"""Hybrid fuel provider — real prices where we can, stations-only elsewhere.

`GovFuelProvider` only knows about countries with public real-price feeds
(ES, FR, IT today; DE next). When a route crosses a country outside that
set, we still want the driver to see WHERE the fuel stations are — just
without a per-litre number. `NominatimFuelProvider` fills that gap: it
returns OSM `amenity=fuel` records with name and coordinates but no
prices, which we tag `price_available=False` so the mobile tile renders
an honest "price unavailable" instead of a fake €0/L.

The two datasets are combined per request:
- Gov results always win for their covered countries.
- Nominatim results are added only for coordinates falling in
  uncovered countries.
- Duplicates within ~10 m are dropped (a Nominatim station near a
  gov-listed one is redundant).
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import replace

from app.domain import Country, Route
from app.providers.fuel import FuelPrice
from app.providers.fuel_econtrol import EControlAustriaFuelProvider
from app.providers.fuel_gov import COVERED_COUNTRIES, GovFuelProvider
from app.providers.fuel_here import HereFuelProvider, HereFuelPricesProvider
from app.providers.geoapify_poi import GeoapifyFuelProvider
from app.providers.nominatim_poi import NominatimFuelProvider

# Countries covered by dedicated real-price providers outside the gov
# feed layer. Stations in these countries are excluded from the HERE
# and Nominatim fallbacks to avoid phantom duplicates.
_EXTRA_COVERED: frozenset[Country] = frozenset({Country.AT})

_log = logging.getLogger(__name__)

_DEDUPE_GRID = 10000  # 4-decimal grid ≈ 11 m per cell at European latitudes


class HybridFuelProvider:
    def __init__(
        self,
        gov: GovFuelProvider | None = None,
        nominatim: NominatimFuelProvider | None = None,
        here: HereFuelProvider | None = None,
        here_prices: HereFuelPricesProvider | None = None,
        econtrol: EControlAustriaFuelProvider | None = None,
    ) -> None:
        self._gov = gov or GovFuelProvider()
        self._nominatim = nominatim or NominatimFuelProvider()
        # HereFuelPricesProvider — preferred path, calls fuel.hereapi.com/v3/stations
        # and returns real pump prices (price_available=True). Tried first.
        self._here_prices = here_prices or HereFuelPricesProvider()
        # HereFuelProvider (Browse) — fallback when the Prices API returns
        # nothing (new country, quota exhausted). Returns station locations
        # with best-effort prices from the Browse extended schema.
        self._here = here or HereFuelProvider()
        # e-control.at — Austrian government Spritpreisrechner. Real pump
        # prices, no key required. Runs concurrently with gov feeds.
        self._econtrol = econtrol or EControlAustriaFuelProvider()

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        # Electric vehicles: skip liquid-fuel gov feeds entirely —
        # they have no charger data — and route straight to Geoapify
        # with the `charging_station` category. Returns tariff-tagged
        # `FuelPrice` entries with `is_charging_station=True` so the
        # frontend picks the EV icon / €/kWh label.
        if (fuel_type or "").lower() == "electric":
            try:
                return await GeoapifyFuelProvider().prices_along(
                    route, fuel_type=fuel_type,
                )
            except Exception as exc:  # noqa: BLE001
                _log.warning("Geoapify EV fetch failed: %r", exc)
                return ()

        # Run gov feeds (ES/FR/IT) and e-control.at (AT) concurrently —
        # both are real-price sources with no paid quota.
        gov, econtrol = await asyncio.gather(
            self._gov.prices_along(route, fuel_type=fuel_type),
            self._econtrol.prices_along(route, fuel_type=fuel_type),
            return_exceptions=True,
        )
        if isinstance(gov, BaseException):
            _log.warning("Gov fuel feed failed: %r", gov)
            gov = ()
        if isinstance(econtrol, BaseException):
            _log.warning("e-control.at fuel feed failed: %r", econtrol)
            econtrol = ()

        # All countries for which we have real prices (gov feeds + AT).
        all_covered = COVERED_COUNTRIES | _EXTRA_COVERED

        # Figure out which countries the route crosses but we DON'T have
        # a real-price feed for. If every country is covered we skip the
        # fallback calls entirely — it's the common case for ES/FR/IT
        # trips and avoids a wasted external request.
        crossed = set(route.countries_crossed or ())
        uncovered = crossed - all_covered
        _log.warning(
            "HybridFuel: crossed=%s uncovered=%s gov=%d econtrol=%d "
            "geometry_pts=%d dist_km=%.0f",
            [c.value for c in crossed],
            [c.value for c in uncovered],
            len(gov),
            len(econtrol),
            len(route.geometry or ()),
            route.distance_km,
        )

        # Seed merged list with all real-price results.
        gov_cells = {_cell(p) for p in gov}
        merged: list[FuelPrice] = list(gov)
        all_cells: set[tuple[int, int] | None] = set(gov_cells)
        for p in econtrol:
            cell = _cell(p)
            if cell in all_cells:
                continue
            all_cells.add(cell)
            merged.append(p)

        if not uncovered and crossed:
            merged.sort(key=lambda p: p.distance_from_origin_km)
            return tuple(merged)

        # HERE Fuel Prices API first — returns real pump prices.
        # Fall through to HERE Browse (HereFuelProvider) when it returns
        # nothing (key missing, quota exhausted, region not yet covered).
        # Nominatim is the final geographic safety net when both HERE
        # paths come up empty.
        try:
            here = await self._here_prices.prices_along(
                route, fuel_type=fuel_type,
            )
            _log.warning(
                "HybridFuel HERE Prices API returned %d stations", len(here),
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE fuel prices API failed: %r", exc)
            here = ()
        if not here:
            try:
                here = await self._here.prices_along(route, fuel_type=fuel_type)
                _log.warning(
                    "HybridFuel HERE Browse returned %d stations", len(here),
                )
            except Exception as exc:  # noqa: BLE001
                _log.warning("HERE fuel browse fallback failed: %r", exc)
                here = ()

        for p in here:
            # Never let HERE overwrite gov/econtrol coverage.
            if p.country in all_covered:
                continue
            cell = _cell(p)
            if cell in all_cells:
                continue
            all_cells.add(cell)
            merged.append(p)

        # Nominatim as final safety net — surface the station even
        # without a price when both HERE and gov came up empty for
        # that coord.
        try:
            nominatim = await self._nominatim.prices_along(route)
            _log.warning("HybridFuel Nominatim returned %d stations", len(nominatim))
        except Exception as exc:  # noqa: BLE001
            _log.warning("Nominatim fuel fallback failed: %r", exc)
            nominatim = ()
        for p in nominatim:
            if p.country in all_covered:
                continue
            cell = _cell(p)
            if cell in all_cells:
                continue
            all_cells.add(cell)
            merged.append(replace(p, price_available=False))

        _log.warning(
            "HybridFuel merged total: %d stations", len(merged),
        )
        merged.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(merged)


def _cell(p: FuelPrice) -> tuple[int, int] | None:
    if p.coordinate is None:
        return None
    return (
        round(p.coordinate.lat * _DEDUPE_GRID),
        round(p.coordinate.lon * _DEDUPE_GRID),
    )

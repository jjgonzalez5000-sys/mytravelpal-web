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

import logging
from dataclasses import replace

from app.domain import Country, Route
from app.providers.fuel import FuelPrice
from app.providers.fuel_gov import COVERED_COUNTRIES, GovFuelProvider
from app.providers.fuel_here import HereFuelProvider
from app.providers.geoapify_poi import GeoapifyFuelProvider
from app.providers.nominatim_poi import NominatimFuelProvider

_log = logging.getLogger(__name__)

_DEDUPE_GRID = 10000  # 4-decimal grid ≈ 11 m per cell at European latitudes


class HybridFuelProvider:
    def __init__(
        self,
        gov: GovFuelProvider | None = None,
        nominatim: NominatimFuelProvider | None = None,
        here: HereFuelProvider | None = None,
    ) -> None:
        self._gov = gov or GovFuelProvider()
        self._nominatim = nominatim or NominatimFuelProvider()
        # HERE Fuel Prices — real €/L for the 25+ countries the
        # gov feeds don't cover. Silently no-ops when the API key
        # env var is missing (local dev, forks without credentials).
        self._here = here or HereFuelProvider()

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

        gov = await self._gov.prices_along(route, fuel_type=fuel_type)

        # Figure out which countries the route crosses but we DON'T have
        # a real-price feed for. If every country is covered we skip the
        # fallback calls entirely — it's the common case for ES/FR/IT
        # trips and avoids a wasted external request.
        crossed = set(route.countries_crossed or ())
        uncovered = crossed - COVERED_COUNTRIES
        if not uncovered and crossed:
            return gov

        # HERE first — real prices for the uncovered countries.
        # Nominatim only fills the geographic gap when HERE returns
        # nothing (key missing, quota exhausted, weird region).
        try:
            here = await self._here.prices_along(route)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE fuel fallback failed: %r", exc)
            here = ()

        gov_cells = {_cell(p) for p in gov}
        merged: list[FuelPrice] = list(gov)
        here_cells: set[tuple[int, int] | None] = set(gov_cells)
        for p in here:
            # Never let HERE overwrite gov coverage.
            if p.country in COVERED_COUNTRIES:
                continue
            cell = _cell(p)
            if cell in here_cells:
                continue
            here_cells.add(cell)
            merged.append(p)

        # Nominatim as final safety net — surface the station even
        # without a price when both HERE and gov came up empty for
        # that coord.
        try:
            nominatim = await self._nominatim.prices_along(route)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Nominatim fuel fallback failed: %r", exc)
            nominatim = ()
        for p in nominatim:
            if p.country in COVERED_COUNTRIES:
                continue
            cell = _cell(p)
            if cell in here_cells:
                continue
            here_cells.add(cell)
            merged.append(replace(p, price_available=False))

        merged.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(merged)


def _cell(p: FuelPrice) -> tuple[int, int] | None:
    if p.coordinate is None:
        return None
    return (
        round(p.coordinate.lat * _DEDUPE_GRID),
        round(p.coordinate.lon * _DEDUPE_GRID),
    )

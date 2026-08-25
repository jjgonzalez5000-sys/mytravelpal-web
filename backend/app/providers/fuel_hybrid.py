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
from app.providers.nominatim_poi import NominatimFuelProvider

_log = logging.getLogger(__name__)

_DEDUPE_GRID = 10000  # 4-decimal grid ≈ 11 m per cell at European latitudes


class HybridFuelProvider:
    def __init__(
        self,
        gov: GovFuelProvider | None = None,
        nominatim: NominatimFuelProvider | None = None,
    ) -> None:
        self._gov = gov or GovFuelProvider()
        self._nominatim = nominatim or NominatimFuelProvider()

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        gov = await self._gov.prices_along(route)

        # Figure out which countries the route crosses but we DON'T have
        # a real-price feed for. If every country is covered we skip the
        # Nominatim call entirely — it's the common case for ES/FR/IT
        # trips and avoids a wasted external request.
        crossed = set(route.countries_crossed or ())
        uncovered = crossed - COVERED_COUNTRIES
        if not uncovered and crossed:
            return gov

        try:
            nominatim = await self._nominatim.prices_along(route)
        except Exception as exc:  # noqa: BLE001 - never let fallback crash /plan
            _log.warning("Nominatim fuel fallback failed: %r", exc)
            return gov

        gov_cells = {_cell(p) for p in gov}
        merged: list[FuelPrice] = list(gov)
        for p in nominatim:
            # Skip Nominatim stations in countries where gov has data —
            # gov is always more complete + carries real prices.
            if p.country in COVERED_COUNTRIES:
                continue
            if _cell(p) in gov_cells:
                continue
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

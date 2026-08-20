from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Protocol

from app.domain import Country, Route


@dataclass(frozen=True, slots=True)
class FuelPrice:
    station_name: str
    country: Country
    price_eur_per_l: float
    distance_from_origin_km: float


class FuelProvider(Protocol):
    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]: ...


# Rough recent-history averages for unleaded 95, EUR/L. Numbers vary week
# to week; these are placeholders good enough to demo the ordering.
_BASE_PRICE_BY_COUNTRY: dict[Country, float] = {
    Country.CH: 1.75,
    Country.FR: 1.80,
    Country.IT: 1.85,
    Country.ES: 1.55,
}


class MockFuelProvider:
    """Deterministic mock fuel-price provider.

    Fabricates ~one station per 100 km of route, distributed across the
    countries the route crosses, with prices spread around each country's
    average. Same route → same stations → same prices.
    """

    _KM_BETWEEN_STATIONS = 100.0
    _PRICE_SPREAD = 0.12  # ±12 cents around country average

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        n_stations = max(1, int(route.distance_km // self._KM_BETWEEN_STATIONS))
        seed = hashlib.sha1(route.polyline.encode()).digest()
        countries = route.countries_crossed or (Country.FR,)

        stations: list[FuelPrice] = []
        for i in range(n_stations):
            country = countries[i % len(countries)]
            base = _BASE_PRICE_BY_COUNTRY.get(country, 1.75)
            # Map a seed byte to [-1, 1] then to [-spread, +spread].
            delta = ((seed[i % len(seed)] / 255.0) * 2 - 1) * self._PRICE_SPREAD
            price = round(base + delta, 3)
            distance = round(self._KM_BETWEEN_STATIONS * (i + 0.5), 1)
            stations.append(
                FuelPrice(
                    station_name=f"Station {i + 1}",
                    country=country,
                    price_eur_per_l=price,
                    distance_from_origin_km=distance,
                )
            )
        return tuple(stations)

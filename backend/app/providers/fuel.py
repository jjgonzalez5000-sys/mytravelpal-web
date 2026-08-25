from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Protocol

from app.data.countries import COUNTRIES
from app.domain import Coordinate, Country, Route


@dataclass(frozen=True, slots=True)
class FuelPrice:
    station_name: str
    country: Country
    price_eur_per_l: float
    distance_from_origin_km: float
    coordinate: Coordinate | None = None
    attributes: tuple[tuple[str, str], ...] = ()
    """Curated OSM tags — brand, opening_hours, payment:contactless,
    fuel:diesel/octane_95/lpg availability, car_wash, shop. Empty for
    mock entries.
    """


class FuelProvider(Protocol):
    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]: ...


def _base_price(country: Country) -> float:
    data = COUNTRIES.get(country.value)
    return data.fuel_petrol_anchor_eur if data else 1.75


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
            base = _base_price(country)
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

from __future__ import annotations

import hashlib
from typing import Protocol

from app.domain import Coordinate, Country, Hotel, PriceBand, Route

_AVG_DETOUR_SPEED_KMH = 60.0  # off-motorway roads are slower


class HotelsProvider(Protocol):
    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        """Return all hotels reasonably close to the route.

        Filtering (max detour, price band) is a separate concern handled
        by the hotel_search service.
        """
        ...


# Rough per-country hotel-price anchors, EUR/night for a 3-star mid room.
# Placeholders; real integration (e.g. Booking Rapid API) will replace.
_PRICE_ANCHORS: dict[Country, float] = {
    Country.CH: 180.0,
    Country.FR: 120.0,
    Country.IT: 110.0,
    Country.ES: 95.0,
}


class MockHotelsProvider:
    """Deterministic hotel catalogue synthesised from route waypoints.

    For each waypoint we fabricate a small handful of hotels within ~15 km
    of the point, at prices spread around the country anchor. The output
    is fully deterministic (seeded from the route polyline) so the same
    trip renders the same hotels every time.
    """

    _HOTELS_PER_WAYPOINT = 3
    _MAX_OFFSET_DEG = 0.10   # ~11 km — the small detour we simulate
    _PRICE_SPREAD_FRACTION = 0.6  # ±60 % around country anchor

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        if not route.waypoints:
            return ()
        seed = hashlib.sha1(route.polyline.encode()).digest()
        hotels: list[Hotel] = []
        for wi, wp in enumerate(route.waypoints):
            country = _country_or_first(route, wp)
            anchor = _PRICE_ANCHORS.get(country, 120.0)
            for hi in range(self._HOTELS_PER_WAYPOINT):
                b = seed[(wi * self._HOTELS_PER_WAYPOINT + hi) % len(seed)]
                # Two seed-derived unit-scaled values in [-1, 1].
                unit_a = (b / 255.0) * 2 - 1
                unit_b = (seed[(b + hi) % len(seed)] / 255.0) * 2 - 1
                lat = wp.lat + unit_a * self._MAX_OFFSET_DEG
                lon = wp.lon + unit_b * self._MAX_OFFSET_DEG
                distance_km = _crow_km(wp, Coordinate(lat=lat, lon=lon))
                # Round-trip off the motorway at slower speed.
                detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
                price = round(anchor * (1 + unit_b * self._PRICE_SPREAD_FRACTION), 2)
                if price < 30:
                    price = 30.0  # nothing lower than a hostel bunk
                # Attributes: deterministically derived from seed bytes so
                # the same trip renders the same distribution.
                kid_friendly = seed[(wi * 7 + hi) % len(seed)] % 3 != 0
                pet_friendly = seed[(wi * 11 + hi) % len(seed)] % 2 == 0
                has_parking = seed[(wi * 13 + hi) % len(seed)] % 5 != 0
                hotels.append(
                    Hotel(
                        name=f"{country.value} Hotel {wi + 1}-{hi + 1}",
                        coordinate=Coordinate(lat=lat, lon=lon),
                        country=country,
                        price_eur_per_night=price,
                        price_band=PriceBand.from_price_eur(price),
                        distance_from_route_km=round(distance_km, 2),
                        detour_minutes=round(detour_minutes, 1),
                        kid_friendly=kid_friendly,
                        pet_friendly=pet_friendly,
                        has_parking=has_parking,
                    )
                )
        return tuple(hotels)


def _country_or_first(route: Route, wp: Coordinate) -> Country:
    """Try to attribute a waypoint to a country; fall back to the first
    country of the route to keep the mock simple.
    """
    from app.services.country_detection import detect_country

    c = detect_country(wp)
    if c is not None:
        return c
    return route.countries_crossed[0] if route.countries_crossed else Country.FR


def _crow_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km

    return _haversine_km(a, b)

from __future__ import annotations

import hashlib
from typing import Protocol

from app.domain import Coordinate, Country, MealSlot, PriceBand, Restaurant, Route

_ALL_SLOTS = (MealSlot.BREAKFAST, MealSlot.LUNCH, MealSlot.DINNER)

_AVG_DETOUR_SPEED_KMH = 60.0  # off-motorway roads are slower


class RestaurantsProvider(Protocol):
    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        """Return all restaurants reasonably close to the route.

        Filtering (max detour, price band) is handled by the
        restaurant_search service, not here.
        """
        ...


# Per-country meal-price anchors, EUR per person for a mid-tier lunch.
# Placeholders; a real POI integration (TripAdvisor / Google Places)
# will replace with actual data.
_PRICE_ANCHORS: dict[Country, float] = {
    Country.CH: 40.0,
    Country.FR: 28.0,
    Country.IT: 25.0,
    Country.ES: 22.0,
}


def _classify_meal_price(price: float) -> PriceBand:
    """Restaurant-oriented banding (per person, per meal).

    < 20 € budget; 20-50 € mid; > 50 € luxury. These thresholds are
    scoped to restaurants only — hotels have their own classifier in
    `providers/hotels.py`.
    """
    if price < 20:
        return PriceBand.BUDGET
    if price <= 50:
        return PriceBand.MID
    return PriceBand.LUX


class MockRestaurantsProvider:
    """Deterministic restaurant catalogue synthesised from route waypoints.

    Two restaurants per waypoint, offset by a small random-looking vector
    seeded from the route polyline, priced around the country anchor.
    """

    _RESTAURANTS_PER_WAYPOINT = 2
    _MAX_OFFSET_DEG = 0.08  # ~9 km — smaller than the hotel offset
    _PRICE_SPREAD_FRACTION = 0.7  # ±70 % around anchor — restaurants vary widely

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        if not route.waypoints:
            return ()
        seed = hashlib.sha1(("r|" + route.polyline).encode()).digest()
        restaurants: list[Restaurant] = []
        for wi, wp in enumerate(route.waypoints):
            country = _country_or_first(route, wp)
            anchor = _PRICE_ANCHORS.get(country, 25.0)
            for ri in range(self._RESTAURANTS_PER_WAYPOINT):
                b = seed[(wi * self._RESTAURANTS_PER_WAYPOINT + ri) % len(seed)]
                unit_a = (b / 255.0) * 2 - 1
                unit_b = (seed[(b + ri) % len(seed)] / 255.0) * 2 - 1
                lat = wp.lat + unit_a * self._MAX_OFFSET_DEG
                lon = wp.lon + unit_b * self._MAX_OFFSET_DEG
                distance_km = _crow_km(wp, Coordinate(lat=lat, lon=lon))
                detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
                price = round(anchor * (1 + unit_b * self._PRICE_SPREAD_FRACTION), 2)
                if price < 8:
                    price = 8.0  # nothing lower than a service-area sandwich
                kid_friendly = seed[(wi * 7 + ri) % len(seed)] % 2 == 0
                pet_friendly = seed[(wi * 11 + ri) % len(seed)] % 3 != 0
                # Meal slots this place typically serves; every restaurant
                # covers at least lunch or dinner (bar service-area coffee).
                slot_mask = seed[(wi * 17 + ri) % len(seed)] % 7 + 1
                slots = tuple(
                    s for i, s in enumerate(_ALL_SLOTS) if (slot_mask >> i) & 1
                ) or (MealSlot.LUNCH,)
                restaurants.append(
                    Restaurant(
                        name=f"{country.value} Restaurant {wi + 1}-{ri + 1}",
                        coordinate=Coordinate(lat=lat, lon=lon),
                        country=country,
                        price_eur_per_meal=price,
                        price_band=_classify_meal_price(price),
                        distance_from_route_km=round(distance_km, 2),
                        detour_minutes=round(detour_minutes, 1),
                        kid_friendly=kid_friendly,
                        pet_friendly=pet_friendly,
                        open_meal_slots=slots,
                    )
                )
        return tuple(restaurants)


def _country_or_first(route: Route, wp: Coordinate) -> Country:
    from app.services.country_detection import detect_country

    c = detect_country(wp)
    if c is not None:
        return c
    return route.countries_crossed[0] if route.countries_crossed else Country.FR


def _crow_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km

    return _haversine_km(a, b)

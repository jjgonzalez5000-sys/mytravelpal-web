"""Overpass API providers for hotels and fuel stations.

Overpass (`https://overpass-api.de/api/interpreter`) is the free query
service that runs on top of OpenStreetMap. It's slow (queries take
several seconds) and rate-limited (fair-use, no key), but it gives us
real POIs across the entire supported map without a paid contract.

Strategy:
- Query a corridor along the route (bounding box, buffered ±0.15°).
- Parse OSM tags for kid/pet-friendly / parking / meal-slot hints.
- Fall back to the mock provider on timeout or empty response so the
  planner never returns nothing at all.

The two providers below can compose with their mock counterparts via
the existing composite pattern:

    hotels = FallbackHotelsProvider(
        OverpassHotelsProvider(), MockHotelsProvider(),
    )
"""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.domain import (
    Coordinate,
    Country,
    Hotel,
    MealSlot,
    PriceBand,
    Restaurant,
    Route,
)
from app.providers.fuel import FuelPrice
from app.providers.restaurants import _classify_meal_price

_log = logging.getLogger(__name__)

_OVERPASS_URL = "https://overpass-api.de/api/interpreter"
_MAX_FEATURES = 40
_ROUTE_BUFFER_DEG = 0.15  # ~16 km latitude buffer around the bbox
_TIMEOUT_S = 10.0


def _route_bbox(route: Route, buffer_deg: float = _ROUTE_BUFFER_DEG) -> tuple[float, float, float, float]:
    points = [route.origin, route.destination, *route.waypoints]
    if route.geometry:
        step = max(1, len(route.geometry) // 32)
        points.extend(route.geometry[::step])
    min_lat = min(p.lat for p in points) - buffer_deg
    max_lat = max(p.lat for p in points) + buffer_deg
    min_lon = min(p.lon for p in points) - buffer_deg
    max_lon = max(p.lon for p in points) + buffer_deg
    return (min_lat, min_lon, max_lat, max_lon)


def _yes(value: str | None) -> bool:
    return (value or "").lower() in {"yes", "designated", "true", "1"}


def _country_of(coord: Coordinate, route: Route) -> Country:
    from app.services.country_detection import detect_country
    return detect_country(coord) or (
        route.countries_crossed[0] if route.countries_crossed else Country.FR
    )


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km as f
    return f(a, b)


def _distance_from_route_km(point: Coordinate, route: Route) -> float:
    points = [route.origin, *route.waypoints, route.destination]
    return min(_haversine_km(point, p) for p in points)


_HOTEL_TAG_WHITELIST = (
    "stars", "phone", "contact:phone", "website", "contact:website",
    "opening_hours", "wheelchair", "wifi", "internet_access",
    "brand", "breakfast", "air_conditioning", "smoking", "operator",
)
_RESTAURANT_TAG_WHITELIST = (
    "cuisine", "phone", "contact:phone", "website", "contact:website",
    "opening_hours", "wheelchair", "outdoor_seating", "takeaway",
    "delivery", "dog", "capacity", "brand", "smoking", "reservation",
)
_FUEL_TAG_WHITELIST = (
    "brand", "opening_hours", "payment:contactless", "payment:credit_cards",
    "fuel:diesel", "fuel:octane_95", "fuel:octane_98", "fuel:lpg",
    "fuel:e10", "fuel:e85", "fuel:HGV_diesel", "car_wash", "shop",
    "self_service", "toilets",
)


def _curate_tags(
    tags: dict[str, Any],
    whitelist: tuple[str, ...],
) -> tuple[tuple[str, str], ...]:
    """Extract whitelisted OSM tags as a tuple of pairs.

    Non-string values coerced via `str()`; empty strings dropped. Order
    follows the whitelist so the client can render deterministically.
    Duplicates like `phone` vs `contact:phone` are collapsed to whichever
    appears first in the whitelist.
    """
    out: list[tuple[str, str]] = []
    seen_keys: set[str] = set()
    for key in whitelist:
        raw = tags.get(key)
        if raw in (None, ""):
            continue
        # Collapse `contact:phone` → `phone`, etc.
        canonical = key.split(":", 1)[-1] if ":" in key else key
        if canonical in seen_keys:
            continue
        seen_keys.add(canonical)
        out.append((canonical, str(raw)))
    return tuple(out)


class OverpassHotelsProvider:
    """Real hotels via OSM `tourism=hotel` / `guest_house` / `motel`."""

    _AVG_DETOUR_SPEED_KMH = 60.0

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        bbox = _route_bbox(route)
        query = f"""
[out:json][timeout:8][bbox:{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}];
(
  node["tourism"~"hotel|guest_house|motel"];
  way["tourism"~"hotel|guest_house|motel"];
);
out center {_MAX_FEATURES};
"""
        elements = await _query(self._client, query)
        if not elements:
            return ()

        hotels: list[Hotel] = []
        for el in elements:
            coord = _element_coord(el)
            if coord is None:
                continue
            tags: dict[str, Any] = el.get("tags") or {}
            name = tags.get("name") or tags.get("official_name") or "Unnamed hotel"
            country = _country_of(coord, route)
            distance_km = _distance_from_route_km(coord, route)
            detour_minutes = (distance_km * 2) / self._AVG_DETOUR_SPEED_KMH * 60.0

            stars = _try_int(tags.get("stars"))
            price = _hotel_price_from_stars(stars, country)
            hotels.append(
                Hotel(
                    name=str(name),
                    coordinate=coord,
                    country=country,
                    price_eur_per_night=price,
                    price_band=PriceBand.from_price_eur(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    kid_friendly=_yes(tags.get("family_friendly")) or bool(tags.get("rooms:family")),
                    pet_friendly=_yes(tags.get("dog")) or _yes(tags.get("pets")),
                    has_parking=tags.get("parking") not in {None, "no"},
                    attributes=_curate_tags(tags, _HOTEL_TAG_WHITELIST),
                )
            )
        return tuple(hotels)


class OverpassRestaurantsProvider:
    """Real restaurants via OSM `amenity=restaurant|cafe|fast_food|pub|bar`."""

    _AVG_DETOUR_SPEED_KMH = 60.0

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        bbox = _route_bbox(route)
        query = f"""
[out:json][timeout:8][bbox:{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}];
(
  node["amenity"~"restaurant|cafe|fast_food|pub|bar"];
  way["amenity"~"restaurant|cafe|fast_food|pub|bar"];
);
out center {_MAX_FEATURES};
"""
        elements = await _query(self._client, query)
        if not elements:
            return ()

        from app.data.countries import COUNTRIES

        rows: list[Restaurant] = []
        for el in elements:
            coord = _element_coord(el)
            if coord is None:
                continue
            tags: dict[str, Any] = el.get("tags") or {}
            name = tags.get("name") or tags.get("brand") or "Unnamed restaurant"
            country = _country_of(coord, route)
            distance_km = _distance_from_route_km(coord, route)
            detour_minutes = (distance_km * 2) / self._AVG_DETOUR_SPEED_KMH * 60.0

            # Price band: OSM doesn't have a rating, but many places set
            # `stars` or `price_range` (fast_food is always budget). We
            # infer from amenity type as a floor.
            amenity = str(tags.get("amenity") or "restaurant")
            anchor = COUNTRIES.get(country.value)
            base = anchor.restaurant_anchor_eur if anchor else 25.0
            if amenity in {"fast_food"}:
                price = base * 0.5
            elif amenity in {"cafe", "bar", "pub"}:
                price = base * 0.7
            else:
                price = base

            rows.append(
                Restaurant(
                    name=str(name),
                    coordinate=coord,
                    country=country,
                    price_eur_per_meal=round(price, 2),
                    price_band=_classify_meal_price(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    kid_friendly=(
                        _yes(tags.get("family_friendly"))
                        or _yes(tags.get("kids_area"))
                    ),
                    pet_friendly=_yes(tags.get("dog")),
                    attributes=_curate_tags(tags, _RESTAURANT_TAG_WHITELIST),
                )
            )
        return tuple(rows)


class OverpassFuelProvider:
    """Real fuel stations via OSM `amenity=fuel`.

    Overpass returns location + tags but *not* prices — those come from
    per-country feeds later (Spanish ministry API, French `prix-carburants`,
    etc.). Until then we synthesise a plausible price from the country
    anchor so the UI stays honest.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        from app.data.countries import COUNTRIES

        bbox = _route_bbox(route, buffer_deg=0.08)
        query = f"""
[out:json][timeout:8][bbox:{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}];
(
  node["amenity"="fuel"];
  way["amenity"="fuel"];
);
out center {_MAX_FEATURES};
"""
        elements = await _query(self._client, query)
        if not elements:
            return ()

        prices: list[FuelPrice] = []
        for el in elements:
            coord = _element_coord(el)
            if coord is None:
                continue
            tags: dict[str, Any] = el.get("tags") or {}
            name = tags.get("brand") or tags.get("name") or "Fuel station"
            country = _country_of(coord, route)
            anchor = COUNTRIES.get(country.value)
            base = anchor.fuel_petrol_anchor_eur if anchor else 1.75
            prices.append(
                FuelPrice(
                    station_name=str(name),
                    country=country,
                    price_eur_per_l=round(base, 3),
                    distance_from_origin_km=round(
                        _distance_from_route_km(coord, route), 1,
                    ),
                    coordinate=coord,
                    attributes=_curate_tags(tags, _FUEL_TAG_WHITELIST),
                )
            )
        # Sort by distance_from_origin_km so the client sees them along the way.
        prices.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(prices[:20])


async def _query(client: httpx.AsyncClient, query: str) -> list[dict]:
    try:
        response = await client.post(_OVERPASS_URL, data={"data": query})
        response.raise_for_status()
        body = response.json()
    except httpx.HTTPError as exc:
        _log.warning("Overpass request failed: %s", exc)
        return []
    except ValueError:
        return []
    return body.get("elements") or []


def _element_coord(el: dict) -> Coordinate | None:
    if el.get("type") == "node":
        lat = el.get("lat")
        lon = el.get("lon")
    else:
        center = el.get("center") or {}
        lat = center.get("lat")
        lon = center.get("lon")
    if lat is None or lon is None:
        return None
    try:
        return Coordinate(lat=float(lat), lon=float(lon))
    except (TypeError, ValueError):
        return None


def _try_int(value: Any) -> int | None:
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return None


def _hotel_price_from_stars(stars: int | None, country: Country) -> float:
    from app.data.countries import COUNTRIES

    anchor = COUNTRIES.get(country.value)
    base = anchor.hotel_anchor_eur if anchor else 120.0
    if stars is None:
        return base
    # 3★ maps to the country anchor; each star ± ~30 %.
    return round(base * (1 + (stars - 3) * 0.3), 2)


class FallbackHotelsProvider:
    """Try `primary` first; on empty result fall back to `secondary`."""

    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        results = await self._primary.hotels_along(route)
        return results or await self._secondary.hotels_along(route)


class FallbackFuelProvider:
    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        results = await self._primary.prices_along(route)
        return results or await self._secondary.prices_along(route)


class FallbackRestaurantsProvider:
    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        results = await self._primary.restaurants_along(route)
        return results or await self._secondary.restaurants_along(route)

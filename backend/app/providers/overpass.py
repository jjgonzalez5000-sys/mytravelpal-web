"""Overpass API providers for hotels and fuel stations.

Overpass (`https://overpass-api.de/api/interpreter`) is the free query
service that runs on top of OpenStreetMap. It's slow (queries take
several seconds) and rate-limited (fair-use, no key), but it gives us
real POIs across the entire supported map without a paid contract.

Strategy:
- Query a corridor along the route (bounding box, buffered ±0.15°).
- Parse OSM tags for kid/pet-friendly / parking / meal-slot hints.
- On timeout or empty response the provider returns `()`. The API
  surfaces that as an empty section rather than substituting mock
  data — the user is better served by "no results" than by fake ones.

Fallback wrappers are kept in this module for test scenarios that
opt-in via `MYTRAVELPAL_HOTELS=mock` etc., but the production factory
no longer chains Overpass to mock.
"""

from __future__ import annotations

import asyncio
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

# Public Overpass mirrors we try in order. The main `.de` instance is
# fastest when it works but goes 504 under load; kumi and the OSM Russia
# mirror give us a second chance on the same request before we give
# up. All three are free / fair-use — no keys needed.
_OVERPASS_URLS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.openstreetmap.fr/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
)

# Overpass returns HTTP 406 for the default httpx User-Agent. Sending a
# named UA is also the Overpass fair-use etiquette — it lets the ops
# team throttle a specific misbehaving client instead of a whole
# provider. This exact string caused every silent-empty response before
# we added it.
_USER_AGENT = "MyTravelPal/1.0 (+https://mytravelpal.app)"


def _new_overpass_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=_TIMEOUT_S,
        headers={"User-Agent": _USER_AGENT, "Accept": "application/json"},
    )
_MAX_FEATURES = 60
_TIMEOUT_S = 25.0

# We used to query a single bbox covering the whole route. For a
# Madrid-Paris trip that bbox is ~5° × 9° — Overpass either times out
# scanning tens of thousands of POIs or refuses with 429. The `around:`
# predicate scans a narrow corridor instead, so we sample the route
# geometry every ~80 km and let Overpass filter server-side. Radius +
# sample cap are tuned so a Madrid→Paris query returns under 10 s on
# the public mirrors — earlier 5 km × 40 points overloaded the server
# and produced silent 504s.
_CORRIDOR_METERS = 3000
_TARGET_SAMPLE_SPACING_KM = 80.0
_MAX_SAMPLE_POINTS = 20


def _sample_corridor_points(route: Route) -> tuple[Coordinate, ...]:
    """Sample route.geometry so `around:` covers the drive without
    blowing up query cost. Always includes origin and destination as
    anchors so short intra-city routes still work.
    """
    dense = list(route.geometry) or list(route.waypoints)
    if not dense:
        return (route.origin, route.destination)
    # target N samples but cap at _MAX_SAMPLE_POINTS so `around` payload
    # stays manageable even on long trips.
    if route.distance_km > 0:
        target = int(route.distance_km / _TARGET_SAMPLE_SPACING_KM) + 2
    else:
        target = 2
    target = min(_MAX_SAMPLE_POINTS, max(2, target))
    step = max(1, len(dense) // target)
    picks: list[Coordinate] = [route.origin]
    for i in range(0, len(dense), step):
        picks.append(dense[i])
    if picks[-1] is not route.destination:
        picks.append(route.destination)
    return tuple(picks)


def _around_clause(points: tuple[Coordinate, ...]) -> str:
    """Render an Overpass `around:radius,lat1,lon1,lat2,lon2,...` string."""
    coords = ",".join(f"{p.lat:.5f},{p.lon:.5f}" for p in points)
    return f"around:{_CORRIDOR_METERS},{coords}"


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
    """Approximate distance from a POI to the route corridor.

    Prefer the dense OSRM geometry when available (hundreds of samples)
    over the sparse `waypoints` field (a handful of interpolated
    coordinates). Using only waypoints caused POIs sitting right on the
    road to look 30+ km off-route because the nearest waypoint was that
    far — which then failed the `max_detour_minutes` filter and hid
    every result.
    """
    dense = route.geometry or (route.origin, *route.waypoints, route.destination)
    return min(_haversine_km(point, p) for p in dense)


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
        self._client = http_client or _new_overpass_client()

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        around = _around_clause(_sample_corridor_points(route))
        query = f"""
[out:json][timeout:20];
(
  node["tourism"~"hotel|guest_house|motel"]({around});
  way["tourism"~"hotel|guest_house|motel"]({around});
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
                    has_parking=tags.get("parking") != "no",
                    attributes=_curate_tags(tags, _HOTEL_TAG_WHITELIST),
                )
            )
        return tuple(hotels)


class OverpassRestaurantsProvider:
    """Real restaurants via OSM `amenity=restaurant|cafe|fast_food|pub|bar`."""

    _AVG_DETOUR_SPEED_KMH = 60.0

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_overpass_client()

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        around = _around_clause(_sample_corridor_points(route))
        query = f"""
[out:json][timeout:20];
(
  node["amenity"~"restaurant|cafe|fast_food|pub|bar"]({around});
  way["amenity"~"restaurant|cafe|fast_food|pub|bar"]({around});
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
        self._client = http_client or _new_overpass_client()

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        from app.data.countries import COUNTRIES

        around = _around_clause(_sample_corridor_points(route))
        query = f"""
[out:json][timeout:20];
(
  node["amenity"="fuel"]({around});
  way["amenity"="fuel"]({around});
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
    """Fan the query out to every Overpass mirror in parallel and
    return the first 200 that comes back.

    Sequential mirror probing meant every failure added ~20 s of wall
    time before we tried the next one, so a bad day at overpass-api.de
    left the whole planner blocked. Firing 3 requests at once is
    tolerable — Overpass fair-use is per-IP not per-query and the
    losing branches are cancelled the moment we have a winner.

    Return semantics:
    - Any mirror returning HTTP 200 with a JSON body wins. Its
      `elements` list is returned even if empty (that's a legitimate
      "no POIs here" answer).
    - HTTP 400/403 from ANY mirror is treated as a query-side problem
      (malformed query, banned client) and short-circuits — retrying
      won't help.
    - When every branch loses (5xx, 429, network error), we log the
      per-mirror outcome and return `()`.
    """
    async def _hit(url: str) -> tuple[str, int | str | Exception, list[dict] | None]:
        try:
            response = await client.post(url, data={"data": query})
        except httpx.HTTPError as exc:
            return (url, exc, None)
        status = response.status_code
        if status == 200:
            try:
                body = response.json()
            except ValueError:
                return (url, "non-JSON", None)
            # Overpass 200 + `remark: "runtime error: Query timed out"`
            # is a server-side failure disguised as success. Elements
            # comes back empty in that case — treat it as an error so
            # the sibling mirrors get their turn. Without this the
            # timed-out response wins the "first back" race, cancels
            # the healthy mirrors mid-flight, and enrichment silently
            # returns nothing.
            remark = body.get("remark") or ""
            if "timed out" in remark.lower() or "runtime error" in remark.lower():
                return (url, f"remark: {remark[:80]}", None)
            return (url, 200, body.get("elements") or [])
        return (url, status, None)

    tasks = [asyncio.create_task(_hit(url)) for url in _OVERPASS_URLS]
    remaining = set(tasks)
    outcomes: list[tuple[str, int | str | Exception]] = []
    try:
        while remaining:
            done, remaining = await asyncio.wait(
                remaining, return_when=asyncio.FIRST_COMPLETED,
            )
            for task in done:
                url, result, elements = task.result()
                if elements is not None:
                    # Winning branch — cancel the losers so we don't
                    # keep the sockets open behind us.
                    for other in remaining:
                        other.cancel()
                    _log.info(
                        "Overpass %s returned %d elements",
                        url, len(elements),
                    )
                    return elements
                if isinstance(result, int) and 400 <= result < 500 and \
                        result != 429:
                    # Any 4xx-that-isn't-rate-limit is a query problem
                    # — other mirrors will fail identically. Bail out
                    # rather than waste the remaining branches.
                    for other in remaining:
                        other.cancel()
                    return []
                outcomes.append((url, result))
    finally:
        for task in tasks:
            if not task.done():
                task.cancel()

    for url, result in outcomes:
        # `repr` because bare `str(exc)` on httpx.ReadTimeout et al.
        # renders as an empty string — the earlier logs said "network
        # error:" with no context, which was useless in fly logs.
        detail = f"HTTP {result}" if isinstance(result, int) else repr(result)
        _log.warning("Overpass %s failed: %s", url, detail)
    _log.warning(
        "Overpass: all %d mirrors failed for a %d-char query",
        len(outcomes), len(query),
    )
    return []


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
    """Try `primary` first; on empty result fall back to `secondary`.

    A warning log is emitted whenever the fallback fires so operators
    can spot silently-mocked responses in production log tails.
    """

    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        results = await self._primary.hotels_along(route)
        if results:
            return results
        _log.warning(
            "hotels: primary provider returned 0 results (%d km route); "
            "falling back to mock",
            int(route.distance_km),
        )
        return await self._secondary.hotels_along(route)


class FallbackFuelProvider:
    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        results = await self._primary.prices_along(route)
        if results:
            return results
        _log.warning(
            "fuel: primary provider returned 0 results (%d km route); "
            "falling back to mock",
            int(route.distance_km),
        )
        return await self._secondary.prices_along(route)


class FallbackRestaurantsProvider:
    def __init__(self, primary, secondary) -> None:
        self._primary = primary
        self._secondary = secondary

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        results = await self._primary.restaurants_along(route)
        if results:
            return results
        _log.warning(
            "restaurants: primary provider returned 0 results (%d km "
            "route); falling back to mock",
            int(route.distance_km),
        )
        return await self._secondary.restaurants_along(route)

"""Nominatim-based POI providers for hotels, restaurants, fuel stations.

Overpass public mirrors turned out to be unreachable / rate-limited from
Fly.io (`ConnectError: All connection attempts failed`, `ReadTimeout`
across all three mirrors we tried). The Nominatim geocoding endpoint,
by contrast, has been serving requests from the same Fly machine without
issue — same OSM upstream, different infrastructure.

This module reuses Nominatim's `search` endpoint with the special
`q=[key=value]` amenity-search syntax and a viewbox covering the route
corridor. Design choices:

- One request per POI type (3 total for hotels+restaurants+fuel).
- `viewbox=` = the whole route bbox with a small buffer.  Nominatim
  caps the response at `limit`; we ask for `40` and let a client-side
  filter sort by distance-to-route. For long trips (Madrid→Paris) this
  concentrates results in dense areas — arguably desirable, and if it
  ever hurts we can layer corridor-sampled queries on top.
- Sequential across POI types with a small spacer.  Nominatim's usage
  policy is 1 request per second per client; running the three POI
  types back-to-back with a ~0.4 s spacer keeps us well under.
- We honour Nominatim's User-Agent requirement — the same UA string
  the geocoder uses so ops can trace both to the same client.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx

from app.data.countries import COUNTRIES
from app.domain import (
    Coordinate,
    Country,
    Hotel,
    PriceBand,
    Restaurant,
    Route,
)
from app.providers.fuel import FuelPrice
from app.providers.restaurants import _classify_meal_price

_log = logging.getLogger(__name__)

_URL = "https://nominatim.openstreetmap.org/search"
_USER_AGENT = "MyTravelPal/1.0 (+https://mytravelpal.app)"
_TIMEOUT_S = 12.0
# Buffer around the route bbox so we catch POIs a few km off the road.
# 0.05° ~ 5-6 km at European latitudes.
_VIEWBOX_BUFFER_DEG = 0.05
_MAX_RESULTS_PER_QUERY = 40
_RATE_SPACER_S = 0.4
# Off-corridor distance filter — anything past this is dropped in the
# API layer's `filter_hotels` / `filter_restaurants`, but we also cap
# here so Nominatim's "any POI in the viewbox" doesn't smuggle in
# something 50 km sideways.
_MAX_OFF_CORRIDOR_KM = 8.0
_AVG_DETOUR_SPEED_KMH = 60.0


def _new_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=_TIMEOUT_S,
        headers={
            "User-Agent": _USER_AGENT,
            "Accept-Language": "en",
            "Accept": "application/json",
        },
    )


def _route_viewbox(route: Route) -> tuple[float, float, float, float]:
    points = [route.origin, route.destination]
    if route.geometry:
        step = max(1, len(route.geometry) // 24)
        points.extend(route.geometry[::step])
    else:
        points.extend(route.waypoints)
    min_lat = min(p.lat for p in points) - _VIEWBOX_BUFFER_DEG
    max_lat = max(p.lat for p in points) + _VIEWBOX_BUFFER_DEG
    min_lon = min(p.lon for p in points) - _VIEWBOX_BUFFER_DEG
    max_lon = max(p.lon for p in points) + _VIEWBOX_BUFFER_DEG
    # Nominatim viewbox: `west,north,east,south` (top-left, bottom-right)
    return (min_lon, max_lat, max_lon, min_lat)


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km as f
    return f(a, b)


_MAX_ROUTE_REFERENCE_POINTS = 60


def _route_reference_points(route: Route) -> tuple[Coordinate, ...]:
    """Downsample the polyline to a manageable number of anchors so
    corridor filtering doesn't quadratically explode with route
    length. See the identical helper in `fuel_gov.py` — same reason.
    """
    dense = route.geometry or (route.origin, *route.waypoints, route.destination)
    if len(dense) <= _MAX_ROUTE_REFERENCE_POINTS:
        return tuple(dense)
    step = max(1, len(dense) // _MAX_ROUTE_REFERENCE_POINTS)
    sampled = list(dense[::step])
    if sampled[0] is not dense[0]:
        sampled.insert(0, dense[0])
    if sampled[-1] is not dense[-1]:
        sampled.append(dense[-1])
    return tuple(sampled)


def _distance_to_points(
    point: Coordinate, reference: tuple[Coordinate, ...],
) -> float:
    return min(_haversine_km(point, p) for p in reference)


def _distance_from_route_km(point: Coordinate, route: Route) -> float:
    """Convenience wrapper — for hot loops sample once with
    `_route_reference_points()` and call `_distance_to_points()`
    directly on the sample so we're not re-sampling per candidate.
    """
    return _distance_to_points(point, _route_reference_points(route))


def _country_of(coord: Coordinate, route: Route) -> Country:
    from app.services.country_detection import detect_country
    return detect_country(coord) or (
        route.countries_crossed[0] if route.countries_crossed else Country.FR
    )


async def _search(
    client: httpx.AsyncClient, tag_query: str, viewbox: tuple[float, float, float, float],
) -> list[dict[str, Any]]:
    """Run one Nominatim `search` for a `[amenity=…]` tag inside `viewbox`.

    Returns `[]` on any network / parse failure — with detailed logging
    so the fly console shows what went wrong instead of a silent empty.
    """
    params = {
        "q": tag_query,
        "viewbox": f"{viewbox[0]},{viewbox[1]},{viewbox[2]},{viewbox[3]}",
        "bounded": "1",
        "limit": str(_MAX_RESULTS_PER_QUERY),
        "format": "jsonv2",
        "addressdetails": "1",
        "extratags": "1",
    }
    try:
        response = await client.get(_URL, params=params)
    except httpx.HTTPError as exc:
        _log.warning("Nominatim POI %s failed: %r", tag_query, exc)
        return []
    if response.status_code >= 400:
        _log.warning(
            "Nominatim POI %s HTTP %d: %s",
            tag_query, response.status_code, response.text[:200],
        )
        return []
    try:
        body = response.json()
    except ValueError:
        _log.warning("Nominatim POI %s non-JSON body", tag_query)
        return []
    if not isinstance(body, list):
        return []
    return body


def _extract_coord(item: dict[str, Any]) -> Coordinate | None:
    try:
        return Coordinate(lat=float(item["lat"]), lon=float(item["lon"]))
    except (KeyError, TypeError, ValueError):
        return None


def _extratag(item: dict[str, Any], key: str) -> str | None:
    extras = item.get("extratags") or {}
    val = extras.get(key)
    return str(val) if val not in (None, "") else None


def _yes(v: str | None) -> bool:
    return (v or "").lower() in {"yes", "designated", "true", "1"}


def _try_int(v: Any) -> int | None:
    try:
        return int(str(v))
    except (TypeError, ValueError):
        return None


def _display_name(item: dict[str, Any]) -> str:
    # Nominatim's `name` is the POI's own name; `display_name` is a
    # comma-separated address ("Le Bistro, 12 Rue de la Paix, Paris").
    # Prefer the short one, fall back to the first segment of the long
    # one — never the whole address string.
    name = item.get("name")
    if name:
        return str(name)
    display = item.get("display_name") or ""
    return str(display).split(",", 1)[0].strip() or "Unnamed"


class NominatimHotelsProvider:
    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def hotels_along(self, route: Route) -> tuple[Hotel, ...]:
        vb = _route_viewbox(route)
        reference = _route_reference_points(route)
        items = await _search(self._client, "[tourism=hotel]", vb)
        hotels: list[Hotel] = []
        for it in items:
            coord = _extract_coord(it)
            if coord is None:
                continue
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
            country = _country_of(coord, route)
            stars = _try_int(_extratag(it, "stars"))
            anchor = COUNTRIES.get(country.value)
            base = anchor.hotel_anchor_eur if anchor else 120.0
            price = round(
                base * (1 + ((stars or 3) - 3) * 0.3), 2,
            )
            hotels.append(
                Hotel(
                    name=_display_name(it),
                    coordinate=coord,
                    country=country,
                    price_eur_per_night=price,
                    price_band=PriceBand.from_price_eur(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    kid_friendly=_yes(_extratag(it, "family_friendly")),
                    pet_friendly=(
                        _yes(_extratag(it, "dog"))
                        or _yes(_extratag(it, "pets"))
                    ),
                    has_parking=_extratag(it, "parking") not in (None, "no"),
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        hotels.sort(key=lambda h: h.detour_minutes)
        return tuple(hotels)


class NominatimRestaurantsProvider:
    _AMENITY_QUERIES = (
        "[amenity=restaurant]",
        "[amenity=cafe]",
        "[amenity=fast_food]",
    )

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def restaurants_along(self, route: Route) -> tuple[Restaurant, ...]:
        vb = _route_viewbox(route)
        reference = _route_reference_points(route)
        all_items: list[dict[str, Any]] = []
        for tag in self._AMENITY_QUERIES:
            all_items.extend(await _search(self._client, tag, vb))
            await asyncio.sleep(_RATE_SPACER_S)
        seen_place_ids: set[int] = set()
        rows: list[Restaurant] = []
        for it in all_items:
            pid = it.get("place_id")
            if isinstance(pid, int):
                if pid in seen_place_ids:
                    continue
                seen_place_ids.add(pid)
            coord = _extract_coord(it)
            if coord is None:
                continue
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
            country = _country_of(coord, route)
            anchor = COUNTRIES.get(country.value)
            base = anchor.restaurant_anchor_eur if anchor else 25.0
            amenity = str(it.get("type") or "restaurant")
            if amenity == "fast_food":
                price = base * 0.5
            elif amenity in {"cafe", "bar", "pub"}:
                price = base * 0.7
            else:
                price = base
            rows.append(
                Restaurant(
                    name=_display_name(it),
                    coordinate=coord,
                    country=country,
                    price_eur_per_meal=round(price, 2),
                    price_band=_classify_meal_price(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    kid_friendly=_yes(_extratag(it, "family_friendly")),
                    pet_friendly=_yes(_extratag(it, "dog")),
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        rows.sort(key=lambda r: r.detour_minutes)
        return tuple(rows)


class NominatimFuelProvider:
    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        vb = _route_viewbox(route)
        reference = _route_reference_points(route)
        items = await _search(self._client, "[amenity=fuel]", vb)
        prices: list[FuelPrice] = []
        for it in items:
            coord = _extract_coord(it)
            if coord is None:
                continue
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            country = _country_of(coord, route)
            anchor = COUNTRIES.get(country.value)
            base = anchor.fuel_petrol_anchor_eur if anchor else 1.75
            prices.append(
                FuelPrice(
                    station_name=(
                        _extratag(it, "brand") or _display_name(it)
                    ),
                    country=country,
                    price_eur_per_l=round(base, 3),
                    distance_from_origin_km=round(
                        _haversine_km(route.origin, coord), 1,
                    ),
                    coordinate=coord,
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        prices.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(prices[:20])

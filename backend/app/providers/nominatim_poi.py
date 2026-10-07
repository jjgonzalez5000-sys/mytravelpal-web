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
# Nominatim's public policy caps free usage at 1 request/second per IP.
# Anything under that gets you 429'd and, after a few in a row, a
# temporary ban that makes subsequent /plan requests return empty
# POI lists. We space to 1.1 s to stay safely above the cap even
# with a bit of clock jitter.
_RATE_SPACER_S = 1.1
# When Nominatim returns 429 the batch bails immediately for the rest
# of that plan — hammering while banned only extends the ban. Any
# partial results collected before the 429 are still returned.
_RATE_LIMIT_STATUS = 429
# Off-corridor distance filter — anything past this is dropped in the
# API layer's `filter_hotels` / `filter_restaurants`, but we also cap
# here so Nominatim's "any POI in the viewbox" doesn't smuggle in
# something 50 km sideways. Widened from 8 → 15 km after the
# Unterägeri → Turin test returned empty: curvy Alpine roads with
# switchbacks make POIs in valleys read as "10 km off" the straight-
# line polyline sample even though they're right off the actual road.
# 15 km is the practical detour ceiling a driver accepts for a meal.
_MAX_OFF_CORRIDOR_KM = 15.0
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


# Distance per corridor sub-viewbox. For a Madrid → Bucharest trip
# (~2900 km) this yields 6 sub-searches — enough to actually cover
# the corridor with 40 results/each instead of the previous "single
# huge bbox → 40 arbitrary POIs" pattern that returned near-nothing
# for long trips.
# Chunk knobs — tuned for the public Nominatim demo server, which
# is aggressive with 429s.  Bumping to 6 chunks at 300 km sent
# 24 back-to-back requests per plan and triggered the 15 min
# global cooldown; falling back to 4 × 500 km keeps 16 requests
# per plan comfortably within the rate policy while still giving
# a Zurich → Bucharest trip four disjoint POI pools instead of
# the original one giant bbox. Targeted `hotels_near` /
# `restaurants_near` densification (trips.py) fills the gaps
# around each picked rest stop when the corridor pass is sparse.
_CORRIDOR_CHUNK_KM = 500.0
# Bumped 4 → 6 after 2026-09-28 dogfood: Toledo → Turda (RO) is
# ~2800 km, capped at 4 chunks it meant each Geoapify bbox spanned
# ~700 km. Places API kept timing out on those huge rectangles →
# every provider returned empty and the driver saw a bare plan.
# Six chunks = ~467 km each → bboxes small enough that Geoapify's
# 15 s per-request timeout is workable, still under the free tier's
# 5 req/s ceiling (6 chunks × 3 categories = 18 requests fired in
# parallel, but Geoapify pools per key so effective peak is lower).
_MAX_CORRIDOR_CHUNKS = 6
_MIN_CORRIDOR_CHUNKS = 1


def _corridor_viewboxes(
    route: Route,
) -> list[tuple[float, float, float, float]]:
    """Split the trip into consecutive sub-viewboxes so a single
    Nominatim `limit=40` search returns useful density on long trips.

    Short routes (<500 km) get one bbox — the original behaviour.
    Long routes (Madrid-Bucharest) get up to 8 sub-bboxes covering
    ~500 km each. Consecutive bboxes overlap by design (each includes
    a small buffer past its endpoints) so POIs near a chunk boundary
    aren't missed.
    """
    # Use geometry when available; fall back to waypoints (great-circle
    # interpolation) so sparse routes don't collapse to just 2 points.
    if route.geometry:
        dense = route.geometry
    elif route.waypoints:
        dense = (route.origin, *route.waypoints, route.destination)
    else:
        dense = (route.origin, route.destination)
    if len(dense) < 2:
        return [_route_viewbox(route)]
    if route.distance_km <= _CORRIDOR_CHUNK_KM:
        return [_route_viewbox(route)]
    chunks = int(route.distance_km // _CORRIDOR_CHUNK_KM) + 1
    chunks = max(_MIN_CORRIDOR_CHUNKS, min(_MAX_CORRIDOR_CHUNKS, chunks))
    step = max(1, len(dense) // chunks)
    boxes: list[tuple[float, float, float, float]] = []
    for i in range(chunks):
        start = i * step
        end = min(len(dense), (i + 1) * step + 1)  # +1 for endpoint overlap
        segment = dense[start:end]
        if len(segment) < 2:
            continue
        min_lat = min(p.lat for p in segment) - _VIEWBOX_BUFFER_DEG
        max_lat = max(p.lat for p in segment) + _VIEWBOX_BUFFER_DEG
        min_lon = min(p.lon for p in segment) - _VIEWBOX_BUFFER_DEG
        max_lon = max(p.lon for p in segment) + _VIEWBOX_BUFFER_DEG
        boxes.append((min_lon, max_lat, max_lon, min_lat))
    return boxes or [_route_viewbox(route)]


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


class _NominatimRateLimited(Exception):
    """Raised when Nominatim returns 429 so the caller can short-circuit
    the rest of the batch instead of extending the ban.
    """


# In-memory cache: (viewbox_key, tag_query) -> (fetched_at, list of items).
# Small enough to fit comfortably in RAM (each entry ~50 KB max, keyed
# on quantised bbox so overlapping trips share hits). Wiped on process
# restart, which is fine — this is a de-hammer measure, not durable
# storage.
_POI_CACHE: dict[tuple[str, str], tuple[float, list[dict[str, Any]]]] = {}
_POI_CACHE_TTL_S = 24 * 3600

# Global cooldown after a 429. While active, EVERY POI search returns
# empty immediately — even attempting Nominatim again just extends the
# ban. 15 min matches Nominatim's typical soft-ban window. Manual
# reset on process restart.
_COOLDOWN_S = 15 * 60
_cooldown_until: float = 0.0


def _bbox_key(vb: tuple[float, float, float, float]) -> str:
    """Round bbox coords to a 0.02° grid (~2 km) so nearly-identical
    corridors share cache hits. A user planning Madrid → Paris twice
    within a day hits the cache the second time.
    """
    return ",".join(f"{round(x, 2)}" for x in vb)


async def _search(
    client: httpx.AsyncClient, tag_query: str, viewbox: tuple[float, float, float, float],
) -> list[dict[str, Any]]:
    """Run one Nominatim `search` for a `[amenity=…]` tag inside `viewbox`.

    Cache-first: identical or near-identical bboxes reuse results for
    24 h so subsequent /plan calls for the same corridor don't hit
    the endpoint at all. On 429, raises [_NominatimRateLimited] to
    short-circuit the batch AND arms a global 15-min cooldown so
    further batches don't even try until the ban expires.
    """
    global _cooldown_until

    import time
    cache_key = (_bbox_key(viewbox), tag_query)
    cached = _POI_CACHE.get(cache_key)
    now = time.monotonic()
    if cached is not None and now - cached[0] < _POI_CACHE_TTL_S:
        return cached[1]

    if now < _cooldown_until:
        _log.info(
            "Nominatim in cooldown for %.0f s more — skipping %s",
            _cooldown_until - now, tag_query,
        )
        raise _NominatimRateLimited()

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
    if response.status_code == _RATE_LIMIT_STATUS:
        _cooldown_until = time.monotonic() + _COOLDOWN_S
        _log.warning(
            "Nominatim POI %s 429 — global cooldown %ds",
            tag_query, _COOLDOWN_S,
        )
        raise _NominatimRateLimited()
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
    _POI_CACHE[cache_key] = (now, body)
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
        # Multi-chunk corridor: for Madrid → Bucharest one bbox +
        # limit=40 returned near-nothing on-route. Split the trip
        # so each ~500 km chunk gets its own limit=40 pool.
        boxes = _corridor_viewboxes(route)
        reference = _route_reference_points(route)
        items: list[dict[str, Any]] = []
        try:
            for vb in boxes:
                items.extend(await _search(self._client, "[tourism=hotel]", vb))
                if len(boxes) > 1:
                    await asyncio.sleep(_RATE_SPACER_S)
        except _NominatimRateLimited:
            # Whatever we collected before the 429 stays; the rest of
            # the batch is dropped.
            pass
        hotels: list[Hotel] = []
        seen_place_ids: set[int] = set()
        for it in items:
            # Overlapping bboxes at chunk boundaries return the same
            # Nominatim place_id in >1 result — dedup so we don't
            # render two rows for the same physical hotel.
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
                    detour_km=round(distance_km * 2, 2),
                    kid_friendly=_yes(_extratag(it, "family_friendly")),
                    pet_friendly=(
                        _yes(_extratag(it, "dog"))
                        or _yes(_extratag(it, "pets"))
                    ),
                    has_parking=_extratag(it, "parking") != "no",
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        hotels.sort(key=lambda h: h.detour_minutes)
        return tuple(hotels)

    async def hotels_near(
        self, point: Coordinate, radius_km: float = 40.0,
    ) -> tuple[Hotel, ...]:
        """Targeted point-radius hotel search — used by the trip
        planner to densify the sleep-stop hotel match when the
        corridor pass returned nothing near the picked rest stop.
        """
        deg = max(radius_km, 5.0) / 111.0
        vb = (
            point.lon - deg, point.lat + deg,
            point.lon + deg, point.lat - deg,
        )
        items: list[dict[str, Any]] = []
        try:
            items.extend(await _search(self._client, "[tourism=hotel]", vb))
        except _NominatimRateLimited:
            pass
        seen: set[int] = set()
        hotels: list[Hotel] = []
        for it in items:
            pid = it.get("place_id")
            if isinstance(pid, int):
                if pid in seen:
                    continue
                seen.add(pid)
            coord = _extract_coord(it)
            if coord is None:
                continue
            distance_km = _haversine_km(point, coord)
            if distance_km > radius_km:
                continue
            country = point_country(coord)
            stars = _try_int(_extratag(it, "stars"))
            anchor = COUNTRIES.get(country.value)
            base = anchor.hotel_anchor_eur if anchor else 120.0
            price = round(base * (1 + ((stars or 3) - 3) * 0.3), 2)
            detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
            hotels.append(
                Hotel(
                    name=_display_name(it),
                    coordinate=coord,
                    country=country,
                    price_eur_per_night=price,
                    price_band=PriceBand.from_price_eur(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    detour_km=round(distance_km * 2, 2),
                    kid_friendly=_yes(_extratag(it, "family_friendly")),
                    pet_friendly=(
                        _yes(_extratag(it, "dog"))
                        or _yes(_extratag(it, "pets"))
                    ),
                    has_parking=_extratag(it, "parking") != "no",
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        hotels.sort(key=lambda h: _haversine_km(point, h.coordinate))
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
        # Multi-chunk corridor split — same reason as hotels. For a
        # Madrid → Bucharest trip this expands 3 total searches
        # (1 bbox × 3 amenities) into up to 24 (8 bboxes × 3
        # amenities) so we actually get useful per-segment density.
        boxes = _corridor_viewboxes(route)
        reference = _route_reference_points(route)
        all_items: list[dict[str, Any]] = []
        try:
            for vb in boxes:
                for tag in self._AMENITY_QUERIES:
                    all_items.extend(await _search(self._client, tag, vb))
                    await asyncio.sleep(_RATE_SPACER_S)
        except _NominatimRateLimited:
            # Halt the rest of the batch — we've been 429'd. Whatever
            # made it into `all_items` before the hit still ships.
            pass
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
                    detour_km=round(distance_km * 2, 2),
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

    async def restaurants_near(
        self, point: Coordinate, radius_km: float = 25.0,
    ) -> tuple[Restaurant, ...]:
        """Targeted point-radius search — used by the trip planner
        to densify meal-stop matches when the corridor-wide pass
        yielded nothing near a picked rest stop. Radius maps to a
        tiny viewbox (~radius_km around the point) so a single
        `limit=40` query returns POIs actually within the detour
        envelope.
        """
        deg = max(radius_km, 5.0) / 111.0  # km → degrees latitude
        vb = (
            point.lon - deg, point.lat + deg,
            point.lon + deg, point.lat - deg,
        )
        items: list[dict[str, Any]] = []
        try:
            for tag in self._AMENITY_QUERIES:
                items.extend(await _search(self._client, tag, vb))
                await asyncio.sleep(_RATE_SPACER_S)
        except _NominatimRateLimited:
            pass
        seen: set[int] = set()
        rows: list[Restaurant] = []
        for it in items:
            pid = it.get("place_id")
            if isinstance(pid, int):
                if pid in seen:
                    continue
                seen.add(pid)
            coord = _extract_coord(it)
            if coord is None:
                continue
            distance_km = _haversine_km(point, coord)
            if distance_km > radius_km:
                continue
            country = point_country(coord)
            anchor = COUNTRIES.get(country.value)
            base = anchor.restaurant_anchor_eur if anchor else 25.0
            amenity = str(it.get("type") or "restaurant")
            if amenity == "fast_food":
                price = base * 0.5
            elif amenity in {"cafe", "bar", "pub"}:
                price = base * 0.7
            else:
                price = base
            detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
            rows.append(
                Restaurant(
                    name=_display_name(it),
                    coordinate=coord,
                    country=country,
                    price_eur_per_meal=round(price, 2),
                    price_band=_classify_meal_price(price),
                    distance_from_route_km=round(distance_km, 2),
                    detour_minutes=round(detour_minutes, 1),
                    detour_km=round(distance_km * 2, 2),
                    kid_friendly=_yes(_extratag(it, "family_friendly")),
                    pet_friendly=_yes(_extratag(it, "dog")),
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (it.get("extratags") or {}).items()
                        if v not in (None, "")
                    )[:12],
                )
            )
        rows.sort(key=lambda r: _haversine_km(point, r.coordinate))
        return tuple(rows)


def point_country(coord: Coordinate) -> Country:
    from app.services.country_detection import detect_country
    return detect_country(coord) or Country.FR


class NominatimFuelProvider:
    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def prices_along(self, route: Route) -> tuple[FuelPrice, ...]:
        # Use corridor sub-viewboxes (same pattern as hotels/restaurants)
        # so long cross-European routes (CH→RO, DE→GR) get coverage
        # along the actual road instead of one giant bbox that Nominatim
        # returns random results for.
        boxes = _corridor_viewboxes(route)
        reference = _route_reference_points(route)
        seen: set[tuple[int, int]] = set()
        prices: list[FuelPrice] = []

        has_real_geometry = bool(route.geometry) and len(route.geometry) > 15
        max_off_corridor = _MAX_OFF_CORRIDOR_KM if has_real_geometry else 50.0

        for vb in boxes:
            try:
                items = await _search(self._client, "[amenity=fuel]", vb)
            except _NominatimRateLimited:
                break
            for it in items:
                coord = _extract_coord(it)
                if coord is None:
                    continue
                cell = (round(coord.lat * 10000), round(coord.lon * 10000))
                if cell in seen:
                    continue
                distance_km = _distance_to_points(coord, reference)
                if distance_km > max_off_corridor:
                    continue
                seen.add(cell)
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
        return tuple(prices[:60])

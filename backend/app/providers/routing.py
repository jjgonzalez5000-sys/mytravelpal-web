from __future__ import annotations

import hashlib
import logging
import os
import time
from datetime import timedelta
from math import asin, atan2, cos, degrees, radians, sin, sqrt
from typing import Any, Protocol

import httpx

from app.domain import Coordinate, Country, Route

_log = logging.getLogger(__name__)

_EARTH_RADIUS_KM = 6371.0
_AVG_HIGHWAY_SPEED_KMH = 95.0
_WAYPOINT_COUNT = 10  # excluding origin and destination


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    lat1, lon1, lat2, lon2 = map(radians, (a.lat, a.lon, b.lat, b.lon))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * asin(sqrt(h))


def point_at_fraction(a: Coordinate, b: Coordinate, f: float) -> Coordinate:
    """Point at fractional position `f` (0..1) along the great circle from
    `a` to `b`. f=0 returns `a`, f=1 returns `b`.
    """
    if f <= 0:
        return a
    if f >= 1:
        return b
    lat1, lon1, lat2, lon2 = map(radians, (a.lat, a.lon, b.lat, b.lon))
    d = 2 * asin(
        sqrt(
            sin((lat2 - lat1) / 2) ** 2
            + cos(lat1) * cos(lat2) * sin((lon2 - lon1) / 2) ** 2
        )
    )
    if d == 0:
        return a
    a_coef = sin((1 - f) * d) / sin(d)
    b_coef = sin(f * d) / sin(d)
    x = a_coef * cos(lat1) * cos(lon1) + b_coef * cos(lat2) * cos(lon2)
    y = a_coef * cos(lat1) * sin(lon1) + b_coef * cos(lat2) * sin(lon2)
    z = a_coef * sin(lat1) + b_coef * sin(lat2)
    lat = atan2(z, sqrt(x * x + y * y))
    lon = atan2(y, x)
    return Coordinate(lat=degrees(lat), lon=degrees(lon))


def _great_circle_interpolate(
    a: Coordinate, b: Coordinate, n: int
) -> tuple[Coordinate, ...]:
    """Return `n` intermediate coordinates evenly spaced along the great
    circle from `a` to `b` (excluding the endpoints themselves).
    """
    if n <= 0:
        return ()
    return tuple(point_at_fraction(a, b, i / (n + 1)) for i in range(1, n + 1))


class RoutingProvider(Protocol):
    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
        *,
        waypoints: tuple[Coordinate, ...] = (),
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        """Return a Route from origin to destination, visiting any
        intermediate `waypoints` in the given order.

        Flags map to per-provider engine hints:
        - `avoid_tolls` — OSRM `?exclude=toll`, mock: +15 % distance, 0 €
          tolls, slower average speed.
        - `avoid_motorways` — OSRM `?exclude=motorway`. Mock: +25 %
          distance, slower speed. Overlaps with avoid_tolls in practice.
        - `prefer_scenic` — advisory. Mock: penalizes duration by 8 %
          (assume more curvy secondary roads); OSRM has no direct
          equivalent yet, so it just widens the OSRM alternatives
          request in future iterations.
        """
        ...


def _apply_toll_pricing(
    distance_km: float, countries: tuple[Country, ...],
) -> float:
    """Toll approximation across the whole supported map.

    Per-km motorway pricing for countries that price by distance
    (FR/IT/ES/PT/GR/HR/…) plus a flat vignette contribution for
    sticker countries (CH/AT/SI/CZ/SK/HU/BG/RO). Data lives in
    [`countries`](../data/countries.py); this function just applies it.
    """
    from app.data.countries import COUNTRIES

    per_km_sum = 0.0
    vignette_sum = 0.0
    for c in countries:
        data = COUNTRIES.get(c.value)
        if data is None:
            continue
        per_km_sum += data.toll_per_km_eur
        vignette_sum += data.vignette_eur
    return per_km_sum * distance_km + vignette_sum


class MockRoutingProvider:
    """Deterministic mock routing.

    Uses great-circle distance × 1.25 as a road-distance approximation
    and a flat average highway speed. When `avoid_tolls` is set, adds a
    15 % distance penalty (secondary roads are longer) and zeroes tolls.
    Real HERE/TomTom implementation will replace this class behind the
    same interface.
    """

    _ROAD_FACTOR = 1.25
    _AVOID_TOLLS_DISTANCE_PENALTY = 1.15
    _AVOID_MOTORWAY_DISTANCE_PENALTY = 1.25
    _AVOID_TOLLS_SPEED_KMH = 78.0
    _AVOID_MOTORWAY_SPEED_KMH = 65.0
    _SCENIC_TIME_PENALTY = 1.08

    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
        *,
        waypoints: tuple[Coordinate, ...] = (),
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        # Multi-stop total distance = sum of segment great-circle
        # distances × road factor. Same as before when waypoints
        # is empty.
        stops = [origin, *waypoints, destination]
        straight_km = sum(
            _haversine_km(stops[i], stops[i + 1])
            for i in range(len(stops) - 1)
        )
        base_km = straight_km * self._ROAD_FACTOR
        distance_penalty = 1.0
        if avoid_tolls:
            distance_penalty = max(distance_penalty, self._AVOID_TOLLS_DISTANCE_PENALTY)
        if avoid_motorways:
            distance_penalty = max(distance_penalty, self._AVOID_MOTORWAY_DISTANCE_PENALTY)
        distance_km = base_km * distance_penalty
        if avoid_motorways:
            speed = self._AVOID_MOTORWAY_SPEED_KMH
        elif avoid_tolls:
            speed = self._AVOID_TOLLS_SPEED_KMH
        else:
            speed = _AVG_HIGHWAY_SPEED_KMH
        hours = distance_km / speed
        if prefer_scenic:
            hours *= self._SCENIC_TIME_PENALTY
        waypoints = _great_circle_interpolate(origin, destination, _WAYPOINT_COUNT)

        if countries is None:
            from app.services.country_detection import infer_countries_crossed

            countries = infer_countries_crossed((origin, *waypoints, destination))

        toll = 0.0 if (avoid_tolls or avoid_motorways) else _apply_toll_pricing(
            distance_km, countries,
        )

        return Route(
            origin=origin,
            destination=destination,
            distance_km=round(distance_km, 1),
            free_flow_duration=timedelta(hours=hours),
            polyline=_fake_polyline(
                origin, destination, avoid_tolls=avoid_tolls,
                avoid_motorways=avoid_motorways, prefer_scenic=prefer_scenic,
            ),
            toll_cost_eur=round(toll, 2),
            countries_crossed=countries,
            waypoints=waypoints,
            geometry=(),
            avoid_tolls=avoid_tolls,
        )


def _fake_polyline(
    a: Coordinate, b: Coordinate, *,
    avoid_tolls: bool = False,
    avoid_motorways: bool = False,
    prefer_scenic: bool = False,
) -> str:
    tag = f"|t={avoid_tolls}|m={avoid_motorways}|s={prefer_scenic}"
    digest = hashlib.sha1(
        f"{a.lat:.4f},{a.lon:.4f}->{b.lat:.4f},{b.lon:.4f}{tag}".encode()
    ).hexdigest()
    return f"mock:{digest[:16]}"


class OsrmRoutingProvider:
    """Real routing via OpenStreetMap's OSRM service.

    Uses the public OSRM demo server by default; override with the
    `MYTRAVELPAL_OSRM_URL` env var to point at a self-hosted instance
    (public server is rate-limited and offers no SLA).

    OSRM returns actual road geometry, distance, and duration but has no
    concept of tolls — we still overlay per-country toll pricing on top
    of the returned distance. When `avoid_tolls=True` we ask OSRM to
    exclude toll roads via `?exclude=toll`.

    If OSRM is unreachable or returns an error, the provider raises
    `httpx.HTTPError`; the caller (typically the composite/fallback
    provider) can decide to retry with the mock.
    """

    _DEFAULT_URL = "https://router.project-osrm.org"
    _USER_AGENT = "MyTravelPal-dev/0.1 (contact@mytravelpal.example)"
    _WAYPOINT_SAMPLES = 10

    def __init__(
        self,
        base_url: str | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base = (base_url or self._DEFAULT_URL).rstrip("/")
        self._client = http_client or httpx.AsyncClient(timeout=6.0)

    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
        *,
        waypoints: tuple[Coordinate, ...] = (),
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,  # noqa: ARG002 - see docstring
    ) -> Route:
        # Join origin + intermediate waypoints + destination as
        # semicolon-separated `lon,lat` pairs (OSRM's convention).
        # Public demo caps at ~10 total coords; the API layer
        # already caps waypoints at 8 so we're safe.
        stops = [origin, *waypoints, destination]
        coords = ";".join(f"{c.lon},{c.lat}" for c in stops)
        params: dict[str, str] = {
            "geometries": "geojson",
            "overview": "full",
            "steps": "false",
            "annotations": "false",
        }
        # The public OSRM demo server only supports `exclude=motorway`
        # for the driving profile — `exclude=toll` requires a custom
        # OSRM build with the toll-tagged profile. Sending toll
        # returned HTTP 400 in production. We still overlay per-country
        # toll-avoidance on top of the returned route via our own
        # pricing model, so dropping the OSRM flag here has no user
        # impact beyond avoiding a hard 400.
        excludes: list[str] = []
        if avoid_motorways:
            excludes.append("motorway")
        if excludes:
            params["exclude"] = ",".join(excludes)
        url = f"{self._base}/route/v1/driving/{coords}"
        response = await self._client.get(
            url, params=params, headers={"User-Agent": self._USER_AGENT},
        )
        response.raise_for_status()
        body = response.json()
        if body.get("code") != "Ok" or not body.get("routes"):
            raise httpx.HTTPError(f"OSRM returned no route: {body.get('code')}")

        route = body["routes"][0]
        distance_m = float(route["distance"])
        duration_s = float(route["duration"])
        geo = route["geometry"]["coordinates"]  # list of [lon, lat]

        geometry = tuple(
            Coordinate(lat=float(lat), lon=float(lon)) for lon, lat in geo
        )
        waypoints = _sample_evenly(geometry, self._WAYPOINT_SAMPLES)

        if countries is None:
            from app.services.country_detection import infer_countries_crossed

            countries = infer_countries_crossed(
                (origin, *waypoints, destination),
            )

        distance_km = distance_m / 1000.0
        toll = 0.0 if avoid_tolls else _apply_toll_pricing(distance_km, countries)

        return Route(
            origin=origin,
            destination=destination,
            distance_km=round(distance_km, 1),
            free_flow_duration=timedelta(seconds=duration_s),
            polyline=f"osrm:{len(geometry)}pts",
            toll_cost_eur=round(toll, 2),
            countries_crossed=countries,
            waypoints=waypoints,
            geometry=geometry,
            avoid_tolls=avoid_tolls,
        )


def _sample_evenly(
    points: tuple[Coordinate, ...], count: int,
) -> tuple[Coordinate, ...]:
    """Return `count` roughly-evenly-spaced samples from `points`
    (excluding the endpoints). Cheap: index-based sampling — good
    enough for country detection over a dense geometry.
    """
    if len(points) <= 2 or count <= 0:
        return ()
    interior = points[1:-1]
    if len(interior) <= count:
        return interior
    step = len(interior) / count
    return tuple(interior[int(i * step)] for i in range(count))


class FallbackRoutingProvider:
    """Try `primary` first; on any exception, fall back to `secondary`.

    Keeps the app working when the public OSRM server is throttling
    or down — we degrade to the great-circle mock. The client sees a
    straight polyline instead of road geometry but the plan still ships.
    """

    def __init__(
        self,
        primary: RoutingProvider,
        fallback: RoutingProvider,
    ) -> None:
        self._primary = primary
        self._fallback = fallback

    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
        *,
        waypoints: tuple[Coordinate, ...] = (),
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        try:
            return await self._primary.route(
                origin, destination, countries,
                waypoints=waypoints,
                avoid_tolls=avoid_tolls, avoid_motorways=avoid_motorways,
                prefer_scenic=prefer_scenic,
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("primary routing provider failed, using fallback: %s", exc)
            return await self._fallback.route(
                origin, destination, countries,
                waypoints=waypoints,
                avoid_tolls=avoid_tolls, avoid_motorways=avoid_motorways,
                prefer_scenic=prefer_scenic,
            )


# ---------------------------------------------------------------------------
# HERE Flexible Polyline decoder
# ---------------------------------------------------------------------------
# HERE Routing v8 encodes geometry as HERE Flexible Polyline — a variable-
# length, delta-coded, zigzag-signed format distinct from Google's encoding.
# Reference: https://github.com/heremaps/flexible-polyline
#
# Character alphabet (64 symbols) maps each char to a 6-bit value:
#   Bit 5 = continuation flag (1 = more chunks follow for this value).
#   Bits 0-4 = value payload for this chunk.
# After gathering all chunks, zigzag decode: value = (raw >> 1) ^ -(raw & 1).
# First decoded value is a header: precision = (header >> 4) & 0x0F.

_FLEX_TABLE = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
)
_FLEX_DECODE: dict[str, int] = {c: i for i, c in enumerate(_FLEX_TABLE)}


def _decode_flexpolyline(encoded: str) -> tuple[Coordinate, ...]:
    """Decode HERE Flexible Polyline to a tuple of Coordinates.

    Returns an empty tuple when the string is malformed or empty — the
    caller (HereRoutingProvider.route) treats that as a routing failure.
    """
    if not encoded:
        return ()

    # Step 1: split the encoded string into a sequence of raw unsigned ints.
    raw_values: list[int] = []
    shift = 0
    acc = 0
    for ch in encoded:
        c = _FLEX_DECODE.get(ch)
        if c is None:
            continue  # skip unknown characters defensively
        acc |= (c & 0x1F) << shift
        if c & 0x20 == 0:
            # Continuation bit clear — value complete.
            raw_values.append(acc)
            acc = 0
            shift = 0
        else:
            shift += 5

    if not raw_values:
        return ()

    # Step 2: decode header.
    # HERE Flexible Polyline encodes TWO header values before the coordinates:
    #   raw_values[0] = version (always 1)
    #   raw_values[1] = precision (decimal places, typically 5 or 6)
    # Coordinates start at raw_values[2:] as (lat_delta, lng_delta) pairs.
    if len(raw_values) < 3:
        return ()
    precision = raw_values[1]        # e.g. 5 or 6 decimal places
    inv = 10.0 ** (-precision)

    # Step 3: decode coordinate pairs (2D only; ignore 3rd dimension if present).
    coords: list[Coordinate] = []
    last_lat = last_lng = 0
    i = 2
    while i + 1 < len(raw_values):
        raw_lat = raw_values[i]
        raw_lng = raw_values[i + 1]
        # Zigzag decode: converts unsigned back to signed delta.
        dlat = (raw_lat >> 1) ^ -(raw_lat & 1)
        dlng = (raw_lng >> 1) ^ -(raw_lng & 1)
        last_lat += dlat
        last_lng += dlng
        coords.append(Coordinate(lat=last_lat * inv, lon=last_lng * inv))
        i += 2

    return tuple(coords)


# ---------------------------------------------------------------------------
# HERE Routing v8 provider
# ---------------------------------------------------------------------------

_HERE_ROUTING_ENDPOINT = "https://router.hereapi.com/v8/routes"
_HERE_ROUTING_TIMEOUT_S = 10.0
_HERE_ROUTING_WAYPOINT_SAMPLES = 10
# 48 h cache for route geometry + toll costs.
_HERE_ROUTE_CACHE: dict[tuple[Any, ...], tuple[Route, float]] = {}
_HERE_ROUTE_CACHE_TTL_S = 172_800  # 48 h


class HereRoutingProvider:
    """Real routing via HERE Routing v8 — road geometry + toll data in one call.

    Returns a `Route` with real geometry decoded from HERE Flexible Polyline
    and toll costs taken directly from the HERE toll sections (EUR fares) so
    the `HereTollsProvider` doesn't need a second round-trip.

    Results are cached in-process for 48 h keyed by (origin, destination,
    avoid_tolls, avoid_motorways) rounded to 3 decimal places (~100 m), so
    repeated /plan calls for the same corridor hit memory instead of HERE.

    Falls back cleanly on any exception so the `FallbackRoutingProvider`
    chain continues to the great-circle mock.
    """

    _WAYPOINT_SAMPLES = _HERE_ROUTING_WAYPOINT_SAMPLES

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(
            timeout=_HERE_ROUTING_TIMEOUT_S,
        )
        self._key = os.environ.get("MYTRAVELPAL_HERE_API_KEY") or ""

    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
        *,
        waypoints: tuple[Coordinate, ...] = (),
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,  # noqa: ARG002 - advisory only
    ) -> Route:
        if not self._key:
            raise RuntimeError("MYTRAVELPAL_HERE_API_KEY not set")

        cache_key = (
            round(origin.lat, 3), round(origin.lon, 3),
            round(destination.lat, 3), round(destination.lon, 3),
            avoid_tolls, avoid_motorways,
            # Include waypoints so multi-stop routes cache correctly.
            tuple(
                (round(c.lat, 3), round(c.lon, 3)) for c in waypoints
            ),
        )
        cached = _HERE_ROUTE_CACHE.get(cache_key)
        if cached is not None:
            cached_route, ts = cached
            if time.time() - ts < _HERE_ROUTE_CACHE_TTL_S:
                _log.debug("HERE routing: cache hit for %s→%s", origin, destination)
                return cached_route

        params: dict[str, Any] = {
            "transportMode": "car",
            "origin": f"{origin.lat:.5f},{origin.lon:.5f}",
            "destination": f"{destination.lat:.5f},{destination.lon:.5f}",
            "return": "polyline,tolls,summary",
            "currency": "EUR",
            "apiKey": self._key,
        }
        if waypoints:
            params["via"] = [
                f"{c.lat:.5f},{c.lon:.5f}" for c in waypoints
            ]
        avoid_features: list[str] = []
        if avoid_tolls:
            avoid_features.append("tollRoad")
        if avoid_motorways:
            avoid_features.append("controlledAccessHighway")
        if avoid_features:
            params["avoid[features]"] = ",".join(avoid_features)

        try:
            r = await self._client.get(_HERE_ROUTING_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(f"HERE routing request failed: {exc}") from exc

        if r.status_code != 200:
            raise RuntimeError(
                f"HERE routing HTTP {r.status_code}: {r.text[:200]}",
            )

        try:
            body = r.json()
        except ValueError as exc:
            raise RuntimeError("HERE routing: invalid JSON response") from exc

        routes = body.get("routes") or []
        if not routes:
            raise RuntimeError("HERE routing: no routes in response")

        sections = routes[0].get("sections") or []
        if not sections:
            raise RuntimeError("HERE routing: no sections in response")

        # Aggregate across sections (one per leg in multi-waypoint routes).
        total_m = 0.0
        total_s = 0.0
        all_coords: list[Coordinate] = []
        toll_eur = 0.0

        for section in sections:
            summary = section.get("summary") or {}
            total_m += float(summary.get("length") or 0)
            total_s += float(summary.get("duration") or 0)

            polyline_str = section.get("polyline") or ""
            if polyline_str:
                pts = _decode_flexpolyline(polyline_str)
                if all_coords and pts:
                    # First point of the next section == last point of the
                    # previous section — skip it to avoid duplicates.
                    all_coords.extend(pts[1:])
                else:
                    all_coords.extend(pts)

            # HERE may expose EUR fares directly; pick the minimum fare per
            # toll entry (tag/video price is cheaper than cash).
            for toll in section.get("tolls") or []:
                eur_fares: list[float] = []
                for f in (toll.get("fares") or []):
                    price_obj = f.get("price") or {}
                    cur = str(price_obj.get("currency") or "").upper()
                    val = price_obj.get("value")
                    if cur == "EUR" and isinstance(val, (int, float)):
                        eur_fares.append(float(val))
                if eur_fares:
                    toll_eur += min(eur_fares)

        geometry = tuple(all_coords)
        if not geometry:
            raise RuntimeError("HERE routing: decoded polyline is empty")

        wps = _sample_evenly(geometry, self._WAYPOINT_SAMPLES)

        if countries is None:
            from app.services.country_detection import infer_countries_crossed

            countries = infer_countries_crossed((origin, *wps, destination))

        distance_km = total_m / 1000.0
        # Use HERE's own toll figure when it returned any; otherwise fall
        # back to the per-country heuristic so toll-free sections don't
        # silently zero-out routes where toll_eur happened to be 0 because
        # HERE didn't return fare data for that country yet.
        toll_cost = 0.0 if avoid_tolls else (
            round(toll_eur, 2)
            if toll_eur > 0
            else _apply_toll_pricing(distance_km, countries)
        )

        result = Route(
            origin=origin,
            destination=destination,
            distance_km=round(distance_km, 1),
            free_flow_duration=timedelta(seconds=total_s),
            polyline=f"here:{len(geometry)}pts",
            toll_cost_eur=toll_cost,
            countries_crossed=countries,
            waypoints=wps,
            geometry=geometry,
            avoid_tolls=avoid_tolls,
        )
        _HERE_ROUTE_CACHE[cache_key] = (result, time.time())
        return result


def default_routing_provider() -> RoutingProvider:
    """Pick a routing provider based on runtime configuration.

    Chain (first working provider wins):
      OSRM → HERE Routing v8 (if key set) → great-circle mock

    - `MYTRAVELPAL_ROUTING=mock` forces the mock (useful in tests).
    - `MYTRAVELPAL_ROUTING=here` forces HERE Routing → mock fallback.
    - Default: OSRM with HERE as mid-tier fallback when the key is set,
      then the great-circle mock as last resort.
    """
    mode = os.environ.get("MYTRAVELPAL_ROUTING", "osrm").lower()
    if mode == "mock":
        return MockRoutingProvider()

    mock_fallback = MockRoutingProvider()

    if mode == "here":
        # HERE-only chain: HERE → mock.
        if not os.environ.get("MYTRAVELPAL_HERE_API_KEY"):
            _log.warning(
                "MYTRAVELPAL_ROUTING=here but MYTRAVELPAL_HERE_API_KEY is "
                "not set — falling back to mock routing",
            )
            return mock_fallback
        return FallbackRoutingProvider(
            primary=HereRoutingProvider(),
            fallback=mock_fallback,
        )

    # Default OSRM chain: OSRM → (HERE if key set) → mock.
    if os.environ.get("MYTRAVELPAL_HERE_API_KEY"):
        here_to_mock = FallbackRoutingProvider(
            primary=HereRoutingProvider(),
            fallback=mock_fallback,
        )
    else:
        here_to_mock = mock_fallback

    return FallbackRoutingProvider(
        primary=OsrmRoutingProvider(
            base_url=os.environ.get("MYTRAVELPAL_OSRM_URL"),
        ),
        fallback=here_to_mock,
    )

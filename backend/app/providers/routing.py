from __future__ import annotations

import hashlib
import logging
import os
from datetime import timedelta
from math import asin, atan2, cos, degrees, radians, sin, sqrt
from typing import Protocol

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
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        """Return a Route from origin to destination.

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
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        straight_km = _haversine_km(origin, destination)
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
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,  # noqa: ARG002 - see docstring
    ) -> Route:
        coords = f"{origin.lon},{origin.lat};{destination.lon},{destination.lat}"
        params: dict[str, str] = {
            "geometries": "geojson",
            "overview": "full",
            "steps": "false",
            "annotations": "false",
        }
        excludes: list[str] = []
        if avoid_tolls:
            excludes.append("toll")
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
        avoid_tolls: bool = False,
        avoid_motorways: bool = False,
        prefer_scenic: bool = False,
    ) -> Route:
        try:
            return await self._primary.route(
                origin, destination, countries,
                avoid_tolls=avoid_tolls, avoid_motorways=avoid_motorways,
                prefer_scenic=prefer_scenic,
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("primary routing provider failed, using fallback: %s", exc)
            return await self._fallback.route(
                origin, destination, countries,
                avoid_tolls=avoid_tolls, avoid_motorways=avoid_motorways,
                prefer_scenic=prefer_scenic,
            )


def default_routing_provider() -> RoutingProvider:
    """Pick a routing provider based on runtime configuration.

    - `MYTRAVELPAL_ROUTING=mock` forces the mock (useful in tests).
    - Otherwise: OSRM (base URL from `MYTRAVELPAL_OSRM_URL` or the public
      demo server) with an automatic fallback to the mock on failure.
    """
    mode = os.environ.get("MYTRAVELPAL_ROUTING", "osrm").lower()
    if mode == "mock":
        return MockRoutingProvider()
    return FallbackRoutingProvider(
        primary=OsrmRoutingProvider(base_url=os.environ.get("MYTRAVELPAL_OSRM_URL")),
        fallback=MockRoutingProvider(),
    )

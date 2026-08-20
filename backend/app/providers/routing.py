from __future__ import annotations

import hashlib
from datetime import timedelta
from math import asin, atan2, cos, degrees, radians, sin, sqrt
from typing import Protocol

from app.domain import Coordinate, Country, Route

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
    ) -> Route:
        """Return a Route from origin to destination.

        If `countries` is None, the provider infers them from the route
        geometry (via waypoints). When provided, `countries` overrides
        the inference — useful when the caller has authoritative info.
        """
        ...


class MockRoutingProvider:
    """Deterministic mock routing.

    Uses great-circle distance × 1.25 as a road-distance approximation and
    a flat average highway speed. Real HERE/TomTom implementation will
    replace this class behind the same interface.
    """

    _ROAD_FACTOR = 1.25

    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...] | None = None,
    ) -> Route:
        straight_km = _haversine_km(origin, destination)
        distance_km = straight_km * self._ROAD_FACTOR
        hours = distance_km / _AVG_HIGHWAY_SPEED_KMH
        waypoints = _great_circle_interpolate(origin, destination, _WAYPOINT_COUNT)

        if countries is None:
            # Import inside the method to avoid a circular dependency at
            # module load between providers and services.
            from app.services.country_detection import infer_countries_crossed

            countries = infer_countries_crossed((origin, *waypoints, destination))

        # Toll approximation per country — realistic-ish order of magnitude.
        per_km_by_country = {
            Country.FR: 0.09,
            Country.IT: 0.08,
            Country.ES: 0.07,
            Country.CH: 0.0,  # CH uses an annual vignette, not per-km tolls.
        }
        toll = sum(per_km_by_country.get(c, 0.0) for c in countries) * distance_km
        if Country.CH in countries:
            toll += 40.0  # amortized vignette contribution

        polyline = _fake_polyline(origin, destination)

        return Route(
            origin=origin,
            destination=destination,
            distance_km=round(distance_km, 1),
            free_flow_duration=timedelta(hours=hours),
            polyline=polyline,
            toll_cost_eur=round(toll, 2),
            countries_crossed=countries,
            waypoints=waypoints,
        )


def _fake_polyline(a: Coordinate, b: Coordinate) -> str:
    """Placeholder polyline id. Real providers return encoded polyline geometry."""
    digest = hashlib.sha1(
        f"{a.lat:.4f},{a.lon:.4f}->{b.lat:.4f},{b.lon:.4f}".encode()
    ).hexdigest()
    return f"mock:{digest[:16]}"

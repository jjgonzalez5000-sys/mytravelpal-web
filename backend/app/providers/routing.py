from __future__ import annotations

import hashlib
from datetime import timedelta
from math import asin, cos, radians, sin, sqrt
from typing import Protocol

from app.domain import Coordinate, Country, Route

_EARTH_RADIUS_KM = 6371.0
_AVG_HIGHWAY_SPEED_KMH = 95.0


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    lat1, lon1, lat2, lon2 = map(radians, (a.lat, a.lon, b.lat, b.lon))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * asin(sqrt(h))


class RoutingProvider(Protocol):
    async def route(
        self,
        origin: Coordinate,
        destination: Coordinate,
        countries: tuple[Country, ...],
    ) -> Route: ...


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
        countries: tuple[Country, ...],
    ) -> Route:
        straight_km = _haversine_km(origin, destination)
        distance_km = straight_km * self._ROAD_FACTOR
        hours = distance_km / _AVG_HIGHWAY_SPEED_KMH

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
        )


def _fake_polyline(a: Coordinate, b: Coordinate) -> str:
    """Placeholder polyline id. Real providers return encoded polyline geometry."""
    digest = hashlib.sha1(
        f"{a.lat:.4f},{a.lon:.4f}->{b.lat:.4f},{b.lon:.4f}".encode()
    ).hexdigest()
    return f"mock:{digest[:16]}"

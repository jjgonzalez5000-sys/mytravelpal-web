"""Filter adverse events to those close enough to the route to matter."""

from __future__ import annotations

from app.domain import AdverseEvent, Coordinate, Route
from app.providers.routing import _haversine_km

_DEFAULT_MAX_DISTANCE_KM = 25.0


def _min_distance_to_route(event_coord: Coordinate, route: Route) -> float:
    """Great-circle distance from `event_coord` to the closest point on the
    origin → waypoints → destination polyline (each pair of adjacent points
    treated as a straight great-circle segment; the whole segment is
    approximated by its two endpoints for MVP purposes).
    """
    points = (route.origin, *route.waypoints, route.destination)
    return min(_haversine_km(event_coord, p) for p in points)


def filter_events_near_route(
    events: tuple[AdverseEvent, ...],
    route: Route,
    *,
    max_distance_km: float = _DEFAULT_MAX_DISTANCE_KM,
    limit: int = 20,
) -> tuple[AdverseEvent, ...]:
    """Return events within `max_distance_km` of the route, sorted by
    severity (critical first) then by proximity.
    """
    severity_order = {"critical": 0, "warning": 1, "info": 2}
    scored: list[tuple[float, int, AdverseEvent]] = []
    for e in events:
        d = _min_distance_to_route(e.coordinate, route)
        if d <= max_distance_km:
            scored.append((d, severity_order.get(e.severity.value, 3), e))
    scored.sort(key=lambda t: (t[1], t[0]))
    return tuple(e for _, _, e in scored[:limit])

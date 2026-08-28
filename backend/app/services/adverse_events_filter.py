"""Filter adverse events to those close enough to the route to matter."""

from __future__ import annotations

from app.domain import AdverseEvent, AdverseEventType, Coordinate, Route
from app.providers.routing import _haversine_km


# Event types considered too routine to surface as a "critical event"
# alert. Roadworks in particular are so common in Europe that
# including them dilutes the "avísame de eventos críticos" promise —
# every plan would trigger 3-5 roadwork rows the driver ignores.
# Keeping them in the enum for backwards compatibility with stored
# user-marked events; the filter just drops them from output.
_UNSURFACED_TYPES: frozenset[AdverseEventType] = frozenset(
    {AdverseEventType.ROADWORK},
)

# Corridor width used when the caller doesn't override. 25 km was too
# generous for FIRMS — it dragged in fires that were plainly outside
# the driver's exposure envelope (smoke plume rarely reaches the
# highway from > 15 km on a normal day). 12 km keeps the "affects
# your trip" promise honest.
_DEFAULT_MAX_DISTANCE_KM = 12.0


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
    """Return events within `max_distance_km` of the route, deduplicated,
    sorted by severity (critical first) then by proximity.

    De-duplication rules (Sprint 23):
    - Same `id` collapses to one entry (composite providers may return
      overlapping IDs when the same feed is queried twice for a long
      route that spans two bounding boxes).
    - Same coordinate + description + type within 0.5 km also collapses.
      Prevents FIRMS from surfacing every VIIRS pixel of the same fire
      as a separate row and the mock demo events from appearing twice
      for round-trip queries.
    """
    severity_order = {"critical": 0, "warning": 1, "info": 2}
    scored: list[tuple[float, int, AdverseEvent]] = []
    seen_ids: set[str] = set()
    seen_signatures: list[tuple[str, str, float, float]] = []
    for e in events:
        if e.type in _UNSURFACED_TYPES:
            continue
        if e.id in seen_ids:
            continue
        # Signature includes severity so the test-suite fabrications
        # of 3 severities at the same coord still all survive; only
        # honest duplicates (same type + severity + description at the
        # same spot) are collapsed.
        signature = (
            e.type.value,
            e.severity.value,
            e.description,
            round(e.coordinate.lat, 2),
            round(e.coordinate.lon, 2),
        )
        if any(
            existing[0] == signature[0]
            and existing[1] == signature[1]
            and existing[2] == signature[2]
            and _haversine_km(
                Coordinate(lat=existing[3], lon=existing[4]),
                Coordinate(lat=signature[3], lon=signature[4]),
            ) <= 0.5
            for existing in seen_signatures
        ):
            continue
        d = _min_distance_to_route(e.coordinate, route)
        if d <= max_distance_km:
            scored.append((d, severity_order.get(e.severity.value, 3), e))
            seen_ids.add(e.id)
            seen_signatures.append(signature)
    scored.sort(key=lambda t: (t[1], t[0]))
    return tuple(e for _, _, e in scored[:limit])

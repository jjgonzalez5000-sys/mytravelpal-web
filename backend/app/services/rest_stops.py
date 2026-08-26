"""Recommend safety rest stops along a route.

Common European guidance (ADAC, DGT, FIA) is a short break every ~2h of
continuous driving. We surface stops at each 2h mark along the trip's
free-flow duration.
"""

from __future__ import annotations

from app.domain import RestStop, Route
from app.providers.routing import _haversine_km, point_at_fraction

_DEFAULT_INTERVAL_HOURS = 2.0
_DEFAULT_BREAK_MINUTES = 15


def compute_rest_stops(
    route: Route,
    *,
    interval_hours: float = _DEFAULT_INTERVAL_HOURS,
    break_minutes: int = _DEFAULT_BREAK_MINUTES,
) -> tuple[RestStop, ...]:
    """Return rest stops every `interval_hours` of driving.

    Empty tuple if the trip is shorter than one interval — nothing to
    recommend on a short hop.

    When the route has real polyline geometry (OSRM primary provider),
    we WALK the polyline to place each rest stop at its actual
    on-road coordinate — critical for hotel / restaurant matching:
    a great-circle interpolation between origin and destination
    lands the stop dozens of km off the real road for any route
    with meaningful curvature (mountain passes, coastal detours).
    Without geometry (mock provider), fall back to great-circle
    interpolation.
    """
    total_hours = route.free_flow_duration.total_seconds() / 3600.0
    if total_hours < interval_hours:
        return ()

    walker = _PolylineWalker(route) if route.geometry else None
    n_stops = int(total_hours // interval_hours)
    stops: list[RestStop] = []
    for i in range(1, n_stops + 1):
        cumulative_hours = i * interval_hours
        # Don't recommend a stop within 15 min of arrival — the driver has
        # essentially arrived.
        if total_hours - cumulative_hours < 0.25:
            break
        fraction = cumulative_hours / total_hours
        target_km = fraction * route.distance_km
        if walker is not None:
            coord = walker.point_at_km(target_km)
        else:
            coord = point_at_fraction(
                route.origin, route.destination, fraction,
            )
        stops.append(
            RestStop(
                coordinate=coord,
                distance_from_origin_km=round(target_km, 1),
                cumulative_driving_hours=round(cumulative_hours, 2),
                recommended_break_minutes=break_minutes,
            )
        )
    return tuple(stops)


class _PolylineWalker:
    """Precomputes cumulative distance along the polyline so
    `point_at_km(km)` is O(log n) via binary search. Building the
    prefix-sum is O(n) but we do it once per plan.
    """

    __slots__ = ("_points", "_cum_km")

    def __init__(self, route: Route) -> None:
        pts = route.geometry
        cum: list[float] = [0.0]
        acc = 0.0
        for i in range(1, len(pts)):
            acc += _haversine_km(pts[i - 1], pts[i])
            cum.append(acc)
        self._points = pts
        self._cum_km = cum

    def point_at_km(self, km: float):
        # Clamp to the polyline's own length — the polyline sum can
        # drift from OSRM's reported distance by a % due to
        # simplification; picking the last point on overflow is
        # safer than an out-of-bounds bisect.
        if not self._cum_km:
            return self._points[0]
        km = max(0.0, min(km, self._cum_km[-1]))
        # Binary search for the segment containing `km`.
        from bisect import bisect_left
        i = bisect_left(self._cum_km, km)
        if i == 0:
            return self._points[0]
        if i >= len(self._points):
            return self._points[-1]
        # Interpolate between points[i-1] and points[i].
        prev_km = self._cum_km[i - 1]
        seg_km = self._cum_km[i] - prev_km
        if seg_km <= 0:
            return self._points[i]
        t = (km - prev_km) / seg_km
        a, b = self._points[i - 1], self._points[i]
        return type(a)(
            lat=a.lat + (b.lat - a.lat) * t,
            lon=a.lon + (b.lon - a.lon) * t,
        )

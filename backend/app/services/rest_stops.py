"""Recommend safety rest stops along a route.

Common European guidance (ADAC, DGT, FIA) is a short break every ~2h of
continuous driving. We surface stops at each 2h mark along the trip's
free-flow duration.
"""

from __future__ import annotations

from app.domain import RestStop, Route
from app.providers.routing import point_at_fraction

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
    """
    total_hours = route.free_flow_duration.total_seconds() / 3600.0
    if total_hours < interval_hours:
        return ()

    n_stops = int(total_hours // interval_hours)
    stops: list[RestStop] = []
    for i in range(1, n_stops + 1):
        cumulative_hours = i * interval_hours
        # Don't recommend a stop within 15 min of arrival — the driver has
        # essentially arrived.
        if total_hours - cumulative_hours < 0.25:
            break
        fraction = cumulative_hours / total_hours
        coord = point_at_fraction(route.origin, route.destination, fraction)
        distance_km = round(fraction * route.distance_km, 1)
        stops.append(
            RestStop(
                coordinate=coord,
                distance_from_origin_km=distance_km,
                cumulative_driving_hours=round(cumulative_hours, 2),
                recommended_break_minutes=break_minutes,
            )
        )
    return tuple(stops)

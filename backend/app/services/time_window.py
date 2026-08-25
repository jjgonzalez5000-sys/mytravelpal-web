"""Optimal-departure-window computation.

Given a route and a desired departure time, samples travel time across a
window around it and returns the top-N options sorted by estimated total
duration. This is MyTravelPal's core differentiating feature.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.domain import Route, TimeWindow
from app.providers import TrafficProvider


def minutes_saved_vs_desired(
    windows: tuple[TimeWindow, ...],
    desired_departure_at: datetime,
) -> float:
    """Time (in minutes) saved by taking the recommended window instead
    of the sample closest to the user's desired departure time.

    Positive → recommendation is faster than the original choice.
    Negative → recommendation is slower (shouldn't happen but keeps
    the sign contract explicit).
    Zero if no windows returned.
    """
    if not windows:
        return 0.0
    recommended = next(
        (w for w in windows if w.recommended),
        windows[0],
    )
    # The sample closest to the desired time — that's what the driver
    # would have taken without our nudge.
    at_desired = min(
        windows,
        key=lambda w: abs((w.departure_at - desired_departure_at).total_seconds()),
    )
    delta_seconds = (
        at_desired.estimated_duration.total_seconds()
        - recommended.estimated_duration.total_seconds()
    )
    return round(delta_seconds / 60.0, 1)


@dataclass(frozen=True, slots=True)
class TimeWindowConfig:
    window_span: timedelta = timedelta(hours=3)
    sample_step: timedelta = timedelta(minutes=30)
    top_n: int = 5


async def compute_time_windows(
    route: Route,
    desired_departure_at: datetime,
    traffic: TrafficProvider,
    config: TimeWindowConfig | None = None,
) -> tuple[TimeWindow, ...]:
    """Sample travel time in a ±span range around desired_departure_at.

    Returns the top-N candidates ordered by estimated duration ascending.
    The first result is flagged `recommended=True`. Ties are broken by
    proximity to the desired departure time (closer wins).
    """
    cfg = config or TimeWindowConfig()

    candidates: list[TimeWindow] = []
    start = desired_departure_at - cfg.window_span
    end = desired_departure_at + cfg.window_span
    cursor = start
    while cursor <= end:
        factor = await traffic.factor_at(route, cursor)
        duration = timedelta(seconds=route.free_flow_duration.total_seconds() * factor)
        candidates.append(
            TimeWindow(
                departure_at=cursor,
                estimated_duration=duration,
                traffic_factor=round(factor, 3),
            )
        )
        cursor += cfg.sample_step

    def _sort_key(tw: TimeWindow) -> tuple[float, float]:
        return (
            tw.estimated_duration.total_seconds(),
            abs((tw.departure_at - desired_departure_at).total_seconds()),
        )

    ordered = sorted(candidates, key=_sort_key)[: cfg.top_n]
    if not ordered:
        return ()

    best, *rest = ordered
    recommended = TimeWindow(
        departure_at=best.departure_at,
        estimated_duration=best.estimated_duration,
        traffic_factor=best.traffic_factor,
        recommended=True,
    )
    return (recommended, *rest)

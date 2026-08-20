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

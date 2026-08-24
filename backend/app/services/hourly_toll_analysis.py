"""Hourly toll analysis — Premium feature.

At peak traffic hours the toll route slows down (traffic factor > 1.5x).
Sometimes the toll-free detour, which is longer in distance but doesn't
suffer from rush-hour congestion, becomes competitive on time — and it
also saves the toll money. This service tells the user which hours of
the day are the ones where skipping tolls actually wins.

Pure function over a route and a traffic provider — no LLM.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.domain import Route
from app.providers import TrafficProvider


@dataclass(frozen=True, slots=True)
class HourlyTollVerdict:
    hour: int
    toll_route_minutes: float
    toll_free_route_minutes: float
    savings_eur: float
    recommendation: str  # "keep_tolls" | "skip_tolls" | "neutral"


@dataclass(frozen=True, slots=True)
class HourlyTollReport:
    verdicts: tuple[HourlyTollVerdict, ...]
    best_hours_to_skip: tuple[int, ...]
    worst_hours_to_skip: tuple[int, ...]


async def analyze(
    *,
    reference_day: datetime,
    main_route: Route,
    toll_free_route: Route,
    traffic: TrafficProvider,
) -> HourlyTollReport:
    """For each hour of `reference_day`, compare:
        toll_route_minutes at that hour (adjusted by traffic factor)
        vs toll_free_route_minutes (assumed less traffic-sensitive).
    Emit a per-hour verdict and highlight the best/worst hours.
    """
    savings = main_route.toll_cost_eur - toll_free_route.toll_cost_eur
    verdicts: list[HourlyTollVerdict] = []

    for hour in range(24):
        at = reference_day.replace(
            hour=hour, minute=0, second=0, microsecond=0,
        )
        toll_factor = await traffic.factor_at(main_route, at)
        free_factor = await traffic.factor_at(toll_free_route, at)
        # Secondary roads see much less commuter congestion — dampen the
        # traffic factor towards 1.0 by 60 % for the toll-free route.
        free_factor = 1.0 + (free_factor - 1.0) * 0.4
        toll_time = main_route.free_flow_duration.total_seconds() / 60.0 * toll_factor
        free_time = (
            toll_free_route.free_flow_duration.total_seconds() / 60.0 * free_factor
        )
        diff = free_time - toll_time
        if diff < 5 and savings >= 5:
            recommendation = "skip_tolls"
        elif diff > 30:
            recommendation = "keep_tolls"
        else:
            recommendation = "neutral"
        verdicts.append(
            HourlyTollVerdict(
                hour=hour,
                toll_route_minutes=round(toll_time, 1),
                toll_free_route_minutes=round(free_time, 1),
                savings_eur=round(savings, 2),
                recommendation=recommendation,
            )
        )

    scored = sorted(verdicts, key=lambda v: v.toll_free_route_minutes - v.toll_route_minutes)
    return HourlyTollReport(
        verdicts=tuple(verdicts),
        best_hours_to_skip=tuple(v.hour for v in scored[:3]),
        worst_hours_to_skip=tuple(v.hour for v in scored[-3:]),
    )


def _midnight(dt: datetime) -> datetime:
    return dt.replace(hour=0, minute=0, second=0, microsecond=0)


__all__ = [
    "HourlyTollReport",
    "HourlyTollVerdict",
    "analyze",
    "_midnight",
]


# Convenience wrapper accepting a plain travel duration in hours if the
# caller only has that + a target date.
def make_toll_free_stub(
    reference_hours: float, toll_free_hours: float, toll_free_cost: float = 0.0,
) -> Route:
    """Test-friendly helper that builds a bare-minimum toll-free Route
    from just a duration & cost.

    Kept next to the analyser so tests don't have to reconstruct the
    whole domain object hierarchy just to call it.
    """
    from app.domain import Coordinate, Country

    return Route(
        origin=Coordinate(0, 0), destination=Coordinate(0, 0),
        distance_km=0,
        free_flow_duration=timedelta(hours=toll_free_hours),
        polyline='stub',
        toll_cost_eur=toll_free_cost,
        countries_crossed=(Country.FR,),
    )

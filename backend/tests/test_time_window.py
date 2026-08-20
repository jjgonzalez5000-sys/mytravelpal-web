from __future__ import annotations

from datetime import datetime, timedelta

import pytest

from app.domain import Coordinate, Country, Route
from app.services.time_window import TimeWindowConfig, compute_time_windows


class _ConstantTraffic:
    def __init__(self, factor: float) -> None:
        self._factor = factor

    async def factor_at(self, route: Route, when: datetime) -> float:  # noqa: ARG002
        return self._factor


class _RushHourTraffic:
    """1.0 baseline; 2.0 between 07:00 and 09:00 local naive time."""

    async def factor_at(self, route: Route, when: datetime) -> float:  # noqa: ARG002
        return 2.0 if 7 <= when.hour < 9 else 1.0


def _route(duration_minutes: float = 120.0) -> Route:
    return Route(
        origin=Coordinate(lat=48.85, lon=2.35),
        destination=Coordinate(lat=45.76, lon=4.83),
        distance_km=500.0,
        free_flow_duration=timedelta(minutes=duration_minutes),
        polyline="mock:test",
        toll_cost_eur=25.0,
        countries_crossed=(Country.FR,),
    )


@pytest.mark.asyncio
async def test_windows_are_ordered_by_duration_ascending() -> None:
    desired = datetime(2026, 8, 24, 8, 0)  # Monday 08:00 — inside rush hour
    windows = await compute_time_windows(_route(), desired, _RushHourTraffic())

    assert len(windows) > 0
    durations = [w.estimated_duration for w in windows]
    assert durations == sorted(durations)


@pytest.mark.asyncio
async def test_top_result_is_flagged_recommended_and_only_it() -> None:
    desired = datetime(2026, 8, 24, 8, 0)
    windows = await compute_time_windows(_route(), desired, _RushHourTraffic())

    assert windows[0].recommended is True
    assert all(not w.recommended for w in windows[1:])


@pytest.mark.asyncio
async def test_rush_hour_windows_are_skipped_in_favor_of_off_peak() -> None:
    desired = datetime(2026, 8, 24, 8, 0)
    windows = await compute_time_windows(_route(), desired, _RushHourTraffic())

    top = windows[0]
    # Best window should be outside 07:00-09:00 rush hour.
    assert not (7 <= top.departure_at.hour < 9)
    assert top.traffic_factor == 1.0


@pytest.mark.asyncio
async def test_tie_breaks_favor_windows_closer_to_desired_time() -> None:
    """With constant traffic, all durations tie. The desired time (or the
    sample equal to it) should be the recommendation.
    """
    desired = datetime(2026, 8, 24, 12, 0)
    windows = await compute_time_windows(_route(), desired, _ConstantTraffic(1.0))

    assert windows[0].departure_at == desired
    assert windows[0].recommended is True


@pytest.mark.asyncio
async def test_returns_at_most_top_n_windows() -> None:
    desired = datetime(2026, 8, 24, 12, 0)
    cfg = TimeWindowConfig(
        window_span=timedelta(hours=3),
        sample_step=timedelta(minutes=30),
        top_n=3,
    )
    windows = await compute_time_windows(_route(), desired, _ConstantTraffic(1.0), cfg)

    assert len(windows) == 3


@pytest.mark.asyncio
async def test_empty_span_returns_single_sample() -> None:
    """A zero-span config still returns the desired time itself."""
    desired = datetime(2026, 8, 24, 12, 0)
    cfg = TimeWindowConfig(
        window_span=timedelta(0),
        sample_step=timedelta(minutes=30),
        top_n=5,
    )
    windows = await compute_time_windows(_route(), desired, _ConstantTraffic(1.0), cfg)

    assert len(windows) == 1
    assert windows[0].departure_at == desired
    assert windows[0].recommended is True

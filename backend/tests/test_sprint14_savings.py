"""Sprint 14: time_saved_vs_desired computation + savings field on
`/trips/plan`.
"""

from __future__ import annotations

from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.domain import TimeWindow
from app.main import app
from app.services.time_window import minutes_saved_vs_desired

client = TestClient(app)


def _tw(*, at: datetime, minutes: float, recommended: bool = False) -> TimeWindow:
    return TimeWindow(
        departure_at=at,
        estimated_duration=timedelta(minutes=minutes),
        traffic_factor=1.0,
        recommended=recommended,
    )


class TestMinutesSavedVsDesired:
    def test_returns_zero_when_recommended_matches_desired_time(self) -> None:
        desired = datetime(2026, 8, 24, 8)
        windows = (
            _tw(at=desired, minutes=100, recommended=True),
            _tw(at=desired + timedelta(hours=1), minutes=120),
        )
        assert minutes_saved_vs_desired(windows, desired) == 0

    def test_positive_when_recommended_is_faster_than_desired_sample(self) -> None:
        desired = datetime(2026, 8, 24, 8)
        windows = (
            _tw(at=desired - timedelta(hours=2), minutes=60, recommended=True),
            _tw(at=desired, minutes=120),  # at desired: slow
            _tw(at=desired + timedelta(hours=2), minutes=80),
        )
        # 120 - 60 = 60 min saved
        assert minutes_saved_vs_desired(windows, desired) == 60.0

    def test_empty_windows_returns_zero(self) -> None:
        assert minutes_saved_vs_desired((), datetime(2026, 8, 24, 8)) == 0

    def test_picks_closest_sample_to_desired(self) -> None:
        desired = datetime(2026, 8, 24, 8)
        windows = (
            _tw(at=desired - timedelta(hours=3), minutes=90, recommended=True),
            _tw(at=desired - timedelta(minutes=30), minutes=110),  # closest
            _tw(at=desired + timedelta(hours=3), minutes=80),
        )
        # closest = 110; recommended = 90 → 20 min saved
        assert minutes_saved_vs_desired(windows, desired) == 20.0


class TestPlanEndpointSavings:
    def _plan(self, **extra):
        payload = {
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            **extra,
        }
        response = client.post("/v1/trips/plan", json=payload)
        assert response.status_code == 200, response.text
        return response.json()

    def test_savings_field_always_present(self) -> None:
        body = self._plan()
        assert "savings" in body
        s = body["savings"]
        assert "time_saved_minutes_vs_desired" in s
        assert "money_saved_eur_vs_tolls" in s

    def test_time_savings_is_non_negative_number(self) -> None:
        body = self._plan()
        assert body["savings"]["time_saved_minutes_vs_desired"] >= 0

    def test_money_saved_reflects_toll_alternative_when_worth_it(self) -> None:
        # Short trip in France where the alternative is Marginal by
        # default heuristic. Money saved should be 0.
        body = self._plan(include_toll_alternative=True)
        savings = body["savings"]["money_saved_eur_vs_tolls"]
        alt = body["toll_alternative"]
        if alt and alt["worth_it"]:
            assert savings == alt["savings_eur"]
        else:
            assert savings == 0.0

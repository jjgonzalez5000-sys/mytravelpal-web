"""Tests for POST /v1/trips/adverse-refresh — the Companion-mode
live re-scan endpoint. Verifies that polyline slicing correctly
bounds the corridor and that the event filter still drops out-of-
range items.
"""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.api.v1.trips import _slice_polyline_by_km
from app.domain import Coordinate
from app.main import app


client = TestClient(app)


def _linear_polyline(km_target: float, points: int = 20) -> list[Coordinate]:
    """Straight-line polyline of approximately `km_target` km — walks
    due east from (45, 0) so 1 deg lon ≈ 78.7 km at that latitude.
    Enough for slicing tests without pulling real OSRM geometry.
    """
    step_deg = (km_target / 78.7) / (points - 1)
    return [Coordinate(lat=45.0, lon=step_deg * i) for i in range(points)]


class TestSlicePolyline:
    def test_slice_returns_points_within_window(self) -> None:
        poly = _linear_polyline(1000.0, points=50)
        sliced, from_km, to_km, dist = _slice_polyline_by_km(
            poly, current_km=200.0, look_ahead_km=200.0,
        )
        assert len(sliced) >= 2
        assert from_km == 200.0
        # to_km is current + actual sliced distance — should be close
        # to 200 km (± vertex quantisation on a 50-point polyline).
        assert 150.0 <= dist <= 210.0
        assert to_km <= 410.0

    def test_slice_at_zero_starts_from_origin(self) -> None:
        poly = _linear_polyline(500.0, points=20)
        sliced, from_km, _to_km, dist = _slice_polyline_by_km(
            poly, current_km=0.0, look_ahead_km=100.0,
        )
        assert from_km == 0.0
        assert dist > 70.0 and dist < 110.0
        # The first sliced point sits at (or very near) the origin —
        # the endpoint anchoring shouldn't move it far.
        assert sliced[0].lon < 0.1

    def test_slice_past_end_returns_empty(self) -> None:
        poly = _linear_polyline(500.0, points=20)
        sliced, _from, _to, dist = _slice_polyline_by_km(
            poly, current_km=600.0, look_ahead_km=200.0,
        )
        assert sliced == []
        assert dist == 0.0

    def test_slice_short_polyline_short_circuits(self) -> None:
        sliced, _f, _t, dist = _slice_polyline_by_km(
            [Coordinate(lat=45.0, lon=0.0)], 0.0, 200.0,
        )
        assert sliced == []
        assert dist == 0.0


class TestAdverseRefreshEndpoint:
    def _payload(self, **extra: object) -> dict:
        # Paris → east: ~500 km of straight-line polyline, no real
        # events will hit in the mock provider (Paris strike is at
        # km 0 which we skip when current_km > 0), which is what
        # we want for the "empty near_km returns nothing" assertion.
        poly = _linear_polyline(500.0, points=30)
        return {
            "geometry": [{"lat": p.lat, "lon": p.lon} for p in poly],
            "current_km": 100.0,
            "look_ahead_km": 200.0,
            **extra,
        }

    def test_returns_event_list_shape(self) -> None:
        response = client.post(
            "/v1/trips/adverse-refresh", json=self._payload(),
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert "events" in body
        assert isinstance(body["events"], list)
        assert "sliced_from_km" in body
        assert "sliced_to_km" in body
        assert "sliced_distance_km" in body

    def test_out_of_range_current_km_returns_empty_events(self) -> None:
        # current_km past the end of the polyline → slicing returns
        # no points, no providers are hit, empty events.
        response = client.post(
            "/v1/trips/adverse-refresh",
            json=self._payload(current_km=99999.0),
        )
        assert response.status_code == 200
        body = response.json()
        assert body["events"] == []
        assert body["sliced_distance_km"] == 0.0

    def test_requires_at_least_two_geometry_points(self) -> None:
        response = client.post(
            "/v1/trips/adverse-refresh",
            json={
                "geometry": [{"lat": 45.0, "lon": 0.0}],
                "current_km": 0.0,
                "look_ahead_km": 100.0,
            },
        )
        assert response.status_code == 422

    def test_negative_current_km_rejected(self) -> None:
        response = client.post(
            "/v1/trips/adverse-refresh",
            json=self._payload(current_km=-1.0),
        )
        assert response.status_code == 422

    def test_look_ahead_capped(self) -> None:
        response = client.post(
            "/v1/trips/adverse-refresh",
            json=self._payload(look_ahead_km=10_000.0),
        )
        assert response.status_code == 422

    def test_countries_hint_is_accepted(self) -> None:
        response = client.post(
            "/v1/trips/adverse-refresh",
            json=self._payload(countries=["FR"]),
        )
        assert response.status_code == 200, response.text

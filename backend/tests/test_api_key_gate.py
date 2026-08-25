"""Sprint 17: API-key middleware gate."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app


class TestApiKeyGate:
    @pytest.fixture
    def with_key(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("MYTRAVELPAL_API_KEY", "test-secret-key")
        yield TestClient(app)

    def test_gate_off_by_default_dev_mode(self) -> None:
        client = TestClient(app)
        # No env var set → gate is a no-op, request goes through.
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_endpoint_always_exempt(self, with_key: TestClient) -> None:
        response = with_key.get("/health")
        assert response.status_code == 200

    def test_v1_endpoint_rejects_without_header(
        self, with_key: TestClient,
    ) -> None:
        response = with_key.post("/v1/trips/plan", json={
            "origin": {"lat": 48, "lon": 2},
            "destination": {"lat": 40, "lon": -3},
            "desired_departure_at": "2026-08-24T08:00:00",
        })
        assert response.status_code == 401
        assert response.json()["error"] == "api_key_required"

    def test_v1_endpoint_rejects_wrong_key(
        self, with_key: TestClient,
    ) -> None:
        response = with_key.post(
            "/v1/trips/plan",
            headers={"X-MyTravelPal-Api-Key": "not-the-key"},
            json={
                "origin": {"lat": 48, "lon": 2},
                "destination": {"lat": 40, "lon": -3},
                "desired_departure_at": "2026-08-24T08:00:00",
            },
        )
        assert response.status_code == 401

    def test_v1_endpoint_passes_with_correct_key(
        self, with_key: TestClient,
    ) -> None:
        response = with_key.post(
            "/v1/trips/plan",
            headers={"X-MyTravelPal-Api-Key": "test-secret-key"},
            json={
                "origin": {"lat": 48.8566, "lon": 2.3522},
                "destination": {"lat": 40.4168, "lon": -3.7038},
                "desired_departure_at": "2026-08-24T08:00:00",
            },
        )
        assert response.status_code == 200

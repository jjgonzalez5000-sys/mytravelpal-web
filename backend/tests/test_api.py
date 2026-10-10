from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_endpoint() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_plan_trip_paris_to_madrid_returns_windows_and_fuel() -> None:
    payload = {
        "origin": {"lat": 48.8566, "lon": 2.3522},
        "destination": {"lat": 40.4168, "lon": -3.7038},
        "desired_departure_at": "2026-08-24T08:00:00",
        "countries": ["FR", "ES"],
    }
    response = client.post("/v1/trips/plan", json=payload)
    assert response.status_code == 200
    body = response.json()

    assert body["route"]["distance_km"] > 1000
    assert set(body["route"]["countries_crossed"]) == {"FR", "ES"}
    assert body["route"]["toll_cost_eur"] > 0

    assert len(body["time_windows"]) > 0
    assert sum(1 for w in body["time_windows"] if w["recommended"]) == 1
    minutes = [w["estimated_minutes"] for w in body["time_windows"]]
    assert minutes == sorted(minutes)

    assert len(body["fuel_prices"]) > 0


def test_plan_trip_rejects_invalid_coordinates() -> None:
    payload = {
        "origin": {"lat": 999.0, "lon": 0.0},
        "destination": {"lat": 40.0, "lon": -3.0},
        "desired_departure_at": "2026-08-24T08:00:00",
        "countries": ["FR"],
    }
    response = client.post("/v1/trips/plan", json=payload)
    assert response.status_code == 422

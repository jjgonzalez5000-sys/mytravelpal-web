from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_geocode_endpoint_returns_matches() -> None:
    response = client.get("/v1/geocode", params={"q": "madrid"})
    assert response.status_code == 200
    body = response.json()
    assert body["results"]
    assert body["results"][0]["display_name"].startswith("Madrid")
    assert body["results"][0]["country"] == "ES"


def test_geocode_endpoint_rejects_empty_query() -> None:
    response = client.get("/v1/geocode", params={"q": ""})
    assert response.status_code == 422


def test_plan_trip_auto_detects_countries_when_omitted() -> None:
    payload = {
        "origin": {"lat": 48.8566, "lon": 2.3522},        # Paris
        "destination": {"lat": 40.4168, "lon": -3.7038},  # Madrid
        "desired_departure_at": "2026-08-24T08:00:00",
    }
    response = client.post("/v1/trips/plan", json=payload)
    assert response.status_code == 200
    assert set(response.json()["route"]["countries_crossed"]) == {"FR", "ES"}


def test_plan_trip_still_honors_explicit_countries() -> None:
    payload = {
        "origin": {"lat": 48.8566, "lon": 2.3522},
        "destination": {"lat": 40.4168, "lon": -3.7038},
        "desired_departure_at": "2026-08-24T08:00:00",
        "countries": ["FR"],
    }
    response = client.post("/v1/trips/plan", json=payload)
    assert response.status_code == 200
    assert response.json()["route"]["countries_crossed"] == ["FR"]

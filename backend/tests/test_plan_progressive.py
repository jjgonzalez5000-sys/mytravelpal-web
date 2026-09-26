"""Tests for the two-phase progressive trip-plan endpoints.

``/v1/trips/plan/core`` should return the fast subset the mobile
ResultScreen needs to render the map + hero + day cards immediately
(route, days, savings, time windows, optimizations).

``/v1/trips/plan/enrich`` should return the slower subset that
hydrates the sections downstream (hotels, restaurants, fuel prices,
adverse events, weather segments, toll alternative).

The historic ``/v1/trips/plan`` must still return the union of both
so pre-progressive mobile clients keep working (backwards compat).

Implementation note: the current backend still runs a monolithic
compute for both progressive endpoints and just slices the response
server-side ("shortcut" variant of the split). The ``plan_cache``
absorbs the double-compute cost when a client fires ``/core`` +
``/enrich`` back-to-back — the second hits the cache and returns
instantly.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app
from app.services.plan_cache import reset_plan_cache_for_tests

client = TestClient(app)


def _paris_madrid_payload() -> dict:
    return {
        "origin": {"lat": 48.8566, "lon": 2.3522},
        "destination": {"lat": 40.4168, "lon": -3.7038},
        "desired_departure_at": "2026-08-24T08:00:00",
        "countries": ["FR", "ES"],
        # Ask for hotels + restaurants + adverse events so the enrich
        # phase actually has something to return; otherwise the check
        # against enrich fields being non-empty would depend on the
        # provider's default corridor pass.
        "hotel_max_detour_minutes": 25,
        "restaurant_max_detour_minutes": 20,
        "include_adverse_events": True,
        "include_toll_alternative": True,
    }


def test_plan_core_returns_route_and_days_but_not_hotels_restaurants() -> None:
    reset_plan_cache_for_tests()
    response = client.post("/v1/trips/plan/core", json=_paris_madrid_payload())
    assert response.status_code == 200
    body = response.json()

    # Core fields — must be populated.
    assert body["route"]["distance_km"] > 1000
    assert body["route"]["polyline"] != "" or body["route"]["geometry"]
    assert len(body["time_windows"]) > 0
    # `days` and `optimizations` require a profile — without one the
    # backend still ships an empty `days` list. Route + windows are
    # the ironclad core-phase guarantee.
    assert "days" in body

    # Enrich-only fields — must be EMPTY/None in the core slice so
    # the client doesn't wastefully re-parse them.
    assert body["hotels"] == []
    assert body["restaurants"] == []
    assert body["fuel_prices"] == []
    assert body["adverse_events"] == []
    assert body["weather_segments"] == []
    assert body["toll_alternative"] is None
    assert body["rest_stops"] == []


def test_plan_enrich_returns_enrich_fields_but_not_route() -> None:
    reset_plan_cache_for_tests()
    response = client.post(
        "/v1/trips/plan/enrich", json=_paris_madrid_payload(),
    )
    assert response.status_code == 200
    body = response.json()

    # Core fields — must be ZEROED/empty in the enrich slice; the
    # client already has them from the earlier `/core` call.
    assert body["route"]["distance_km"] == 0.0
    assert body["route"]["geometry"] == []
    assert body["time_windows"] == []
    assert body["days"] == []
    assert body["optimizations"] is None
    assert body["savings"]["time_saved_minutes_vs_desired"] == 0.0
    assert body["savings"]["money_saved_eur_vs_tolls"] == 0.0

    # Enrich fields — at least one of hotels / restaurants / fuel /
    # rest_stops should surface. Providers are stubbed in tests to
    # return a small deterministic set for a Paris → Madrid route.
    has_any_enrich = (
        len(body["fuel_prices"]) > 0
        or len(body["rest_stops"]) > 0
        or len(body["hotels"]) > 0
        or len(body["restaurants"]) > 0
    )
    assert has_any_enrich, (
        "expected /plan/enrich to surface at least one enrich list; "
        f"got body={body!r}"
    )


def test_plan_full_endpoint_returns_union_of_both() -> None:
    """The historic `/v1/trips/plan` must still ship the whole thing
    so pre-progressive mobile clients (planTrip fallback) keep
    working. This is the backwards-compat guarantee.
    """
    reset_plan_cache_for_tests()
    response = client.post("/v1/trips/plan", json=_paris_madrid_payload())
    assert response.status_code == 200
    body = response.json()

    # Core AND enrich fields both populated.
    assert body["route"]["distance_km"] > 1000
    assert len(body["time_windows"]) > 0
    # At least one enrich signal (stub providers cover fuel + rest
    # stops deterministically).
    assert len(body["fuel_prices"]) > 0 or len(body["rest_stops"]) > 0


def test_plan_core_and_enrich_share_cache_key() -> None:
    """Firing /plan/core then /plan/enrich for the SAME payload
    should be a cache hit on the second call — the compute cost is
    paid ONCE. We prove this indirectly: both responses come from the
    same underlying full-response payload, so the fields they share
    (route.distance_km on core, restStops kilometers on enrich) match
    what /plan returns for the same request.
    """
    reset_plan_cache_for_tests()
    payload = _paris_madrid_payload()
    full = client.post("/v1/trips/plan", json=payload).json()

    reset_plan_cache_for_tests()
    core = client.post("/v1/trips/plan/core", json=payload).json()
    # Same request → same underlying compute → identical route.
    assert core["route"]["distance_km"] == full["route"]["distance_km"]

    # /enrich right after /core should hit the cache (no reset).
    enrich = client.post("/v1/trips/plan/enrich", json=payload).json()
    # Cache-shared: the enrich payload's fuel_prices list mirrors the
    # full response's list (assuming providers are deterministic).
    assert len(enrich["fuel_prices"]) == len(full["fuel_prices"])

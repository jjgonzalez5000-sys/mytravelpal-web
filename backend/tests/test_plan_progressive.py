"""Tests for the two-phase progressive trip-plan endpoints.

``/v1/trips/plan/core`` should return the fast subset the mobile
ResultScreen needs to render the map + hero + day cards immediately
(route, days, savings, time windows, optimizations).

``/v1/trips/plan/enrich`` should return the slower subset that
hydrates the sections downstream (hotels, restaurants, fuel prices,
adverse events, weather segments, toll alternative).

The historic ``/v1/trips/plan`` must still return the union of both
so pre-progressive mobile clients keep working (backwards compat).

Implementation note: the backend now runs two independent compute
paths — ``_plan_core_impl`` for the fast slice and
``_plan_enrich_impl`` for the slow provider fan-out. They share only
a cheap preamble (route + tollguru + time windows) and are keyed on
distinct ``PlanCacheSlot`` values, so hitting one never accidentally
returns a payload the caller wasn't expecting.
"""

from __future__ import annotations

import asyncio
import time

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
    assert isinstance(body["days"], list)

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


def test_plan_core_and_enrich_have_independent_cache_slots() -> None:
    """``/plan/core`` and ``/plan/enrich`` now live in different cache
    slots (``PlanCacheSlot.CORE`` vs. ``PlanCacheSlot.ENRICH``) so a
    hit on one never serves the wrong payload shape to the other.

    We prove independence by firing both endpoints for the same
    payload and asserting each response carries its own signature
    (core has a real route, enrich has enrich fields), i.e. neither
    slot leaked the other's cached bytes into this response.
    """
    reset_plan_cache_for_tests()
    payload = _paris_madrid_payload()

    core = client.post("/v1/trips/plan/core", json=payload).json()
    assert core["route"]["distance_km"] > 1000, (
        "/plan/core must return a real route; got "
        f"distance_km={core['route']['distance_km']}"
    )
    assert core["hotels"] == []
    assert core["fuel_prices"] == []

    # /enrich right after /core: different slot key, so it does its
    # own compute rather than returning core's cached payload.
    enrich = client.post("/v1/trips/plan/enrich", json=payload).json()
    assert enrich["route"]["distance_km"] == 0.0, (
        "/plan/enrich must NOT reuse the /plan/core cache slot; "
        "got a populated route which means the two slots collided"
    )
    has_any_enrich = (
        len(enrich["fuel_prices"]) > 0
        or len(enrich["rest_stops"]) > 0
        or len(enrich["hotels"]) > 0
        or len(enrich["restaurants"]) > 0
    )
    assert has_any_enrich


def test_plan_core_is_faster_than_plan_enrich_with_mocked_delays(
    monkeypatch,
) -> None:
    """With a mocked hotel-provider delay, /core should return
    materially faster than /enrich. Proves the split is real, not
    cosmetic — /core does zero hotel work, so the injected latency
    only hits /enrich.
    """

    reset_plan_cache_for_tests()

    from app.providers.hotels import MockHotelsProvider

    orig_hotels_along = MockHotelsProvider.hotels_along

    async def slow_hotels(self, route, **kw):
        await asyncio.sleep(1.0)
        return await orig_hotels_along(self, route, **kw)

    monkeypatch.setattr(MockHotelsProvider, "hotels_along", slow_hotels)

    payload = _paris_madrid_payload()

    t0 = time.perf_counter()
    r1 = client.post("/v1/trips/plan/core", json=payload)
    core_wall = time.perf_counter() - t0
    assert r1.status_code == 200

    reset_plan_cache_for_tests()
    t0 = time.perf_counter()
    r2 = client.post("/v1/trips/plan/enrich", json=payload)
    enrich_wall = time.perf_counter() - t0
    assert r2.status_code == 200

    # Enrich should be at least 0.5s slower than core because of the
    # injected hotel delay (1s sleep). Leaves plenty of headroom for
    # noise on shared CI hardware.
    assert enrich_wall > core_wall + 0.5, (
        f"core={core_wall:.2f}s enrich={enrich_wall:.2f}s — the split "
        "must isolate /core from the hotel-provider latency"
    )

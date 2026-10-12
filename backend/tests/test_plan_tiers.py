"""Tier handling on the plan endpoints.

A free caller carrying a premium-only flag (a stale payload after a
downgrade) gets a normal plan without it, never a 402. Everything that earns
through a booking or affiliate click stays available to every tier.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.api.v1.trips import TripPlanRequest, _apply_tier
from app.main import app
from app.services.plan_cache import (
    PlanCacheSlot,
    get_plan_cache,
    reset_plan_cache_for_tests,
)

client = TestClient(app)

_PREMIUM = {"X-MyTravelPal-Premium": "true"}


def _payload(**extra: object) -> dict:
    return {
        "origin": {"lat": 48.8566, "lon": 2.3522},
        "destination": {"lat": 40.4168, "lon": -3.7038},
        "desired_departure_at": "2026-08-24T08:00:00",
        **extra,
    }


def _plan(headers: dict[str, str] | None = None, **extra: object) -> dict:
    response = client.post(
        "/v1/trips/plan", json=_payload(**extra), headers=headers or {},
    )
    assert response.status_code == 200, response.text
    return response.json()


@pytest.fixture(autouse=True)
def _fresh_cache():
    reset_plan_cache_for_tests()
    yield
    reset_plan_cache_for_tests()


def test_free_plan_keeps_hotels_and_restaurants() -> None:
    body = _plan(
        hotel_max_detour_minutes=60,
        hotel_price_band="any",
        restaurant_max_detour_minutes=30,
    )
    assert len(body["hotels"]) >= 1
    assert len(body["restaurants"]) >= 1


def test_free_hourly_flag_is_dropped_not_402() -> None:
    body = _plan(include_hourly_toll_analysis=True)
    assert body["hourly_toll_report"] is None


def test_premium_hourly_flag_still_works() -> None:
    body = _plan(_PREMIUM, include_hourly_toll_analysis=True)
    assert len(body["hourly_toll_report"]["verdicts"]) == 24


def test_free_toll_alternative_is_not_gated() -> None:
    assert _plan(include_toll_alternative=True)["route"]["distance_km"] > 0


def test_no_cross_tier_cache_leak() -> None:
    first = _plan(_PREMIUM, include_hourly_toll_analysis=True)
    assert first["hourly_toll_report"] is not None
    free = _plan(include_hourly_toll_analysis=True)
    assert free["hourly_toll_report"] is None
    again = _plan(_PREMIUM, include_hourly_toll_analysis=True)
    assert again["hourly_toll_report"] is not None


def test_normalised_free_payload_hashes_apart_from_premium() -> None:
    req = TripPlanRequest(**_payload(include_hourly_toll_analysis=True))
    plain = TripPlanRequest(**_payload())
    free = _apply_tier(req, premium=False)
    cache = get_plan_cache()
    slot = PlanCacheSlot.FULL
    assert free.include_hourly_toll_analysis is False
    assert cache.key_for(free, slot) == cache.key_for(plain, slot)
    assert cache.key_for(free, slot) != cache.key_for(
        _apply_tier(req, premium=True), slot,
    )


def test_apply_tier_is_idempotent_and_does_not_mutate() -> None:
    req = TripPlanRequest(**_payload(include_hourly_toll_analysis=True))
    once = _apply_tier(req, premium=False)
    assert _apply_tier(once, premium=False) == once
    assert req.include_hourly_toll_analysis is True
    assert _apply_tier(req, premium=True) is req


@pytest.mark.parametrize(
    "path", ["/plan", "/plan/core", "/plan/enrich", "/plan/stream"],
)
def test_every_plan_endpoint_accepts_a_free_request_with_the_flag(
    path: str,
) -> None:
    response = client.post(
        f"/v1/trips{path}",
        json=_payload(
            include_hourly_toll_analysis=True,
            hotel_max_detour_minutes=25,
        ),
    )
    assert response.status_code == 200, response.text

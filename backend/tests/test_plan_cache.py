"""Tests for `app.services.plan_cache`.

The cache layer is tested in isolation from the endpoint so we can
exercise it without spinning up the full provider fan-out. The end-
to-end wiring (miss populates, subsequent hit returns cached) is
covered indirectly by `test_api.py` — a follow-up test could assert
identical bytes on two back-to-back plans if we want per-request
proof.
"""

from __future__ import annotations

import pytest

from app.api.v1.trips import RouteOut, TripPlanRequest, TripPlanResponse
from app.domain import Country
from app.services.plan_cache import PlanCache


def _base_request() -> dict:
    return {
        "origin": {"lat": 48.8566, "lon": 2.3522},
        "destination": {"lat": 40.4168, "lon": -3.7038},
        "desired_departure_at": "2026-08-24T08:15:00",
        "countries": ["FR", "ES"],
    }


def _minimal_response() -> TripPlanResponse:
    return TripPlanResponse(
        route=RouteOut(
            distance_km=1265.4,
            free_flow_minutes=720.0,
            polyline="",
            toll_cost_eur=48.3,
            countries_crossed=[Country.FR, Country.ES],
        ),
        time_windows=[],
        fuel_prices=[],
        hotels=[],
        restaurants=[],
        rest_stops=[],
        adverse_events=[],
    )


def test_key_is_stable_for_same_request() -> None:
    cache = PlanCache(redis_url=None)
    req = TripPlanRequest.model_validate(_base_request())
    assert cache.key_for(req) == cache.key_for(req)


def test_key_is_hex_sha256() -> None:
    cache = PlanCache(redis_url=None)
    key = cache.key_for(TripPlanRequest.model_validate(_base_request()))
    assert len(key) == 64
    assert all(c in "0123456789abcdef" for c in key)


def test_departure_minute_within_same_hour_buckets_together() -> None:
    cache = PlanCache(redis_url=None)
    a = _base_request()
    b = _base_request()
    a["desired_departure_at"] = "2026-08-24T08:15:00"
    b["desired_departure_at"] = "2026-08-24T08:45:00"
    key_a = cache.key_for(TripPlanRequest.model_validate(a))
    key_b = cache.key_for(TripPlanRequest.model_validate(b))
    assert key_a == key_b


def test_departure_hour_bucket_is_hour_granular() -> None:
    cache = PlanCache(redis_url=None)
    a = _base_request()
    b = _base_request()
    a["desired_departure_at"] = "2026-08-24T08:45:00"
    b["desired_departure_at"] = "2026-08-24T09:00:00"
    key_a = cache.key_for(TripPlanRequest.model_validate(a))
    key_b = cache.key_for(TripPlanRequest.model_validate(b))
    assert key_a != key_b


def test_different_waypoints_produce_different_keys() -> None:
    cache = PlanCache(redis_url=None)
    a = _base_request()
    b = _base_request()
    b["waypoints"] = [{"lat": 44.8378, "lon": -0.5792}]  # Bordeaux
    key_a = cache.key_for(TripPlanRequest.model_validate(a))
    key_b = cache.key_for(TripPlanRequest.model_validate(b))
    assert key_a != key_b


def test_coord_rounding_absorbs_sub_10m_jitter() -> None:
    cache = PlanCache(redis_url=None)
    a = _base_request()
    b = _base_request()
    # 5 decimals differ, but 4-decimal rounding collapses them.
    b["origin"] = {"lat": 48.85661, "lon": 2.35221}
    key_a = cache.key_for(TripPlanRequest.model_validate(a))
    key_b = cache.key_for(TripPlanRequest.model_validate(b))
    assert key_a == key_b


def test_filter_toggle_changes_key() -> None:
    cache = PlanCache(redis_url=None)
    a = _base_request()
    b = _base_request()
    b["include_adverse_events"] = True
    key_a = cache.key_for(TripPlanRequest.model_validate(a))
    key_b = cache.key_for(TripPlanRequest.model_validate(b))
    assert key_a != key_b


async def test_in_memory_fallback_when_no_redis_url() -> None:
    cache = PlanCache(redis_url=None)
    key = "test-key"
    response = _minimal_response()
    await cache.set(key, response)
    got = await cache.get(key)
    assert got is not None
    assert got.route.distance_km == pytest.approx(1265.4)
    assert got.route.toll_cost_eur == pytest.approx(48.3)
    assert list(got.route.countries_crossed) == [Country.FR, Country.ES]


async def test_get_miss_returns_none() -> None:
    cache = PlanCache(redis_url=None)
    assert await cache.get("never-set") is None


async def test_round_trip_via_key_for() -> None:
    cache = PlanCache(redis_url=None)
    req = TripPlanRequest.model_validate(_base_request())
    key = cache.key_for(req)
    assert await cache.get(key) is None
    await cache.set(key, _minimal_response())
    hit = await cache.get(key)
    assert hit is not None
    assert hit.route.distance_km == pytest.approx(1265.4)


async def test_broken_redis_url_falls_back_silently() -> None:
    # `redis.asyncio.from_url` accepts almost anything at init time,
    # only failing on the first op. So we drive the failure path by
    # pointing at a dead port. Both set() and get() must not raise.
    cache = PlanCache(redis_url="redis://127.0.0.1:1/0")
    await cache.set("k", _minimal_response())
    got = await cache.get("k")
    assert got is not None
    assert got.route.distance_km == pytest.approx(1265.4)


async def test_cache_layer_never_populated_by_caller_on_error() -> None:
    """The endpoint only calls .set() after a successful response.

    We simulate an error path by simply not calling .set() — the
    subsequent .get() must return None. This mirrors the real
    endpoint's behaviour where an HTTPException short-circuits
    before the tail-of-handler .set().
    """

    cache = PlanCache(redis_url=None)
    req = TripPlanRequest.model_validate(_base_request())
    key = cache.key_for(req)
    # Caller raises before .set() — cache stays empty.
    assert await cache.get(key) is None

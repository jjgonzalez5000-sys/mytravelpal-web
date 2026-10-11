"""Toll-free routing, via-only waypoints and per-day end time.

Covers the API contract the mobile app relies on:

* ``avoid_tolls`` reaches the routing provider, the route toll is 0 and every
  stop/day follows the geometry of the toll-free route;
* ``WaypointIn.via_only`` is routed through but never becomes a visit stop;
* ``DayOverrideIn.end_minutes`` drives the day cap through ONE shared helper
  (day_plan + trip_optimizations agree);
* HERE is used for toll-free requests only when a HERE key is configured.
"""

from __future__ import annotations

import asyncio
import dataclasses
import json
import logging
from datetime import datetime, timedelta

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.v1.trips import (
    DayOverrideIn,
    TripPlanRequest,
    WaypointIn,
    _plan_shared_preamble,
    _providers,
)
from app.domain import Coordinate, Country, TravelPace, TripProfile
from app.domain.entities import Route
from app.main import app
from app.providers.factory import get_providers
from app.providers.routing import (
    HereRoutingProvider,
    MockRoutingProvider,
    TollAvoidingRoutingProvider,
    default_routing_provider,
)
from app.services import day_plan as dp
from app.services import trip_optimizations as to
from app.services.plan_cache import PlanCache, reset_plan_cache_for_tests
from app.services.rest_stops import compute_rest_stops

client = TestClient(app)

_NORMAL_LAT = 48.0
_TOLL_FREE_LAT = 44.0
_DEP = "2026-08-24T08:00:00"


# --------------------------------------------------------------------------
# Stub routing
# --------------------------------------------------------------------------


def _line_route(
    lat: float,
    hours: float,
    *,
    kmh: float = 90.0,
    toll: float = 0.0,
    avoid: bool = False,
) -> Route:
    """Straight east-west route at constant latitude so "is this stop on
    the geometry" reduces to comparing latitudes."""
    n = 60
    lon_span = hours * kmh / 74.5
    geom = tuple(
        Coordinate(lat=lat, lon=2.0 + lon_span * i / (n - 1))
        for i in range(n)
    )
    return Route(
        origin=geom[0],
        destination=geom[-1],
        distance_km=hours * kmh,
        free_flow_duration=timedelta(hours=hours),
        polyline="p",
        toll_cost_eur=toll,
        countries_crossed=(Country.FR,),
        waypoints=geom[1:-1:10],
        geometry=geom,
        avoid_tolls=avoid,
    )


class _StubRouting:
    """Normal request -> route on lat 48 with a toll; avoid_tolls -> a
    DIFFERENT geometry on lat 44 with no toll. Records every call."""

    def __init__(self, hours: float = 14.0) -> None:
        self.hours = hours
        self.calls: list[dict] = []

    async def route(
        self, origin, destination, countries=None, *,
        waypoints=(), avoid_tolls=False, avoid_motorways=False,
        prefer_scenic=False,
    ):
        self.calls.append({
            "avoid_tolls": avoid_tolls,
            "avoid_motorways": avoid_motorways,
            "waypoints": tuple(waypoints),
        })
        if avoid_tolls:
            return _line_route(
                _TOLL_FREE_LAT, self.hours + 1.0, toll=0.0, avoid=True,
            )
        return _line_route(_NORMAL_LAT, self.hours, toll=99.0)


@pytest.fixture
def stub_routing():
    reset_plan_cache_for_tests()
    stub = _StubRouting()
    patched = dataclasses.replace(get_providers(), routing=stub, tollguru=None)
    app.dependency_overrides[_providers] = lambda: patched
    try:
        yield stub
    finally:
        app.dependency_overrides.pop(_providers, None)
        reset_plan_cache_for_tests()


def _payload(**extra) -> dict:
    body = {
        "origin": {"lat": 48.0, "lon": 2.0},
        "destination": {"lat": 48.0, "lon": 20.0},
        "desired_departure_at": _DEP,
        "trip_profile": {},
    }
    body.update(extra)
    return body


def _stop_lats(body: dict) -> list[float]:
    lats: list[float] = []
    opt = body["optimizations"]
    for m in opt["meal_stops"]:
        lats.append(m["lat"])
    if opt["sleep_stop"] is not None:
        lats.append(opt["sleep_stop"]["lat"])
    for d in body["days"]:
        for m in d["meal_stops"]:
            lats.append(m["lat"])
        if d["sleep_lat"] is not None:
            lats.append(d["sleep_lat"])
    return lats


# --------------------------------------------------------------------------
# (a) / (b) avoid_tolls end to end
# --------------------------------------------------------------------------


def test_avoid_tolls_reaches_routing_and_toll_is_zero(stub_routing) -> None:
    r = client.post(
        "/v1/trips/plan/core",
        json=_payload(avoid_tolls=True, include_toll_alternative=True),
    )
    assert r.status_code == 200, r.text
    assert stub_routing.calls[0]["avoid_tolls"] is True
    body = r.json()
    assert body["route"]["toll_cost_eur"] == 0.0
    assert body["toll_alternative"] is None
    assert body["partial_toll_skips"] == []


def test_default_request_does_not_avoid_tolls(stub_routing) -> None:
    r = client.post("/v1/trips/plan/core", json=_payload())
    assert r.status_code == 200, r.text
    assert stub_routing.calls[0]["avoid_tolls"] is False
    assert r.json()["route"]["toll_cost_eur"] == 99.0


def test_full_plan_with_avoid_tolls_validates_and_has_no_alternative(
    stub_routing,
) -> None:
    r = client.post(
        "/v1/trips/plan",
        json=_payload(
            avoid_tolls=True,
            include_toll_alternative=True,
            include_hourly_toll_analysis=False,
        ),
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["route"]["toll_cost_eur"] == 0.0
    assert body["toll_alternative"] is None
    assert body["partial_toll_skips"] == []
    # Toll alternative must not trigger a second routing call (toll is 0).
    assert [c["avoid_tolls"] for c in stub_routing.calls] == [True]


def test_stops_and_days_follow_the_toll_free_geometry(stub_routing) -> None:
    free = client.post(
        "/v1/trips/plan/core", json=_payload(avoid_tolls=True),
    ).json()
    geom_lats = {round(p[1], 4) for p in free["route"]["geometry"]}
    assert geom_lats == {_TOLL_FREE_LAT}
    assert len(free["days"]) >= 2
    lats = _stop_lats(free)
    assert lats, "expected meal/sleep stops"
    assert all(abs(lat - _TOLL_FREE_LAT) < 0.01 for lat in lats), lats

    normal = client.post("/v1/trips/plan/core", json=_payload()).json()
    nlats = _stop_lats(normal)
    assert nlats and all(abs(lat - _NORMAL_LAT) < 0.01 for lat in nlats)


def test_alt_route_fetch_passes_waypoints_and_avoid_motorways(
    stub_routing,
) -> None:
    wp = {"lat": 48.0, "lon": 9.0, "label": "Mid"}
    r = client.post(
        "/v1/trips/plan",
        json=_payload(
            waypoints=[wp],
            avoid_motorways=True,
            include_toll_alternative=True,
        ),
    )
    assert r.status_code == 200, r.text
    alt_calls = [c for c in stub_routing.calls if c["avoid_tolls"]]
    assert alt_calls, "toll alternative should be requested"
    assert alt_calls[0]["avoid_motorways"] is True
    assert len(alt_calls[0]["waypoints"]) == 1


# --------------------------------------------------------------------------
# (c) plan cache keys
# --------------------------------------------------------------------------


def _req(**extra) -> TripPlanRequest:
    return TripPlanRequest.model_validate(_payload(**extra))


def test_cache_key_differs_for_avoid_tolls() -> None:
    cache = PlanCache(redis_url=None)
    assert cache.key_for(_req()) != cache.key_for(_req(avoid_tolls=True))


def test_cache_key_differs_for_via_only() -> None:
    cache = PlanCache(redis_url=None)
    wp = {"lat": 48.0, "lon": 9.0, "label": "X"}
    a = cache.key_for(_req(waypoints=[wp]))
    b = cache.key_for(_req(waypoints=[{**wp, "via_only": True}]))
    assert a != b


def test_cache_key_differs_for_end_minutes() -> None:
    cache = PlanCache(redis_url=None)
    a = _req(day_overrides=[{"day_index": 1, "end_minutes": 1000}])
    b = _req(day_overrides=[{"day_index": 1, "end_minutes": 1100}])
    assert cache.key_for(a) != cache.key_for(b)


# --------------------------------------------------------------------------
# (d) via_only waypoints
# --------------------------------------------------------------------------


def test_via_only_reaches_routing_but_not_dwell_waypoints() -> None:
    reset_plan_cache_for_tests()
    stub = _StubRouting()
    providers = dataclasses.replace(get_providers(), routing=stub, tollguru=None)
    payload = _req(waypoints=[
        {"lat": 48.0, "lon": 6.0, "label": "ViaPoint", "via_only": True,
         "dwell_nights": 1},
        {"lat": 48.0, "lon": 12.0, "label": "VisitPoint"},
    ])
    pre = asyncio.run(_plan_shared_preamble(payload, providers))
    assert len(stub.calls[0]["waypoints"]) == 2
    assert len(pre.waypoints) == 2
    assert [w.label for w in pre.dwell_waypoints] == ["VisitPoint"]


def test_via_only_absent_from_days_labels_and_anchors(stub_routing) -> None:
    r = client.post(
        "/v1/trips/plan/core",
        json=_payload(waypoints=[
            {"lat": 48.0, "lon": 6.0, "label": "ViaPoint",
             "via_only": True, "dwell_nights": 2},
            {"lat": 48.0, "lon": 12.0, "label": "VisitPoint"},
        ]),
    )
    assert r.status_code == 200, r.text
    assert len(stub_routing.calls[0]["waypoints"]) == 2
    days = r.json()["days"]
    labels = [lbl for d in days for lbl in d["waypoint_labels"]]
    anchors = [a["label"] for d in days for a in d["waypoint_anchors"]]
    assert "VisitPoint" in labels and "VisitPoint" in anchors
    assert "ViaPoint" not in labels and "ViaPoint" not in anchors
    assert all(d["dwell_label"] != "ViaPoint" for d in days)
    # A via-only point with dwell_nights must NOT add stay-put days.
    assert all(d["from_km"] != d["to_km"] for d in days)


def test_via_only_counts_toward_waypoint_limit() -> None:
    wps = [
        {"lat": 40.0 + i * 0.1, "lon": 3.0, "via_only": i % 2 == 0}
        for i in range(9)
    ]
    with pytest.raises(ValidationError):
        _req(waypoints=wps)
    assert len(_req(waypoints=wps[:8]).waypoints) == 8


def test_duplicate_waypoint_keeps_visit_over_via_only() -> None:
    req = _req(waypoints=[
        {"lat": 41.0, "lon": 3.0, "via_only": True},
        {"lat": 41.0, "lon": 3.0, "label": "Stay", "dwell_nights": 1},
    ])
    assert len(req.waypoints) == 1
    assert req.waypoints[0].via_only is False
    assert req.waypoints[0].label == "Stay"


# --------------------------------------------------------------------------
# (e) HERE-first routing for avoid_tolls
# --------------------------------------------------------------------------


class _Recorder:
    def __init__(
        self, name: str, fail: bool = False, error: str = "boom",
    ) -> None:
        self.name = name
        self.fail = fail
        self.error = error
        self.calls: list[bool] = []

    async def route(self, origin, destination, countries=None, *,
                    waypoints=(), avoid_tolls=False, avoid_motorways=False,
                    prefer_scenic=False):
        self.calls.append(avoid_tolls)
        if self.fail:
            raise RuntimeError(self.error)
        return _line_route(
            _TOLL_FREE_LAT if self.name == "here" else _NORMAL_LAT, 5.0,
            avoid=avoid_tolls,
        )


_A = Coordinate(lat=48.0, lon=2.0)
_B = Coordinate(lat=48.0, lon=9.0)


def test_toll_avoiding_provider_uses_here_only_for_avoid_tolls() -> None:
    default, here = _Recorder("default"), _Recorder("here")
    p = TollAvoidingRoutingProvider(default=default, here=here)
    r1 = asyncio.run(p.route(_A, _B, avoid_tolls=True))
    assert here.calls == [True] and default.calls == []
    assert r1.geometry[0].lat == _TOLL_FREE_LAT
    assert r1.avoid_tolls is True
    asyncio.run(p.route(_A, _B))
    assert here.calls == [True] and default.calls == [False]


def test_toll_avoiding_provider_falls_back_and_warns(caplog) -> None:
    default, here = _Recorder("default"), _Recorder("here", fail=True)
    p = TollAvoidingRoutingProvider(default=default, here=here)
    with caplog.at_level(logging.WARNING, logger="app.providers.routing"):
        r = asyncio.run(p.route(_A, _B, avoid_tolls=True))
    # Fallback is a NORMAL route: avoid_tolls is never forwarded to a
    # provider that cannot honour it, and the result is not labelled
    # toll-free.
    assert default.calls == [False]
    assert r.geometry[0].lat == _NORMAL_LAT
    assert r.avoid_tolls is False
    assert any("HERE toll-free routing failed" in m for m in caplog.messages)


def test_factory_wraps_chain_only_when_here_key_is_set(monkeypatch) -> None:
    monkeypatch.setenv("MYTRAVELPAL_ROUTING", "osrm")
    monkeypatch.delenv("MYTRAVELPAL_HERE_API_KEY", raising=False)
    plain = default_routing_provider()
    # No HERE key: still wrapped, so toll-free requests are served as an
    # honest tolled route instead of a mislabelled OSRM one.
    assert isinstance(plain, TollAvoidingRoutingProvider)
    assert plain._here is None

    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    wrapped = default_routing_provider()
    assert isinstance(wrapped, TollAvoidingRoutingProvider)
    assert wrapped._here is not None

    monkeypatch.setenv("MYTRAVELPAL_ROUTING", "mock")
    assert isinstance(default_routing_provider(), MockRoutingProvider)


def test_here_provider_sends_toll_road_avoidance(monkeypatch) -> None:
    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    captured: dict = {}

    async def handler(request: httpx.Request) -> httpx.Response:
        captured["url"] = str(request.url)
        return httpx.Response(200, text=json.dumps({"routes": []}))

    provider = HereRoutingProvider(
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )
    with pytest.raises(RuntimeError):
        asyncio.run(provider.route(_A, _B, avoid_tolls=True))
    assert "tollRoad" in captured["url"]


# --------------------------------------------------------------------------
# (f) end_minutes
# --------------------------------------------------------------------------

_PROFILE = TripProfile()  # steady, cap 8 h, bedtime 22, meals 8/13/20
_DEP_DT = datetime(2026, 8, 24, 8, 0)


def _plan(profile=_PROFILE, hours=14.0, overrides=None, dep=_DEP_DT):
    route = _line_route(_NORMAL_LAT, hours)
    rests = compute_rest_stops(route, profile=profile)
    opt = to.compute(
        departure_at=dep, trip_duration_hours=hours, rest_stops=rests,
        restaurants_by_slot={}, hotels=(), profile=profile,
        day_overrides=overrides, route_km=route.distance_km,
    )
    md = dp.compute(
        departure_at=dep, trip_duration_hours=hours, profile=profile,
        optimizations=opt, rest_stops=rests,
        route_distance_km=route.distance_km, route=route,
        day_overrides=overrides,
    )
    return route, opt, md


def _end(minutes: int) -> dict:
    return {1: {"end_minutes": minutes}}


def test_later_end_extends_day_one_without_changing_total_km() -> None:
    route, _, base = _plan()
    _, _, later = _plan(overrides=_end(20 * 60))
    assert later.days[0].to_km > base.days[0].to_km
    assert later.days[-1].to_km == pytest.approx(route.distance_km)
    assert base.days[-1].to_km == pytest.approx(route.distance_km)


def test_earlier_end_shortens_day_one_and_grows_last_day() -> None:
    _, _, base = _plan()
    _, _, earlier = _plan(overrides=_end(16 * 60))
    assert earlier.days[0].to_km < base.days[0].to_km
    last_b = base.days[-1].to_km - base.days[-1].from_km
    last_e = earlier.days[-1].to_km - earlier.days[-1].from_km
    assert last_e > last_b


def test_much_earlier_end_adds_a_day() -> None:
    _, _, base = _plan()
    _, _, early = _plan(overrides=_end(12 * 60))
    assert base.total_days == 2
    assert early.total_days == 3


def test_end_equal_to_default_end_leaves_plan_unchanged() -> None:
    _, opt0, base = _plan()
    d1 = base.days[0].end_at
    minutes = d1.hour * 60 + d1.minute
    _, opt1, same = _plan(overrides=_end(minutes))
    assert [(d.from_km, d.to_km, d.end_at) for d in same.days] == [
        (d.from_km, d.to_km, d.end_at) for d in base.days
    ]
    assert opt1.sleep_stop.rest_stop.distance_from_origin_km == (
        opt0.sleep_stop.rest_stop.distance_from_origin_km
    )
    assert [(m.slot, m.at) for m in opt1.meal_stops] == [
        (m.slot, m.at) for m in opt0.meal_stops
    ]


@pytest.mark.parametrize("minutes", [12 * 60, 16 * 60, 20 * 60, 23 * 60 + 30])
def test_optimizations_and_day_plan_agree_on_day_one_end(minutes) -> None:
    _, opt, md = _plan(overrides=_end(minutes))
    assert opt.sleep_stop is not None
    assert md.days[0].to_km == opt.sleep_stop.rest_stop.distance_from_origin_km
    assert md.days[0].sleep_coord == opt.sleep_stop.rest_stop.coordinate


def test_end_past_bedtime_is_honoured() -> None:
    # bedtime 22:00. Without the override the sleep stop is clamped to the
    # 8 h cap; asking to drive until 23:30 must go further, and the day
    # must end after bedtime.
    _, opt_base, base = _plan()
    _, opt, md = _plan(overrides=_end(23 * 60 + 30))
    assert md.days[0].to_km > base.days[0].to_km
    assert opt.sleep_stop.at.hour >= 21
    assert md.days[0].end_at.hour >= 22


def test_end_wins_over_driving_cap_hours() -> None:
    _, _, md = _plan(overrides={1: {
        "daily_driving_cap_hours": 3, "end_minutes": 20 * 60,
    }})
    _, _, capped = _plan(overrides={1: {"daily_driving_cap_hours": 3}})
    assert md.days[0].to_km > capped.days[0].to_km


def test_day_override_km_cap_can_lift_profile_km_cap() -> None:
    profile = TripProfile(daily_km_cap=500)
    ov_hours = {1: {"daily_driving_cap_hours": 12}}
    ov_lifted = {1: {"daily_driving_cap_hours": 12, "daily_km_cap": 2000}}
    _, _, held = _plan(profile=profile, overrides=ov_hours)
    _, _, lifted = _plan(profile=profile, overrides=ov_lifted)
    assert held.days[0].to_km <= 540.0
    assert lifted.days[0].to_km > held.days[0].to_km


def test_cap_helper_inverts_pause_and_meal_overhead() -> None:
    # 08:00 -> 17:48 = 9.8 h wall; breakfast + lunch inside (dinner at
    # 20:00 is not) = 2 h; steady pause ratio 0.10.
    cap = to.resolve_day_cap_hours(
        profile=_PROFILE, override={"end_minutes": 17 * 60 + 48},
        day_start=_DEP_DT, avg_kmh=90.0,
    )
    assert cap == pytest.approx((9.8 - 2.0) / 1.10)
    # End before start floors at half an hour.
    floor = to.resolve_day_cap_hours(
        profile=_PROFILE, override={"end_minutes": 7 * 60},
        day_start=_DEP_DT, avg_kmh=90.0,
    )
    assert floor == 0.5
    # Pace changes the inversion.
    savour = to.resolve_day_cap_hours(
        profile=TripProfile(travel_pace=TravelPace.SAVOUR),
        override={"end_minutes": 17 * 60 + 48},
        day_start=_DEP_DT, avg_kmh=90.0,
    )
    assert savour == pytest.approx((9.8 - 2.0) / 1.17)


def test_override_capping_below_trip_makes_single_day_trip_multiday() -> None:
    # 7 h trip, 8 h cap: single day.
    _, _, md = _plan(hours=7.0)
    assert md is None
    _, _, md = _plan(hours=7.0, overrides={1: {"daily_driving_cap_hours": 4}})
    assert md is not None and md.total_days == 2
    _, _, md = _plan(hours=7.0, overrides=_end(11 * 60))
    assert md is not None and md.total_days == 2


def test_explicit_end_covering_trip_past_bedtime_keeps_single_day() -> None:
    profile = TripProfile(
        travel_pace=TravelPace.PUSH, daily_driving_cap_hours=14,
    )
    dep = datetime(2026, 8, 24, 9, 30)  # 12.5 h trip arrives 22:00 >= bedtime
    _, _, md = _plan(profile=profile, hours=12.5, dep=dep)
    assert md is not None  # bedtime rule
    _, _, md = _plan(
        profile=profile, hours=12.5, dep=dep, overrides=_end(26 * 60),
    )
    assert md is None


def test_end_minutes_through_the_endpoint(stub_routing) -> None:
    base = client.post("/v1/trips/plan/core", json=_payload()).json()
    reset_plan_cache_for_tests()
    later = client.post(
        "/v1/trips/plan/core",
        json=_payload(day_overrides=[{"day_index": 1, "end_minutes": 20 * 60}]),
    )
    assert later.status_code == 200, later.text
    later = later.json()
    assert later["days"][0]["to_km"] > base["days"][0]["to_km"]
    assert later["days"][-1]["to_km"] == base["days"][-1]["to_km"]


def test_override_makes_single_day_endpoint_trip_multiday() -> None:
    reset_plan_cache_for_tests()
    stub = _StubRouting(hours=7.0)
    patched = dataclasses.replace(get_providers(), routing=stub, tollguru=None)
    app.dependency_overrides[_providers] = lambda: patched
    try:
        single = client.post("/v1/trips/plan/core", json=_payload()).json()
        reset_plan_cache_for_tests()
        multi = client.post(
            "/v1/trips/plan/core",
            json=_payload(day_overrides=[
                {"day_index": 1, "daily_driving_cap_hours": 3},
            ]),
        )
    finally:
        app.dependency_overrides.pop(_providers, None)
        reset_plan_cache_for_tests()
    assert multi.status_code == 200, multi.text
    assert single["days"] == []
    assert len(multi.json()["days"]) == 2


# --------------------------------------------------------------------------
# (g) validation
# --------------------------------------------------------------------------


def test_day_override_end_minutes_bounds() -> None:
    assert DayOverrideIn(day_index=1).end_minutes is None
    assert DayOverrideIn(day_index=1, end_minutes=0).end_minutes == 0
    assert DayOverrideIn(day_index=1, end_minutes=1560).end_minutes == 1560
    for bad in (-1, 1561):
        with pytest.raises(ValidationError):
            DayOverrideIn(day_index=1, end_minutes=bad)


def test_new_request_fields_default_off() -> None:
    assert WaypointIn(lat=1.0, lon=2.0).via_only is False
    assert _req().avoid_tolls is False


# --------------------------------------------------------------------------
# Review fixes
# --------------------------------------------------------------------------
# A. toll quote cache / toll-free enrich


def _fake_geometry_route(lat: float, avoid: bool = False) -> Route:
    return _line_route(lat, 10.0, avoid=avoid)


def test_toll_quote_cache_key_separates_toll_free_and_normal() -> None:
    from app.providers.tolls_here import _quote_key

    normal = _line_route(_NORMAL_LAT, 10.0)
    toll_free = dataclasses.replace(normal, avoid_tolls=True)
    other_path = _line_route(_NORMAL_LAT + 3.0, 10.0)
    assert _quote_key(normal) == _quote_key(normal)
    assert _quote_key(normal) != _quote_key(toll_free)
    assert _quote_key(normal) != _quote_key(other_path)


def test_here_quote_for_toll_free_route_does_not_reuse_normal_quote(
    monkeypatch,
) -> None:
    from app.providers import tolls_here

    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    tolls_here._QUOTE_CACHE.clear()
    calls = {"n": 0}

    async def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        sections = [{"tolls": []}]
        if calls["n"] == 1:
            sections = [{"tolls": [{"fares": [
                {"price": {"currency": "EUR", "value": 10.0}},
            ]}]}]
        return httpx.Response(200, text=json.dumps(
            {"routes": [{"sections": sections}]},
        ))

    provider = tolls_here.HereTollsProvider(
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )
    normal = _line_route(_NORMAL_LAT, 10.0)
    free = dataclasses.replace(normal, avoid_tolls=True)
    try:
        q1 = asyncio.run(provider.quote(normal))
        q2 = asyncio.run(provider.quote(free))
    finally:
        tolls_here._QUOTE_CACHE.clear()
    assert q1.total_eur == 10.0
    assert q2.total_eur == 0.0
    assert calls["n"] == 2


class _CountingToll:
    def __init__(self) -> None:
        self.calls = 0

    async def quote(self, route, *, vehicle_class="2AxlesAuto"):
        self.calls += 1
        return None


def _patch(stub, tollguru=None):
    reset_plan_cache_for_tests()
    patched = dataclasses.replace(
        get_providers(), routing=stub, tollguru=tollguru,
    )
    app.dependency_overrides[_providers] = lambda: patched


def _unpatch():
    app.dependency_overrides.pop(_providers, None)
    reset_plan_cache_for_tests()


def test_enrich_skips_toll_work_for_a_really_toll_free_route() -> None:
    toll = _CountingToll()
    stub = _StubRouting()
    _patch(stub, toll)
    try:
        r = client.post(
            "/v1/trips/plan/enrich",
            json=_payload(avoid_tolls=True, include_toll_alternative=True),
        )
    finally:
        _unpatch()
    assert r.status_code == 200, r.text
    body = r.json()
    assert toll.calls == 0
    assert [c["avoid_tolls"] for c in stub.calls] == [True]
    assert body["route"]["toll_verified"] is True
    assert body["route"]["toll_cost_eur"] == 0.0
    assert body["toll_alternative"] is None
    assert body["partial_toll_skips"] == []
    assert body["intra_section_skips"] == []


def test_response_route_exposes_whether_tolls_were_really_avoided(
    stub_routing,
) -> None:
    on = client.post("/v1/trips/plan/core", json=_payload(avoid_tolls=True))
    reset_plan_cache_for_tests()
    off = client.post("/v1/trips/plan/core", json=_payload())
    assert on.json()["route"]["avoid_tolls"] is True
    assert off.json()["route"]["avoid_tolls"] is False


class _TollFreeNotHonoured(_StubRouting):
    """Simulates the wrapper after an HERE outage: a normal tolled route
    labelled avoid_tolls=False even though it was requested."""

    async def route(self, origin, destination, countries=None, *,
                    waypoints=(), avoid_tolls=False, avoid_motorways=False,
                    prefer_scenic=False):
        self.calls.append({"avoid_tolls": avoid_tolls,
                           "avoid_motorways": avoid_motorways,
                           "waypoints": tuple(waypoints)})
        return _line_route(_NORMAL_LAT, self.hours, toll=99.0)


def test_unhonoured_toll_free_request_is_reported_and_priced() -> None:
    toll = _CountingToll()
    _patch(_TollFreeNotHonoured(), toll)
    try:
        core = client.post(
            "/v1/trips/plan/core", json=_payload(avoid_tolls=True),
        ).json()
        reset_plan_cache_for_tests()
        client.post(
            "/v1/trips/plan/enrich", json=_payload(avoid_tolls=True),
        )
    finally:
        _unpatch()
    assert core["route"]["avoid_tolls"] is False
    assert core["route"]["toll_cost_eur"] == 99.0
    assert toll.calls == 1  # normal quote flow still runs


# B. honest fallback


def test_no_here_configured_serves_an_honest_tolled_route() -> None:
    default = _Recorder("default")
    p = TollAvoidingRoutingProvider(default=default, here=None)
    r = asyncio.run(p.route(_A, _B, avoid_tolls=True))
    assert default.calls == [False]
    assert r.avoid_tolls is False


def test_fallback_clears_avoid_flag_stamped_by_default_provider() -> None:
    class _Liar(_Recorder):
        async def route(self, *a, **k):
            r = await super().route(*a, **k)
            return dataclasses.replace(r, avoid_tolls=True)

    p = TollAvoidingRoutingProvider(default=_Liar("default"), here=None)
    assert asyncio.run(p.route(_A, _B, avoid_tolls=True)).avoid_tolls is False


def test_here_outage_is_negative_cached_but_request_errors_are_not() -> None:
    here = _Recorder("here", fail=True, error="HERE routing HTTP 401: nope")
    default = _Recorder("default")
    p = TollAvoidingRoutingProvider(default=default, here=here)
    asyncio.run(p.route(_A, _B, avoid_tolls=True))
    asyncio.run(p.route(_A, _B, avoid_tolls=True))
    assert here.calls == [True]  # second call skipped HERE
    assert default.calls == [False, False]

    here2 = _Recorder("here", fail=True, error="HERE routing: no routes")
    p2 = TollAvoidingRoutingProvider(default=_Recorder("d"), here=here2)
    asyncio.run(p2.route(_A, _B, avoid_tolls=True))
    asyncio.run(p2.route(_A, _B, avoid_tolls=True))
    assert here2.calls == [True, True]


_FLEX = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"


def _flex_encode(points: list[tuple[float, float]]) -> str:
    def enc(v: int) -> str:
        out = ""
        while v >= 0x20:
            out += _FLEX[(v & 0x1F) | 0x20]
            v >>= 5
        return out + _FLEX[v]

    def zig(d: int) -> int:
        return d << 1 if d >= 0 else ((-d) << 1) - 1

    out = enc(1) + enc(5)
    plat = plon = 0
    for lat, lon in points:
        la, lo = round(lat * 1e5), round(lon * 1e5)
        out += enc(zig(la - plat)) + enc(zig(lo - plon))
        plat, plon = la, lo
    return out


def _here_provider(sections_tolls: list) -> HereRoutingProvider:
    poly = _flex_encode([(48.0, 2.0), (48.0, 3.0), (48.0, 4.0)])

    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text=json.dumps({"routes": [{"sections": [{
            "summary": {"length": 200000, "duration": 7200},
            "polyline": poly,
            "tolls": sections_tolls,
        }]}]}))

    return HereRoutingProvider(
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )


def test_here_route_is_stamped_toll_free_only_when_response_has_no_tolls(
    monkeypatch,
) -> None:
    from app.providers import routing as routing_mod

    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    routing_mod._HERE_ROUTE_CACHE.clear()
    try:
        clean = asyncio.run(
            _here_provider([]).route(_A, _B, avoid_tolls=True),
        )
        routing_mod._HERE_ROUTE_CACHE.clear()
        dirty = asyncio.run(_here_provider([{"fares": [
            {"price": {"currency": "EUR", "value": 7.5}},
        ]}]).route(_A, _B, avoid_tolls=True))
    finally:
        routing_mod._HERE_ROUTE_CACHE.clear()
    assert clean.avoid_tolls is True and clean.toll_cost_eur == 0.0
    assert dirty.avoid_tolls is False and dirty.toll_cost_eur == 7.5


# C. day 2+ explicit end


def _three_day(overrides):
    return _plan(hours=20.0, overrides=overrides)


def test_day_two_end_minutes_seeds_boundary_from_sleep_stop() -> None:
    _, _, base = _three_day(None)
    assert base.total_days == 3
    ov = {2: {"end_minutes": 15 * 60}}
    route, opt, md = _three_day(ov)
    assert len(opt.sleep_stops) >= 2
    day2_sleep = next(s for s in opt.sleep_stops if s.day_index == 2)
    assert md.days[1].to_km == day2_sleep.rest_stop.distance_from_origin_km
    assert md.days[1].sleep_coord == day2_sleep.rest_stop.coordinate
    assert md.days[1].to_km != base.days[1].to_km
    assert md.days[-1].to_km == pytest.approx(route.distance_km)


def test_day_two_without_end_minutes_is_unchanged() -> None:
    _, _, a = _three_day(None)
    _, _, b = _three_day({2: {"daily_driving_cap_hours": 8}})
    assert [(d.from_km, d.to_km) for d in a.days] == [
        (d.from_km, d.to_km) for d in b.days
    ]


# D. meals off


def test_end_time_is_honoured_when_meal_stops_are_off() -> None:
    assert to.resolve_day_cap_hours(
        profile=_PROFILE, override={"end_minutes": 17 * 60 + 48},
        day_start=_DEP_DT, avg_kmh=90.0, meals_enabled=False,
    ) == pytest.approx(9.8 / 1.10)

    route = _line_route(_NORMAL_LAT, 14.0)
    rests = compute_rest_stops(route, profile=_PROFILE)
    ov = _end(16 * 60)
    opt = to.compute(
        departure_at=_DEP_DT, trip_duration_hours=14.0, rest_stops=rests,
        restaurants_by_slot={}, hotels=(), profile=_PROFILE,
        include_meal_stops=False, day_overrides=ov,
        route_km=route.distance_km,
    )
    md = dp.compute(
        departure_at=_DEP_DT, trip_duration_hours=14.0, profile=_PROFILE,
        optimizations=opt, rest_stops=rests,
        route_distance_km=route.distance_km, route=route, day_overrides=ov,
    )
    assert opt.meals_enabled is False and opt.meal_stops == ()
    requested = datetime(2026, 8, 24, 16, 0)
    end = md.days[0].end_at
    assert abs((end - requested).total_seconds()) <= 3600
    # With meals ON the same request budgets 2 h of meals, so the cap
    # (and with it the target) is smaller.
    on = to.resolve_day_cap_hours(
        profile=_PROFILE, override={"end_minutes": 16 * 60},
        day_start=_DEP_DT, avg_kmh=90.0,
    )
    off = to.resolve_day_cap_hours(
        profile=_PROFILE, override={"end_minutes": 16 * 60},
        day_start=_DEP_DT, avg_kmh=90.0, meals_enabled=False,
    )
    assert off > on


# E. snap retry


def test_end_near_day_start_still_gets_a_sleep_stop() -> None:
    # 09:00 is one hour after departure: the tight +-90 min search finds
    # nothing (first rest stop arrives ~10:12), the +-3 h retry does.
    _, opt, md = _plan(overrides=_end(9 * 60))
    assert opt.sleep_stop is not None
    assert opt.sleep_stop.rest_stop.distance_from_origin_km == 180.0
    assert md.days[0].to_km == 180.0


# F. validation


def test_day_override_driving_cap_hours_bounds() -> None:
    assert DayOverrideIn(
        day_index=1, daily_driving_cap_hours=1,
    ).daily_driving_cap_hours == 1
    assert DayOverrideIn(
        day_index=1, daily_driving_cap_hours=14,
    ).daily_driving_cap_hours == 14
    for bad in (0, 15):
        with pytest.raises(ValidationError):
            DayOverrideIn(day_index=1, daily_driving_cap_hours=bad)


def _here_tolls_provider(tolls: list[dict]):
    from app.providers import tolls_here

    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text=json.dumps(
            {"routes": [{"sections": [{"tolls": tolls}]}]},
        ))

    tolls_here._QUOTE_CACHE.clear()
    return tolls_here.HereTollsProvider(
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )


def test_here_quote_uses_converted_eur_for_foreign_currency_tolls(
    monkeypatch,
) -> None:
    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    provider = _here_tolls_provider([
        {"tollSystem": "ORESUNDSBRON", "fares": [{
            "price": {"currency": "SEK", "value": 690.0},
            "convertedPrice": {"currency": "EUR", "value": 61.58},
        }]},
        {"tollSystem": "VIGNETTE SWITZERLAND", "fares": [{
            "price": {"currency": "CHF", "value": 40.0},
            "convertedPrice": {"currency": "EUR", "value": 43.02},
        }]},
    ])
    q = asyncio.run(provider.quote(_line_route(_NORMAL_LAT, 10.0)))
    assert q is not None
    assert q.total_eur == 104.6
    assert len(q.tolls) == 2


def test_here_quote_with_unpriced_tolls_is_unavailable_not_zero(
    monkeypatch,
) -> None:
    monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "k")
    provider = _here_tolls_provider([
        {"tollSystem": "X", "fares": [
            {"price": {"currency": "SEK", "value": 690.0}},
        ]},
    ])
    assert asyncio.run(provider.quote(_line_route(_NORMAL_LAT, 10.0))) is None


def test_enrich_flags_tolls_unavailable_and_drops_estimated_extras() -> None:
    stub = _StubRouting()
    _patch(stub, _CountingToll())
    try:
        resp = client.post(
            "/v1/trips/plan/enrich",
            json=_payload(include_toll_alternative=True),
        )
    finally:
        _unpatch()
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["route"]["toll_unavailable"] is True
    assert body["route"]["toll_verified"] is False
    assert body["partial_toll_skips"] == []
    assert body["toll_alternative"] is None


def test_merge_route_carries_toll_unavailable() -> None:
    from app.api.v1.trips import RouteOut, _merge_route

    core = RouteOut(
        distance_km=10, free_flow_minutes=5, polyline="",
        toll_cost_eur=63.8, countries_crossed=[], geometry=[],
    )
    enrich = core.model_copy(update={
        "toll_cost_eur": 0.0, "toll_unavailable": True,
    })
    merged = _merge_route(core, enrich)
    assert merged.toll_unavailable is True
    assert merged.toll_verified is False


def test_place_label_names_the_town_and_zone_not_the_street() -> None:
    from app.providers.geocoding import place_label_from_address

    assert place_label_from_address(
        {"road": "E 6", "village": "Hjärnarp", "county": "Skåne County"},
    ) == "Hjärnarp (Skåne County)"
    assert place_label_from_address(
        {"road": "E 6", "county": "Skåne County"},
    ) == "Skåne County"
    assert place_label_from_address({"city": "Oslo", "state": "Oslo"}) == "Oslo"
    assert place_label_from_address({"road": "E 6"}) is None

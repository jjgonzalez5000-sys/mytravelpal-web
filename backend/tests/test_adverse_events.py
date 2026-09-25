from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.domain import (
    AdverseEvent,
    AdverseEventSeverity,
    AdverseEventSource,
    AdverseEventType,
    Coordinate,
    Country,
    Route,
)
from app.main import app
from app.providers import (
    CompositeAdverseEventsProvider,
    MockAdverseEventsProvider,
    MockRoutingProvider,
    UserMarkedAdverseEventsProvider,
)
from app.services.adverse_events_filter import filter_events_near_route

client = TestClient(app)

_PARIS = Coordinate(48.8566, 2.3522)
_MADRID = Coordinate(40.4168, -3.7038)
_NOW = datetime(2026, 8, 20, 12, tzinfo=timezone.utc)


def _event(
    *, id: str = "e1", type: AdverseEventType = AdverseEventType.STRIKE,
    severity: AdverseEventSeverity = AdverseEventSeverity.WARNING,
    coord: Coordinate = Coordinate(48.85, 2.35),
) -> AdverseEvent:
    return AdverseEvent(
        id=id, type=type, severity=severity, source=AdverseEventSource.MOCK,
        coordinate=coord, description="d",
        reported_at=_NOW - timedelta(hours=1),
        expires_at=_NOW + timedelta(hours=10),
    )


class TestUserMarkedProvider:
    def test_submit_stores_the_event(self) -> None:
        p = UserMarkedAdverseEventsProvider()
        e = p.submit(
            type=AdverseEventType.PROTEST, severity=AdverseEventSeverity.INFO,
            coordinate=Coordinate(45, 4), description="  march  ",
            reported_at=_NOW,
        )
        assert e.description == "march"
        assert e.source is AdverseEventSource.USER
        assert p.all_active(now=_NOW) == (e,)

    def test_expired_events_are_purged(self) -> None:
        p = UserMarkedAdverseEventsProvider()
        p.submit(
            type=AdverseEventType.STRIKE, severity=AdverseEventSeverity.WARNING,
            coordinate=Coordinate(45, 4), description="x",
            reported_at=_NOW - timedelta(hours=48),
            expires_at=_NOW - timedelta(hours=24),
        )
        assert p.all_active(now=_NOW) == ()

    def test_default_ttl_is_24h(self) -> None:
        p = UserMarkedAdverseEventsProvider()
        e = p.submit(
            type=AdverseEventType.STRIKE, severity=AdverseEventSeverity.INFO,
            coordinate=Coordinate(45, 4), description="x", reported_at=_NOW,
        )
        assert e.expires_at - e.reported_at == timedelta(hours=24)


class TestFilter:
    def _route(self) -> Route:
        # A short synthetic route with a known waypoint near (46, 3).
        return Route(
            origin=Coordinate(48, 2), destination=Coordinate(44, 4),
            distance_km=500, free_flow_duration=timedelta(hours=5),
            polyline="p", toll_cost_eur=0,
            countries_crossed=(Country.FR,),
            waypoints=(Coordinate(46, 3),),
        )

    def test_far_event_is_dropped(self) -> None:
        far = _event(coord=Coordinate(38, -10))  # ~1500 km away
        kept = filter_events_near_route((far,), self._route(), max_distance_km=25.0)
        assert kept == ()

    def test_close_event_is_kept(self) -> None:
        close = _event(coord=Coordinate(46.05, 3.05))
        kept = filter_events_near_route((close,), self._route(), max_distance_km=25.0)
        assert kept == (close,)

    def test_sorts_critical_before_warning_before_info(self) -> None:
        info = _event(id="i", severity=AdverseEventSeverity.INFO, coord=Coordinate(46, 3))
        warn = _event(id="w", severity=AdverseEventSeverity.WARNING, coord=Coordinate(46, 3))
        crit = _event(id="c", severity=AdverseEventSeverity.CRITICAL, coord=Coordinate(46, 3))
        kept = filter_events_near_route((info, warn, crit), self._route())
        assert [e.id for e in kept] == ["c", "w", "i"]

    def test_true_duplicates_collapse_to_one(self) -> None:
        """Same type + severity + description within 0.5 km → one entry."""
        a = _event(id="a", coord=Coordinate(46.00, 3.00))
        b = _event(id="b", coord=Coordinate(46.001, 3.001))  # ~150 m
        kept = filter_events_near_route((a, b), self._route())
        assert len(kept) == 1
        assert kept[0].id == "a"  # first one wins

    def test_same_id_repeated_collapses(self) -> None:
        """Composite providers may return the same id twice."""
        one = _event(id="dup", coord=Coordinate(46, 3))
        two = _event(id="dup", coord=Coordinate(46, 3))
        kept = filter_events_near_route((one, two), self._route())
        assert len(kept) == 1


class TestCompositeProvider:
    @pytest.mark.asyncio
    async def test_concatenates_all_children(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        composite = CompositeAdverseEventsProvider(
            providers=(MockAdverseEventsProvider(), UserMarkedAdverseEventsProvider()),
        )
        events = await composite.events_along(route, now=_NOW)
        # Mock provides 8 demo events; user provider adds 0 initially.
        assert len(events) == 8


class TestPlanEndpoint:
    def _plan(self, **extra: object) -> dict:
        payload = {
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            **extra,
        }
        response = client.post("/v1/trips/plan", json=payload)
        assert response.status_code == 200, response.text
        return response.json()

    def test_events_empty_by_default(self) -> None:
        body = self._plan()
        assert body["adverse_events"] == []

    def test_include_returns_events_near_route(self) -> None:
        body = self._plan(include_adverse_events=True)
        # Paris-Madrid passes near the Paris strike (48.85, 2.35),
        # the Lyon roadwork (45.76, 4.84 — actually off route), and
        # the Zaragoza accident (41.65, -0.90). At least one hits.
        assert len(body["adverse_events"]) >= 1
        assert all(e["source"] in {"mock", "user"} for e in body["adverse_events"])

    def test_max_distance_narrows_results(self) -> None:
        wide = self._plan(include_adverse_events=True, adverse_events_max_distance_km=200)
        narrow = self._plan(include_adverse_events=True, adverse_events_max_distance_km=5)
        assert len(wide["adverse_events"]) >= len(narrow["adverse_events"])


class TestSubmitEndpoint:
    def test_submit_and_it_shows_up_in_plan(self) -> None:
        # Post a user-marked event right on the Paris → Madrid line.
        sub = client.post("/v1/adverse-events", json={
            "type": "fire", "severity": "critical",
            "lat": 44.0, "lon": -0.5,
            "description": "Test fire near Bordeaux",
        })
        assert sub.status_code == 200, sub.text
        event_id = sub.json()["id"]

        body = client.post("/v1/trips/plan", json={
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            "include_adverse_events": True,
            "adverse_events_max_distance_km": 100,
        }).json()

        found = [e for e in body["adverse_events"] if e["id"] == event_id]
        assert found, "user-submitted event should surface on nearby plans"

    def test_rejects_invalid_coordinates(self) -> None:
        r = client.post("/v1/adverse-events", json={
            "type": "fire", "severity": "warning",
            "lat": 999, "lon": 0, "description": "x",
        })
        assert r.status_code == 422

    def test_rejects_empty_description(self) -> None:
        r = client.post("/v1/adverse-events", json={
            "type": "fire", "severity": "warning",
            "lat": 45, "lon": 4, "description": "",
        })
        assert r.status_code == 422


class TestAdverseEventEnum:
    """Post-2026-08-28 additions (tester ask): landslide, earthquake,
    avalanche, road closure, heatwave. These must be present so mobile
    clients that reference them by string code (`type=heatwave`) round-trip
    cleanly through the pydantic serialiser.
    """

    def test_enum_carries_all_new_types(self) -> None:
        codes = {t.value for t in AdverseEventType}
        for expected in (
            "earthquake", "landslide", "avalanche",
            "closure", "heatwave", "strike",
        ):
            assert expected in codes, f"missing AdverseEventType.{expected}"


class TestNewStubProviders:
    """Copernicus EMS + road-closure stubs must be silent (return ())
    until wired. Kept as a smoke test so accidental production wiring
    doesn't ship without a corresponding test update.
    """

    @pytest.mark.asyncio
    async def test_copernicus_stub_returns_empty(self) -> None:
        from app.providers.copernicus_ems import CopernicusEmsProvider
        p = CopernicusEmsProvider()
        route = Route(
            origin=_PARIS, destination=_MADRID, distance_km=1000,
            free_flow_duration=timedelta(hours=10), polyline="p",
            toll_cost_eur=0, countries_crossed=(Country.FR, Country.ES),
        )
        assert await p.events_along(route, now=_NOW) == ()

    @pytest.mark.asyncio
    async def test_road_closure_stub_returns_empty(self) -> None:
        from app.providers.road_closures import RoadClosureProvider
        p = RoadClosureProvider()
        route = Route(
            origin=_PARIS, destination=_MADRID, distance_km=1000,
            free_flow_duration=timedelta(hours=10), polyline="p",
            toll_cost_eur=0, countries_crossed=(Country.FR, Country.ES),
        )
        assert await p.events_along(route, now=_NOW) == ()

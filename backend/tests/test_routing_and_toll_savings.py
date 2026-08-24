from __future__ import annotations

import json
from datetime import timedelta

import httpx
import pytest
from fastapi.testclient import TestClient

from app.domain import Coordinate, Country, Route
from app.main import app
from app.providers import (
    FallbackRoutingProvider,
    MockRoutingProvider,
    OsrmRoutingProvider,
)
from app.services.toll_savings import compare

client = TestClient(app)

_PARIS = Coordinate(48.8566, 2.3522)
_MADRID = Coordinate(40.4168, -3.7038)


class TestMockAvoidTolls:
    @pytest.mark.asyncio
    async def test_avoid_tolls_zeroes_the_toll_cost(self) -> None:
        provider = MockRoutingProvider()
        with_tolls = await provider.route(_PARIS, _MADRID)
        without = await provider.route(_PARIS, _MADRID, avoid_tolls=True)
        assert with_tolls.toll_cost_eur > 0
        assert without.toll_cost_eur == 0
        assert without.avoid_tolls is True

    @pytest.mark.asyncio
    async def test_avoid_tolls_makes_route_longer_and_slower(self) -> None:
        provider = MockRoutingProvider()
        base = await provider.route(_PARIS, _MADRID)
        alt = await provider.route(_PARIS, _MADRID, avoid_tolls=True)
        assert alt.distance_km > base.distance_km
        assert alt.free_flow_duration > base.free_flow_duration

    @pytest.mark.asyncio
    async def test_mock_has_empty_geometry(self) -> None:
        route = await MockRoutingProvider().route(_PARIS, _MADRID)
        assert route.geometry == ()


class TestOsrmProvider:
    def _fake_transport(self, geo_len: int = 200) -> httpx.AsyncClient:
        geometry = [[2.35 + i * 0.01, 48.85 - i * 0.05] for i in range(geo_len)]

        async def handler(request: httpx.Request) -> httpx.Response:
            assert '/route/v1/driving/' in str(request.url)
            body = {
                'code': 'Ok',
                'routes': [
                    {
                        'distance': 1_316_000.0,
                        'duration': 46_800.0,
                        'geometry': {'type': 'LineString', 'coordinates': geometry},
                    }
                ],
            }
            return httpx.Response(200, text=json.dumps(body))

        return httpx.AsyncClient(transport=httpx.MockTransport(handler))

    @pytest.mark.asyncio
    async def test_parses_osrm_response(self) -> None:
        provider = OsrmRoutingProvider(http_client=self._fake_transport())
        route = await provider.route(_PARIS, _MADRID)
        assert route.distance_km == pytest.approx(1316.0, rel=0.01)
        assert route.free_flow_duration == timedelta(seconds=46_800.0)
        assert len(route.geometry) == 200
        assert route.geometry[0] == Coordinate(lat=48.85, lon=2.35)

    @pytest.mark.asyncio
    async def test_avoid_tolls_appends_exclude_param(self) -> None:
        captured: dict = {}

        async def handler(request: httpx.Request) -> httpx.Response:
            captured['url'] = str(request.url)
            body = {
                'code': 'Ok',
                'routes': [
                    {
                        'distance': 100.0, 'duration': 10.0,
                        'geometry': {'type': 'LineString',
                                     'coordinates': [[2, 48], [3, 49]]},
                    }
                ],
            }
            return httpx.Response(200, text=json.dumps(body))

        client_ = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        provider = OsrmRoutingProvider(http_client=client_)
        await provider.route(_PARIS, _MADRID, avoid_tolls=True)
        assert 'exclude=toll' in captured['url']

    @pytest.mark.asyncio
    async def test_raises_on_no_route(self) -> None:
        async def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, text=json.dumps({'code': 'NoRoute'}))

        client_ = httpx.AsyncClient(transport=httpx.MockTransport(handler))
        provider = OsrmRoutingProvider(http_client=client_)
        with pytest.raises(httpx.HTTPError):
            await provider.route(_PARIS, _MADRID)


class TestFallback:
    @pytest.mark.asyncio
    async def test_falls_back_when_primary_raises(self) -> None:
        class _Broken:
            async def route(self, *a, **kw):
                raise httpx.ConnectError('down')

        wrapped = FallbackRoutingProvider(_Broken(), MockRoutingProvider())
        route = await wrapped.route(_PARIS, _MADRID)
        assert route.distance_km > 0  # mock produced something


class TestTollSavings:
    def _route(
        self,
        *, distance_km: float, hours: float, toll: float,
    ) -> Route:
        return Route(
            origin=_PARIS, destination=_MADRID,
            distance_km=distance_km,
            free_flow_duration=timedelta(hours=hours),
            polyline='p', toll_cost_eur=toll,
            countries_crossed=(Country.FR, Country.ES),
        )

    def test_worth_it_when_savings_high_and_penalty_low(self) -> None:
        main = self._route(distance_km=1000, hours=10, toll=100)
        alt = self._route(distance_km=1100, hours=10.4, toll=0)
        result = compare(main, alt)
        assert result.savings_eur == 100.0
        assert result.time_penalty_minutes == pytest.approx(24.0, rel=0.01)
        assert result.worth_it is True

    def test_not_worth_it_when_savings_tiny(self) -> None:
        main = self._route(distance_km=1000, hours=10, toll=3)
        alt = self._route(distance_km=1100, hours=10.2, toll=0)
        assert compare(main, alt).worth_it is False

    def test_not_worth_it_when_time_penalty_huge(self) -> None:
        main = self._route(distance_km=1000, hours=10, toll=100)
        alt = self._route(distance_km=1400, hours=13, toll=0)
        assert compare(main, alt).worth_it is False


class TestPlanEndpointTollAlternative:
    def _plan(self, **extra):
        payload = {
            'origin': {'lat': 48.8566, 'lon': 2.3522},
            'destination': {'lat': 40.4168, 'lon': -3.7038},
            'desired_departure_at': '2026-08-24T08:00:00',
            **extra,
        }
        response = client.post('/v1/trips/plan', json=payload)
        assert response.status_code == 200, response.text
        return response.json()

    def test_toll_alternative_omitted_by_default(self) -> None:
        body = self._plan()
        assert body['toll_alternative'] is None

    def test_include_returns_alternative_with_savings(self) -> None:
        body = self._plan(include_toll_alternative=True)
        alt = body['toll_alternative']
        assert alt is not None
        assert alt['savings_eur'] > 0
        assert alt['time_penalty_minutes'] > 0
        assert alt['extra_distance_km'] > 0

    def test_route_geometry_is_empty_when_mock_provider(self) -> None:
        # conftest forces MYTRAVELPAL_ROUTING=mock, so no geometry.
        body = self._plan()
        assert body['route']['geometry'] == []

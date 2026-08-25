"""Sprint 15: route_variants service + /trips/plan integration."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.domain import Coordinate
from app.main import app
from app.providers import MockRoutingProvider
from app.services.route_variants import compute_variants

client = TestClient(app)


class TestRouteVariantsService:
    @pytest.mark.asyncio
    async def test_returns_three_variants_including_primary(self) -> None:
        provider = MockRoutingProvider()
        origin = Coordinate(48.8566, 2.3522)
        destination = Coordinate(40.4168, -3.7038)
        primary = await provider.route(origin, destination)
        variants = await compute_variants(
            provider=provider, primary=primary,
            origin=origin, destination=destination,
            countries=primary.countries_crossed,
        )
        assert [v.key for v in variants] == ['fastest', 'toll_free', 'scenic']

    @pytest.mark.asyncio
    async def test_toll_free_variant_has_lower_toll_cost(self) -> None:
        provider = MockRoutingProvider()
        origin = Coordinate(48.8566, 2.3522)
        destination = Coordinate(40.4168, -3.7038)
        primary = await provider.route(origin, destination)
        variants = await compute_variants(
            provider=provider, primary=primary,
            origin=origin, destination=destination,
            countries=primary.countries_crossed,
        )
        by_key = {v.key: v for v in variants}
        assert by_key['toll_free'].route.toll_cost_eur == 0
        assert by_key['fastest'].route.toll_cost_eur > 0

    @pytest.mark.asyncio
    async def test_scenic_variant_takes_longer_but_same_distance_ish(self) -> None:
        provider = MockRoutingProvider()
        origin = Coordinate(48.8566, 2.3522)
        destination = Coordinate(40.4168, -3.7038)
        primary = await provider.route(origin, destination)
        variants = await compute_variants(
            provider=provider, primary=primary,
            origin=origin, destination=destination,
            countries=primary.countries_crossed,
        )
        scenic = next(v for v in variants if v.key == 'scenic')
        assert scenic.route.free_flow_duration > primary.free_flow_duration


class TestPlanEndpointVariants:
    def _plan(self, **extra):
        payload = {
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            **extra,
        }
        response = client.post("/v1/trips/plan", json=payload)
        assert response.status_code == 200, response.text
        return response.json()

    def test_route_variants_empty_by_default(self) -> None:
        assert self._plan()["route_variants"] == []

    def test_include_returns_all_three_variants(self) -> None:
        body = self._plan(include_route_comparison=True)
        variants = body["route_variants"]
        assert [v["key"] for v in variants] == [
            "fastest", "toll_free", "scenic",
        ]
        for v in variants:
            assert v["distance_km"] > 0
            assert v["free_flow_minutes"] > 0

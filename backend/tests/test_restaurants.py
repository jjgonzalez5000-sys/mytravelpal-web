from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.domain import Coordinate, Country, PriceBand, Restaurant
from app.main import app
from app.providers import MockRestaurantsProvider, MockRoutingProvider
from app.services.restaurant_search import filter_restaurants

client = TestClient(app)


def _r(*, band: PriceBand, detour: float, price: float) -> Restaurant:
    return Restaurant(
        name="R",
        coordinate=Coordinate(lat=45, lon=5),
        country=Country.FR,
        price_eur_per_meal=price,
        price_band=band,
        distance_from_route_km=detour * 0.5,
        detour_minutes=detour,
    )


class TestFilterRestaurants:
    def test_filters_by_max_detour(self) -> None:
        rs = (
            _r(band=PriceBand.MID, detour=10, price=30),
            _r(band=PriceBand.MID, detour=40, price=32),
        )
        kept = filter_restaurants(rs, max_detour_minutes=20, price_band=PriceBand.ANY)
        assert len(kept) == 1

    def test_filters_by_band(self) -> None:
        rs = (
            _r(band=PriceBand.BUDGET, detour=10, price=15),
            _r(band=PriceBand.LUX, detour=10, price=80),
        )
        kept = filter_restaurants(rs, max_detour_minutes=60, price_band=PriceBand.LUX)
        assert [r.price_band for r in kept] == [PriceBand.LUX]

    def test_sorts_by_detour_then_price(self) -> None:
        rs = (
            _r(band=PriceBand.MID, detour=20, price=25),
            _r(band=PriceBand.MID, detour=10, price=40),
            _r(band=PriceBand.MID, detour=10, price=28),
        )
        kept = filter_restaurants(rs, max_detour_minutes=60, price_band=PriceBand.ANY)
        assert [r.price_eur_per_meal for r in kept] == [28, 40, 25]


class TestMockRestaurantsProvider:
    @pytest.mark.asyncio
    async def test_produces_two_restaurants_per_waypoint(self) -> None:
        routing = MockRoutingProvider()
        paris = Coordinate(lat=48.8566, lon=2.3522)
        madrid = Coordinate(lat=40.4168, lon=-3.7038)
        route = await routing.route(paris, madrid)
        restaurants = await MockRestaurantsProvider().restaurants_along(route)
        assert len(restaurants) == 2 * len(route.waypoints)

    @pytest.mark.asyncio
    async def test_deterministic(self) -> None:
        routing = MockRoutingProvider()
        paris = Coordinate(lat=48.8566, lon=2.3522)
        madrid = Coordinate(lat=40.4168, lon=-3.7038)
        route = await routing.route(paris, madrid)
        p = MockRestaurantsProvider()
        assert await p.restaurants_along(route) == await p.restaurants_along(route)


class TestPlanEndpointRestaurantsAndStops:
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

    def test_rest_stops_included_by_default_for_long_trip(self) -> None:
        body = self._plan()
        # Paris → Madrid ≈ 14 hours in the mock; expect several stops.
        assert len(body["rest_stops"]) >= 3
        assert all(s["recommended_break_minutes"] == 15 for s in body["rest_stops"])

    def test_rest_stops_have_growing_cumulative_hours(self) -> None:
        body = self._plan()
        hours = [s["cumulative_driving_hours"] for s in body["rest_stops"]]
        assert hours == sorted(hours)
        assert hours[0] == pytest.approx(2.0)

    def test_no_restaurants_when_not_requested(self) -> None:
        body = self._plan()
        assert body["restaurants"] == []

    def test_enabling_restaurants_returns_at_least_one(self) -> None:
        body = self._plan(
            restaurant_max_detour_minutes=30, restaurant_price_band="any"
        )
        assert len(body["restaurants"]) >= 1
        r = body["restaurants"][0]
        assert r["price_band"] in {"budget", "mid", "lux"}
        assert r["detour_minutes"] <= 30

    def test_restaurant_band_filter(self) -> None:
        body = self._plan(
            restaurant_max_detour_minutes=120, restaurant_price_band="budget"
        )
        assert all(r["price_band"] == "budget" for r in body["restaurants"])

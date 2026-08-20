from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.domain import Coordinate, Country, Hotel, PriceBand
from app.main import app
from app.providers import MockHotelsProvider, MockRoutingProvider
from app.services.hotel_search import filter_hotels

client = TestClient(app)

_PARIS = Coordinate(lat=48.8566, lon=2.3522)
_MADRID = Coordinate(lat=40.4168, lon=-3.7038)


def _hotel(*, band: PriceBand, detour: float, price: float) -> Hotel:
    return Hotel(
        name="H",
        coordinate=Coordinate(lat=45, lon=5),
        country=Country.FR,
        price_eur_per_night=price,
        price_band=band,
        distance_from_route_km=detour * 0.5,
        detour_minutes=detour,
    )


class TestPriceBand:
    def test_from_price_bands(self) -> None:
        assert PriceBand.from_price_eur(60) is PriceBand.BUDGET
        assert PriceBand.from_price_eur(100) is PriceBand.MID
        assert PriceBand.from_price_eur(160) is PriceBand.MID
        assert PriceBand.from_price_eur(161) is PriceBand.LUX
        assert PriceBand.from_price_eur(500) is PriceBand.LUX


class TestFilterHotels:
    def test_filters_by_max_detour(self) -> None:
        hotels = (
            _hotel(band=PriceBand.MID, detour=10, price=100),
            _hotel(band=PriceBand.MID, detour=45, price=110),
        )
        kept = filter_hotels(hotels, max_detour_minutes=20, price_band=PriceBand.ANY)
        assert len(kept) == 1
        assert kept[0].detour_minutes == 10

    def test_filters_by_price_band(self) -> None:
        hotels = (
            _hotel(band=PriceBand.BUDGET, detour=10, price=60),
            _hotel(band=PriceBand.LUX, detour=10, price=250),
        )
        kept = filter_hotels(hotels, max_detour_minutes=60, price_band=PriceBand.LUX)
        assert len(kept) == 1
        assert kept[0].price_band is PriceBand.LUX

    def test_any_band_keeps_all_within_detour(self) -> None:
        hotels = (
            _hotel(band=PriceBand.BUDGET, detour=10, price=60),
            _hotel(band=PriceBand.LUX, detour=15, price=250),
        )
        kept = filter_hotels(hotels, max_detour_minutes=60, price_band=PriceBand.ANY)
        assert len(kept) == 2

    def test_sorts_by_detour_then_price(self) -> None:
        hotels = (
            _hotel(band=PriceBand.MID, detour=20, price=100),
            _hotel(band=PriceBand.MID, detour=10, price=150),
            _hotel(band=PriceBand.MID, detour=10, price=110),
        )
        kept = filter_hotels(hotels, max_detour_minutes=60, price_band=PriceBand.ANY)
        assert [h.price_eur_per_night for h in kept] == [110, 150, 100]

    def test_limit_caps_results(self) -> None:
        hotels = tuple(
            _hotel(band=PriceBand.MID, detour=i, price=100 + i) for i in range(20)
        )
        kept = filter_hotels(
            hotels, max_detour_minutes=60, price_band=PriceBand.ANY, limit=5
        )
        assert len(kept) == 5


class TestMockHotelsProvider:
    @pytest.mark.asyncio
    async def test_returns_hotels_per_waypoint(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        hotels = await MockHotelsProvider().hotels_along(route)
        assert len(hotels) == 3 * len(route.waypoints)

    @pytest.mark.asyncio
    async def test_prices_span_expected_bands_over_a_long_route(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        hotels = await MockHotelsProvider().hotels_along(route)
        bands = {h.price_band for h in hotels}
        # Over 30 hotels spanning FR + ES, we should see at least 2 bands.
        assert len(bands) >= 2

    @pytest.mark.asyncio
    async def test_deterministic_across_calls(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        provider = MockHotelsProvider()
        a = await provider.hotels_along(route)
        b = await provider.hotels_along(route)
        assert a == b


class TestPlanEndpointHotelParams:
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

    def test_no_hotel_params_returns_empty_hotels_list(self) -> None:
        body = self._plan()
        assert body["hotels"] == []

    def test_zero_detour_returns_empty_hotels_list(self) -> None:
        body = self._plan(hotel_max_detour_minutes=0)
        assert body["hotels"] == []

    def test_enabling_hotels_returns_at_least_one(self) -> None:
        body = self._plan(hotel_max_detour_minutes=60, hotel_price_band="any")
        assert len(body["hotels"]) >= 1
        h = body["hotels"][0]
        assert h["price_band"] in {"budget", "mid", "lux"}
        assert h["detour_minutes"] <= 60

    def test_band_filter_returns_only_that_band(self) -> None:
        body = self._plan(hotel_max_detour_minutes=120, hotel_price_band="budget")
        assert all(h["price_band"] == "budget" for h in body["hotels"])

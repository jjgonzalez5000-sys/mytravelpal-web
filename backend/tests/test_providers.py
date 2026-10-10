from __future__ import annotations

from datetime import datetime

import pytest

from app.domain import Coordinate, Country
from app.providers import (
    MockFuelProvider,
    MockRoutingProvider,
    MockTollsProvider,
    MockTrafficProvider,
)

_PARIS = Coordinate(lat=48.8566, lon=2.3522)
_MADRID = Coordinate(lat=40.4168, lon=-3.7038)


@pytest.mark.asyncio
async def test_routing_mock_is_deterministic() -> None:
    provider = MockRoutingProvider()
    a = await provider.route(_PARIS, _MADRID, (Country.FR, Country.ES))
    b = await provider.route(_PARIS, _MADRID, (Country.FR, Country.ES))
    assert a == b


@pytest.mark.asyncio
async def test_routing_mock_distance_is_reasonable_for_paris_madrid() -> None:
    provider = MockRoutingProvider()
    route = await provider.route(_PARIS, _MADRID, (Country.FR, Country.ES))
    # Real Paris-Madrid by road is ~1270 km. Our great-circle × 1.25 sits in the
    # same ballpark; assert a generous but meaningful range.
    assert 1200.0 < route.distance_km < 1600.0


@pytest.mark.asyncio
async def test_routing_mock_adds_ch_vignette_component() -> None:
    provider = MockRoutingProvider()
    from app.data.countries import COUNTRIES

    route_with_ch = await provider.route(_PARIS, _MADRID, (Country.FR, Country.CH))
    # The Swiss sticker is a flat amount on top of the per-km tolls. (The
    # per-km part is now shared between the crossed countries, so adding CH
    # to the list no longer raises the total by itself.)
    assert route_with_ch.toll_cost_eur >= COUNTRIES["CH"].vignette_eur


@pytest.mark.asyncio
async def test_traffic_mock_returns_higher_factor_at_rush_hour() -> None:
    routing = MockRoutingProvider()
    traffic = MockTrafficProvider()
    route = await routing.route(_PARIS, _MADRID, (Country.FR,))

    rush = await traffic.factor_at(route, datetime(2026, 8, 24, 8, 0))  # Mon 08:00
    off_peak = await traffic.factor_at(route, datetime(2026, 8, 24, 3, 0))  # Mon 03:00
    assert rush > off_peak
    assert rush > 1.0
    assert off_peak == pytest.approx(1.0)


@pytest.mark.asyncio
async def test_traffic_mock_weekend_peak_is_dampened_vs_weekday() -> None:
    routing = MockRoutingProvider()
    traffic = MockTrafficProvider()
    route = await routing.route(_PARIS, _MADRID, (Country.FR,))

    weekday = await traffic.factor_at(route, datetime(2026, 8, 24, 8, 0))  # Mon
    weekend = await traffic.factor_at(route, datetime(2026, 8, 22, 8, 0))  # Sat
    assert weekday > weekend
    assert weekend >= 1.0


@pytest.mark.asyncio
async def test_tolls_mock_matches_route_toll_cost() -> None:
    routing = MockRoutingProvider()
    tolls = MockTollsProvider()
    route = await routing.route(_PARIS, _MADRID, (Country.FR, Country.ES))
    assert await tolls.cost_eur(route) == route.toll_cost_eur


@pytest.mark.asyncio
async def test_fuel_mock_returns_at_least_one_station_and_is_deterministic() -> None:
    routing = MockRoutingProvider()
    fuel = MockFuelProvider()
    route = await routing.route(_PARIS, _MADRID, (Country.FR, Country.ES))
    a = await fuel.prices_along(route)
    b = await fuel.prices_along(route)
    assert len(a) >= 1
    assert a == b

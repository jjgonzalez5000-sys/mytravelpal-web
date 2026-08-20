from __future__ import annotations

import pytest

from app.domain import Coordinate, Country
from app.providers import MockRoutingProvider
from app.providers.routing import _great_circle_interpolate


_MILANO = Coordinate(lat=45.4642, lon=9.1900)
_MADRID = Coordinate(lat=40.4168, lon=-3.7038)
_PARIS = Coordinate(lat=48.8566, lon=2.3522)


def test_great_circle_interpolate_produces_requested_count() -> None:
    points = _great_circle_interpolate(_MILANO, _MADRID, 10)
    assert len(points) == 10


def test_great_circle_interpolate_returns_ordered_points() -> None:
    """First interpolated point should be closer to origin than the last."""
    from app.providers.routing import _haversine_km

    points = _great_circle_interpolate(_MILANO, _MADRID, 5)
    assert _haversine_km(_MILANO, points[0]) < _haversine_km(_MILANO, points[-1])


@pytest.mark.asyncio
async def test_route_populates_waypoints() -> None:
    provider = MockRoutingProvider()
    route = await provider.route(_MILANO, _MADRID)
    assert route.waypoints, "expected mock routing to fill waypoints"
    assert route.origin not in route.waypoints
    assert route.destination not in route.waypoints


@pytest.mark.asyncio
async def test_route_infers_intermediate_country_from_waypoints() -> None:
    """Milano → Madrid crosses France; waypoint-based detection catches it,
    endpoint-only detection would miss it.
    """
    provider = MockRoutingProvider()
    route = await provider.route(_MILANO, _MADRID)
    assert Country.FR in route.countries_crossed
    # Order preserved along the route: IT origin, FR middle, ES destination.
    assert route.countries_crossed == (Country.IT, Country.FR, Country.ES)


@pytest.mark.asyncio
async def test_countries_override_takes_precedence_over_inference() -> None:
    provider = MockRoutingProvider()
    route = await provider.route(_MILANO, _MADRID, (Country.IT, Country.ES))
    assert route.countries_crossed == (Country.IT, Country.ES)


@pytest.mark.asyncio
async def test_paris_madrid_now_reflects_fr_and_es() -> None:
    provider = MockRoutingProvider()
    route = await provider.route(_PARIS, _MADRID)
    assert route.countries_crossed == (Country.FR, Country.ES)

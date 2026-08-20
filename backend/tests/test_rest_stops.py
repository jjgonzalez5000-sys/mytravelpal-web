from __future__ import annotations

from datetime import timedelta

import pytest

from app.domain import Coordinate, Country, Route
from app.providers import MockRoutingProvider
from app.services.rest_stops import compute_rest_stops


def _route(duration_hours: float, *, distance_km: float = 500.0) -> Route:
    return Route(
        origin=Coordinate(lat=48.85, lon=2.35),
        destination=Coordinate(lat=45.76, lon=4.83),
        distance_km=distance_km,
        free_flow_duration=timedelta(hours=duration_hours),
        polyline="mock",
        toll_cost_eur=0.0,
        countries_crossed=(Country.FR,),
    )


def test_short_trip_returns_no_stops() -> None:
    assert compute_rest_stops(_route(1.5)) == ()
    assert compute_rest_stops(_route(0.5)) == ()


def test_two_hour_trip_returns_no_stops_because_no_room_after_the_first() -> None:
    """A trip that is exactly 2h has one candidate stop at the arrival —
    the ">= 15 min remaining" guard drops it. Zero recommendations.
    """
    assert compute_rest_stops(_route(2.0)) == ()


def test_stops_are_evenly_spaced() -> None:
    stops = compute_rest_stops(_route(8.0))
    hours = [s.cumulative_driving_hours for s in stops]
    assert hours == [2.0, 4.0, 6.0]


def test_distance_scales_with_position() -> None:
    stops = compute_rest_stops(_route(8.0, distance_km=800.0))
    # 2h/8h = 25% of the route ⇒ 200 km. 4h ⇒ 400 km. 6h ⇒ 600 km.
    assert [s.distance_from_origin_km for s in stops] == [200.0, 400.0, 600.0]


def test_recommended_break_defaults_to_15_min() -> None:
    stops = compute_rest_stops(_route(6.0))
    assert all(s.recommended_break_minutes == 15 for s in stops)


@pytest.mark.asyncio
async def test_stops_land_between_origin_and_destination() -> None:
    routing = MockRoutingProvider()
    paris = Coordinate(lat=48.8566, lon=2.3522)
    madrid = Coordinate(lat=40.4168, lon=-3.7038)
    route = await routing.route(paris, madrid)
    stops = compute_rest_stops(route)

    assert stops, "expected at least one stop for Paris → Madrid"
    for s in stops:
        assert min(paris.lat, madrid.lat) <= s.coordinate.lat <= max(paris.lat, madrid.lat)
        assert min(paris.lon, madrid.lon) <= s.coordinate.lon <= max(paris.lon, madrid.lon)

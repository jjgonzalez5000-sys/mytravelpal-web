from __future__ import annotations

from datetime import timedelta

import pytest

from app.domain import (
    Coordinate,
    Country,
    Route,
    TripProfile,
    Vehicle,
    VehicleType,
)
from app.providers import MockRoutingProvider
from app.services.rest_stops import (
    compute_rest_stops,
    recommended_break_minutes,
)


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


def test_kids_bumps_break_to_45_min() -> None:
    profile = TripProfile(has_kids=True)
    assert recommended_break_minutes(profile) == 45
    stops = compute_rest_stops(_route(6.0), profile=profile)
    assert all(s.recommended_break_minutes == 45 for s in stops)


def test_pets_bumps_break_to_45_min() -> None:
    profile = TripProfile(has_pets=True)
    assert recommended_break_minutes(profile) == 45


def test_kids_and_pets_bump_break_to_60_min() -> None:
    profile = TripProfile(has_kids=True, has_pets=True)
    assert recommended_break_minutes(profile) == 60
    stops = compute_rest_stops(_route(6.0), profile=profile)
    assert all(s.recommended_break_minutes == 60 for s in stops)


def test_camper_bumps_break_to_60_min_regardless_of_kids_pets() -> None:
    profile = TripProfile(
        has_kids=False,
        has_pets=False,
        vehicle=Vehicle(type=VehicleType.CAMPER),
    )
    assert recommended_break_minutes(profile) == 60


def test_default_flags_are_all_false_without_enrichment() -> None:
    stops = compute_rest_stops(_route(6.0))
    assert stops
    for s in stops:
        assert s.kid_friendly is False
        assert s.pet_friendly is False
        assert s.rv_friendly is False


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

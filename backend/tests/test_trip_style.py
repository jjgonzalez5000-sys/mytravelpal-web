"""Unit tests for trip_style.derive_scope.

We fabricate `Route`s with a specified `free_flow_duration` (the only
route field the service actually reads) and vary the `TripProfile`
axes. Nothing here touches the network or an event loop.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from app.domain import (
    BreakStyle,
    Coordinate,
    Country,
    OvernightPolicy,
    Route,
    TravelPace,
    TripProfile,
)
from app.services.trip_style import derive_scope


def _route(hours: float) -> Route:
    return Route(
        origin=Coordinate(48.85, 2.35),
        destination=Coordinate(40.42, -3.70),
        distance_km=1000.0,
        free_flow_duration=timedelta(hours=hours),
        polyline="stub",
        toll_cost_eur=0.0,
        countries_crossed=(Country.FR, Country.ES),
    )


_MORNING = datetime(2026, 8, 24, 8, 0)


def test_push_short_trip_hides_rest_stops_and_hotels() -> None:
    profile = TripProfile(travel_pace=TravelPace.PUSH)
    scope = derive_scope(profile, _route(2.5), _MORNING)
    assert scope.rest_stops_count_target == 0
    assert scope.show_rest_stops is False
    assert scope.show_hotels is False
    assert scope.requires_overnight is False


def test_push_long_trip_still_gets_one_rest_stop() -> None:
    profile = TripProfile(travel_pace=TravelPace.PUSH)
    scope = derive_scope(profile, _route(9.0), _MORNING)
    assert scope.rest_stops_count_target == 1
    # 9h > 8h cap → requires overnight even in push mode.
    assert scope.requires_overnight is True
    assert scope.show_hotels is True


def test_steady_default_trip_shows_up_to_two_rest_stops() -> None:
    profile = TripProfile()  # all defaults
    scope = derive_scope(profile, _route(7.0), _MORNING)
    assert scope.rest_stops_count_target == 2
    assert scope.show_rest_stops is True
    # Under the 8h cap and arrival at 15:00 → no overnight.
    assert scope.requires_overnight is False
    assert scope.show_hotels is False


def test_savour_pace_forces_more_rest_stops() -> None:
    profile = TripProfile(travel_pace=TravelPace.SAVOUR)
    scope = derive_scope(profile, _route(6.0), _MORNING)
    assert scope.rest_stops_count_target == 3
    # Savour also shows hotels for trips > 4h even without overnight.
    assert scope.show_hotels is True


def test_overnight_never_hides_hotels_even_when_bedtime_crossed() -> None:
    profile = TripProfile(
        overnight_policy=OvernightPolicy.NEVER,
        bedtime_hour=22,
    )
    # 8h departing at 20:00 → arrival 04:00 next day, past bedtime.
    late = _MORNING.replace(hour=20)
    scope = derive_scope(profile, _route(8.0), late)
    assert scope.requires_overnight is False
    assert scope.show_hotels is False


def test_always_if_long_forces_overnight_beyond_6h() -> None:
    profile = TripProfile(
        overnight_policy=OvernightPolicy.ALWAYS_IF_LONG,
    )
    scope = derive_scope(profile, _route(6.5), _MORNING)
    assert scope.requires_overnight is True
    assert scope.show_hotels is True


def test_arrival_after_bedtime_detected_at_default_22() -> None:
    profile = TripProfile()  # bedtime_hour=22
    # Depart at 18:00 for a 6h trip → arrival at 00:00 next day.
    evening = _MORNING.replace(hour=18)
    scope = derive_scope(profile, _route(6.0), evening)
    assert scope.arrival_after_bedtime is True
    assert scope.requires_overnight is True  # if_needed + past bedtime
    assert scope.arrival_local_hour == 0


def test_break_style_minimal_hides_restaurants() -> None:
    profile = TripProfile(break_style=BreakStyle.MINIMAL)
    scope = derive_scope(profile, _route(4.0), _MORNING)
    assert scope.show_restaurants is False


def test_break_style_foodie_shows_restaurants() -> None:
    profile = TripProfile(break_style=BreakStyle.FOODIE)
    scope = derive_scope(profile, _route(4.0), _MORNING)
    assert scope.show_restaurants is True


def test_reason_string_is_populated() -> None:
    profile = TripProfile(travel_pace=TravelPace.PUSH)
    scope = derive_scope(profile, _route(2.0), _MORNING)
    assert scope.reason  # non-empty

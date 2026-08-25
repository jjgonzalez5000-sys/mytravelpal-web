"""Consistency service tests.

Motivated by the "12:00 depart, lunch at 13:00, 350 km" bug: the app
should flag a meal-stop that implies impossible driving speed instead
of silently displaying an inconsistent tile.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.domain import Coordinate, MealSlot, RestStop
from app.services.consistency import Severity, check_trip
from app.services.trip_optimizations import MealStop, Optimizations


def _rest(km: float, hours: float) -> RestStop:
    return RestStop(
        coordinate=Coordinate(lat=41.0, lon=2.0),
        distance_from_origin_km=km,
        cumulative_driving_hours=hours,
        recommended_break_minutes=20,
    )


def _meal(
    *,
    slot: MealSlot,
    departure: datetime,
    hours_from_departure: float,
    km: float,
) -> MealStop:
    return MealStop(
        slot=slot,
        at=departure + timedelta(hours=hours_from_departure),
        rest_stop=_rest(km=km, hours=hours_from_departure),
        restaurant=None,
    )


DEPART = datetime(2026, 8, 25, 12, 0, tzinfo=timezone.utc)
ARRIVAL = DEPART + timedelta(hours=5)  # 500 km @ 100 km/h ~ 5h drive


def test_plausible_lunch_stop_produces_no_issue():
    # Lunch at 13:00 (1h in) at km 90 → 90 km/h. Perfectly normal.
    meal = _meal(
        slot=MealSlot.LUNCH, departure=DEPART, hours_from_departure=1.0, km=90.0,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    assert issues == ()


def test_impossible_speed_lunch_flagged_as_error():
    # The motivating case: depart 12:00, lunch at 13:00, 350 km away.
    # Implied 350 km/h. Must surface as an error.
    meal = _meal(
        slot=MealSlot.LUNCH, departure=DEPART, hours_from_departure=1.0, km=350.0,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=DEPART + timedelta(hours=8),
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    assert len(issues) == 1
    assert issues[0].code == "meal.impossible_speed"
    assert issues[0].severity is Severity.ERROR
    assert "350" in issues[0].message


def test_suspicious_speed_flagged_as_warning():
    # 130 km after 1h: 130 km/h — plausible on Autobahn but suspicious
    # as a sustained *average* including any city exit.
    meal = _meal(
        slot=MealSlot.LUNCH, departure=DEPART, hours_from_departure=1.0, km=130.0,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=DEPART + timedelta(hours=6),
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    assert len(issues) == 1
    assert issues[0].code == "meal.suspicious_speed"
    assert issues[0].severity is Severity.WARNING


def test_meal_after_arrival_flagged():
    meal = _meal(
        slot=MealSlot.DINNER, departure=DEPART, hours_from_departure=6.0, km=600.0,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    assert any(i.code == "meal.after_arrival" for i in issues)


def test_meal_before_departure_flagged():
    # `at` before `departure_at` — should never happen but be defensive.
    meal = MealStop(
        slot=MealSlot.BREAKFAST,
        at=DEPART - timedelta(minutes=30),
        rest_stop=_rest(km=10.0, hours=0.1),
        restaurant=None,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    assert any(i.code == "meal.before_departure" for i in issues)


def test_meal_too_close_to_arrival_is_warning():
    # Lunch 10 min before arrival — pointless as a mid-trip stop.
    arrival = DEPART + timedelta(hours=2)
    meal = _meal(
        slot=MealSlot.LUNCH, departure=DEPART,
        hours_from_departure=1.85, km=180.0,   # ~97 km/h — plausible
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=arrival,
        optimizations=Optimizations(meal_stops=(meal,), sleep_stop=None),
    )
    codes = [i.code for i in issues]
    assert "meal.too_close_to_arrival" in codes


def test_no_optimizations_no_issues():
    assert check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL, optimizations=None,
    ) == ()


def test_errors_sort_before_warnings():
    # One impossible-speed error + one too-close-to-arrival warning.
    early = _meal(
        slot=MealSlot.LUNCH, departure=DEPART, hours_from_departure=0.5, km=300.0,
    )
    arrival = DEPART + timedelta(hours=4)
    late = _meal(
        slot=MealSlot.DINNER, departure=DEPART,
        hours_from_departure=3.9, km=380.0,   # ~97 km/h, plausible
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=arrival,
        optimizations=Optimizations(meal_stops=(early, late), sleep_stop=None),
    )
    severities = [i.severity for i in issues]
    assert severities[0] is Severity.ERROR
    assert Severity.WARNING in severities
    assert severities.index(Severity.ERROR) < severities.index(Severity.WARNING)


def _route(km: float) -> object:
    from datetime import timedelta as _td

    from app.domain import Route
    origin = Coordinate(lat=40.42, lon=-3.70)
    dest = Coordinate(lat=48.85, lon=2.35)
    return Route(
        origin=origin, destination=dest,
        distance_km=km,
        free_flow_duration=_td(hours=km / 100.0),
        polyline="", toll_cost_eur=0.0,
        countries_crossed=(),
    )


def _fuel_cost(*, range_ok: bool, ev: bool = False, notes: tuple[str, ...] = ()):
    from app.domain import FuelType
    from app.services.fuel_cost import FuelCostEstimate
    return FuelCostEstimate(
        total_cost_eur=0.0, average_unit_price_eur=1.0,
        fuel_type=FuelType.ELECTRIC if ev else FuelType.PETROL,
        fuel_units=0.0, unit_label="kWh" if ev else "L",
        range_ok=range_ok, notes=notes,
    )


def test_ev_out_of_range_flagged_as_error():
    cost = _fuel_cost(
        range_ok=False, ev=True,
        notes=("Beyond your single-charge range — plan 2 charging stop(s).",),
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=None, route=_route(1200), fuel_cost=cost,
    )
    assert any(
        i.code == "fuel.range_exceeded" and i.severity is Severity.ERROR
        for i in issues
    )


def test_long_combustion_trip_without_stations_warns():
    cost = _fuel_cost(range_ok=True, ev=False)
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=None, route=_route(600), fuel_cost=cost, fuel_prices=(),
    )
    assert any(
        i.code == "fuel.no_stations_visible" and i.severity is Severity.WARNING
        for i in issues
    )


def test_short_trip_without_stations_does_not_warn():
    cost = _fuel_cost(range_ok=True, ev=False)
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=None, route=_route(200), fuel_cost=cost, fuel_prices=(),
    )
    assert not any(i.code == "fuel.no_stations_visible" for i in issues)


def test_sleep_impossible_speed_flagged_as_error():
    from app.services.trip_optimizations import SleepStop
    sleep = SleepStop(
        at=DEPART + timedelta(hours=2),
        rest_stop=_rest(km=600.0, hours=2.0),
        hotel=None,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=DEPART + timedelta(hours=10),
        optimizations=Optimizations(meal_stops=(), sleep_stop=sleep),
    )
    assert any(
        i.code == "sleep.impossible_speed" and i.severity is Severity.ERROR
        for i in issues
    )


def test_sleep_before_departure_flagged():
    from app.services.trip_optimizations import SleepStop
    sleep = SleepStop(
        at=DEPART - timedelta(minutes=15),
        rest_stop=_rest(km=10.0, hours=0.1),
        hotel=None,
    )
    issues = check_trip(
        departure_at=DEPART, arrival_at=ARRIVAL,
        optimizations=Optimizations(meal_stops=(), sleep_stop=sleep),
    )
    assert any(i.code == "sleep.before_departure" for i in issues)


if __name__ == "__main__":  # pragma: no cover
    pytest.main([__file__, "-v"])

"""Per-day boundary regressions.

Motivated by the "473 km day finishes driving at 13:45" tester report:
a driving-only end time computed as `start + hours * (1 + pause_ratio)`
undercounts the meal breaks that genuinely interrupt driving, so the
day header disagrees with the meal cards rendered below it.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.domain import (
    Coordinate,
    MealPreferences,
    MealSlot,
    RestStop,
    TravelPace,
    TripProfile,
)
from app.services.day_plan import compute as compute_day_plan
from app.services.trip_optimizations import (
    MealStop,
    Optimizations,
)


DEPART = datetime(2026, 8, 24, 8, 0, tzinfo=timezone.utc)


def _rest(km: float, hours: float) -> RestStop:
    return RestStop(
        coordinate=Coordinate(lat=45.0, lon=2.0),
        distance_from_origin_km=km,
        cumulative_driving_hours=hours,
        recommended_break_minutes=15,
    )


def _meal(slot: MealSlot, hour: int, km: float, cum_hours: float) -> MealStop:
    return MealStop(
        slot=slot,
        at=DEPART.replace(hour=hour, minute=0),
        rest_stop=_rest(km=km, hours=cum_hours),
        restaurant=None,
    )


def test_pause_and_meal_overhead_extend_day_end():
    """A 6 h driving day at STEADY pace with lunch scheduled at 13:00
    should end at ~15:36, not 13:45 — the raw 08:00 + 6 h + 10 %
    pause math gives 14:36, plus 1 h for the lunch break the driver
    actually takes = 15:36. Regression on the tester's
    "473 km day finishes at 13:45 is impossible" report.
    """
    profile = TripProfile(
        meals=MealPreferences(),
        travel_pace=TravelPace.STEADY,
        daily_driving_cap_hours=6,
    )
    # 12 h total driving → forces multi-day.
    # 6 h day 1 (cap) with lunch at km 273 (mid-drive).
    lunch = _meal(MealSlot.LUNCH, hour=13, km=273.0, cum_hours=5.0)
    opts = Optimizations(meal_stops=(lunch,), sleep_stop=None)
    plan = compute_day_plan(
        departure_at=DEPART,
        trip_duration_hours=12.0,
        profile=profile,
        optimizations=opts,
        rest_stops=(),
        route_distance_km=1080.0,  # 12 h @ 90 km/h
    )
    assert plan is not None
    day1 = plan.days[0]
    # 6 h driving * 1.10 pause = 6.6 h → 14:36. + 1 h lunch = 15:36.
    expected = DEPART + timedelta(hours=6.6 + 1.0)
    assert abs((day1.end_at - expected).total_seconds()) < 60, (
        f"day1.end_at={day1.end_at} vs expected {expected}"
    )
    # And the raw 13:45 answer (start + 5.75h) must NOT be what we get.
    bad = DEPART + timedelta(hours=5.75)
    assert day1.end_at > bad + timedelta(minutes=30)


def test_end_at_unchanged_when_no_meals_scheduled():
    """No meals fall in the day → only pause overhead applies, so the
    end_at matches the pre-fix behaviour for this case.
    """
    profile = TripProfile(
        meals=MealPreferences(),
        travel_pace=TravelPace.STEADY,
        daily_driving_cap_hours=6,
    )
    opts = Optimizations(meal_stops=(), sleep_stop=None)
    plan = compute_day_plan(
        departure_at=DEPART,
        trip_duration_hours=12.0,
        profile=profile,
        optimizations=opts,
        rest_stops=(),
        route_distance_km=1080.0,
    )
    assert plan is not None
    day1 = plan.days[0]
    # 6 h * 1.10 pause = 6.6 h → 14:36
    expected = DEPART + timedelta(hours=6.6)
    assert abs((day1.end_at - expected).total_seconds()) < 60


def test_savour_pace_and_lunch_pushes_day_further():
    """SAVOUR pace has a 17 % pause ratio → 6 h drive = 7.02 h wall +
    1 h lunch = ~8.02 h. 08:00 → ~16:01. Sanity check that pace
    scales the fix.
    """
    profile = TripProfile(
        meals=MealPreferences(),
        travel_pace=TravelPace.SAVOUR,
        daily_driving_cap_hours=6,
    )
    lunch = _meal(MealSlot.LUNCH, hour=13, km=273.0, cum_hours=5.0)
    opts = Optimizations(meal_stops=(lunch,), sleep_stop=None)
    plan = compute_day_plan(
        departure_at=DEPART,
        trip_duration_hours=12.0,
        profile=profile,
        optimizations=opts,
        rest_stops=(),
        route_distance_km=1080.0,
    )
    assert plan is not None
    day1 = plan.days[0]
    expected = DEPART + timedelta(hours=6 * 1.17 + 1.0)
    assert abs((day1.end_at - expected).total_seconds()) < 120


def test_meal_after_driving_does_not_extend_day():
    """Dinner at 20:00 scheduled after the day's drive ends at 14:00
    is a post-drive meal (eaten at the hotel town). It must NOT push
    the day's end past 14:00 + pause overhead.
    """
    profile = TripProfile(
        meals=MealPreferences(),
        travel_pace=TravelPace.STEADY,
        daily_driving_cap_hours=5,
    )
    # Dinner at 20:00 well after the 5 h * 1.10 = 5.5 h drive end (13:30).
    dinner = _meal(MealSlot.DINNER, hour=20, km=430.0, cum_hours=5.0)
    opts = Optimizations(meal_stops=(dinner,), sleep_stop=None)
    plan = compute_day_plan(
        departure_at=DEPART,
        trip_duration_hours=10.0,
        profile=profile,
        optimizations=opts,
        rest_stops=(),
        route_distance_km=900.0,
    )
    assert plan is not None
    day1 = plan.days[0]
    expected = DEPART + timedelta(hours=5 * 1.10)
    assert abs((day1.end_at - expected).total_seconds()) < 60

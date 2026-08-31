"""Trip optimizations: bind rest stops to meal slots and sleep slots.

The idea is to *reduce* what the user has to think about, not add to it.
The result screen already surfaces rest stops, hotels, and restaurants
as long lists. Here we pick the ONE lunch stop, ONE dinner stop, and
ONE sleep stop that make sense for this specific trip and put them in
a distinct "Optimizations" section — a driver looks at 3 items instead
of scrolling 30.

The service is pure: given departure time, rest stops, restaurants, and
hotels, it deterministically produces up to 3 recommendations plus a
fuel-cost estimate produced by [`fuel_cost`](fuel_cost.py). No LLM.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.domain import (
    Hotel,
    MealPreferences,
    MealSlot,
    Restaurant,
    RestStop,
    TravelPace,
    TripProfile,
)


# Fraction of driving time that gets spent NOT-driving on safety
# pauses (15 min ADAC-style breaks). Meals are budgeted separately;
# this only covers the short "stretch your legs" stops.
#
# Testers pointed out that a 5:30 h drive shows up as 5:30 h wall-
# clock in the UI, but in "tranquilo" (SAVOUR) mode you actually
# stop enough that 5:30 h of driving is closer to 6:15 h door-to-
# door. Bake it in so arrival times, meal `at`, and sleep-window
# math all reflect the same reality.
_PAUSE_RATIO_BY_PACE = {
    TravelPace.PUSH: 0.04,     # ~5 min / 2 h drive
    TravelPace.STEADY: 0.10,   # ~12 min / 2 h drive (near EU legal min)
    TravelPace.SAVOUR: 0.17,   # ~20 min / 2 h drive
}


def _pause_ratio(profile: TripProfile) -> float:
    return _PAUSE_RATIO_BY_PACE.get(
        getattr(profile, "travel_pace", TravelPace.STEADY), 0.10,
    )


def _wall_hours(driving_hours: float, pause_ratio: float) -> float:
    """Convert pure driving hours to wall-clock hours by folding in
    the pace-dependent safety-pause overhead. Meal breaks are
    accounted for separately at the meal-stop level.
    """
    return driving_hours * (1.0 + pause_ratio)


@dataclass(frozen=True, slots=True)
class MealStop:
    slot: MealSlot
    at: datetime
    rest_stop: RestStop
    restaurant: Restaurant | None


@dataclass(frozen=True, slots=True)
class SleepStop:
    at: datetime
    rest_stop: RestStop
    hotel: Hotel | None


@dataclass(frozen=True, slots=True)
class Optimizations:
    meal_stops: tuple[MealStop, ...]
    # Kept as a single field for backward compatibility with the
    # `/plan` schema — this is ALWAYS the first day's sleep.
    sleep_stop: SleepStop | None
    # Every overnight the planner scheduled, first-day included.
    # For a 1-day trip: empty. For a 3-day trip: two entries
    # (end of day 1 + end of day 2). Downstream code hits this
    # list to densify hotels around every overnight so multi-day
    # trips don't lose their middle-day hotel recommendations.
    sleep_stops: tuple[SleepStop, ...] = ()


def _slot_hour(prefs: MealPreferences, slot: MealSlot) -> int:
    return {
        MealSlot.BREAKFAST: prefs.breakfast_hour,
        MealSlot.LUNCH: prefs.lunch_hour,
        MealSlot.DINNER: prefs.dinner_hour,
    }[slot]


def _slot_minute(prefs: MealPreferences, slot: MealSlot) -> int:
    return {
        MealSlot.BREAKFAST: prefs.breakfast_minute,
        MealSlot.LUNCH: prefs.lunch_minute,
        MealSlot.DINNER: prefs.dinner_minute,
    }[slot]


def _nearest_rest_stop(
    stops: tuple[RestStop, ...],
    departure: datetime,
    target: datetime,
    *,
    tolerance: timedelta = timedelta(minutes=90),
    pause_ratio: float = 0.0,
    driving_offset: float = 0.0,
) -> RestStop | None:
    """Return the rest stop whose *wall-clock* arrival at the pace's
    effective speed lands closest to `target` (an absolute clock
    time). `pause_ratio` inflates driving hours by the safety-pause
    overhead so lunch-at-14 on a "tranquilo" plan lines up with
    when the driver will actually reach the stop, not with the
    unbroken driving time.

    `driving_offset` (in hours) is the cumulative driving already
    done before `departure` — critical for Day 2+ of a multi-day
    trip, where `stops` still measure cumulative-from-origin but
    the day's clock starts at wake, not origin. Stops with
    `cumulative < driving_offset` are skipped (already behind us).

    Returns None when no candidate falls within `tolerance`.
    """
    if not stops:
        return None
    best: RestStop | None = None
    best_delta: timedelta | None = None
    for s in stops:
        remaining = s.cumulative_driving_hours - driving_offset
        if remaining < 0:
            continue
        arrival = departure + timedelta(
            hours=_wall_hours(remaining, pause_ratio),
        )
        delta = arrival - target
        abs_delta = delta if delta >= timedelta(0) else -delta
        if abs_delta > tolerance:
            continue
        if best_delta is None or abs_delta < best_delta:
            best = s
            best_delta = abs_delta
    return best


_MAX_RESTAURANT_MATCH_KM = 25.0
_MAX_HOTEL_MATCH_KM = 40.0


def _closest_restaurant(
    restaurants: tuple[Restaurant, ...],
    stop: RestStop,
    *,
    exclude_names: frozenset[str] = frozenset(),
) -> Restaurant | None:
    """Pick the restaurant with the smallest distance to the stop
    location — BUT only when that distance is within a plausible
    detour radius. `restaurants` is pre-filtered by profile + detour
    cap + open meal slot, yet the corridor POI search sometimes
    only surfaces hits far from the actual rest stop (all Zurich
    cafés for a stop at km 365, per tester report). Without the
    cap `min()` returns the "least far" candidate — a café at the
    origin — which is nonsensical for a lunch stop 5 hours down
    the road. Returning None here lets the meal render without a
    named venue instead of a wrong one.
    """
    if not restaurants:
        return None
    from app.providers.routing import _haversine_km

    # Rank all candidates by distance-to-stop and pick the closest
    # that isn't already used elsewhere in the trip. Testers
    # reported "misma cadena 3 veces" when lunch + dinner + next-
    # day breakfast all snapped to the same sleep spot: without a
    # dedup the top-3 were identical. `exclude_names` lets the
    # caller thread the already-picked names through.
    scored = sorted(
        restaurants,
        key=lambda r: _haversine_km(r.coordinate, stop.coordinate),
    )
    for r in scored:
        if r.name in exclude_names:
            continue
        if _haversine_km(r.coordinate, stop.coordinate) > _MAX_RESTAURANT_MATCH_KM:
            return None
        return r
    return None


def _closest_hotel(
    hotels: tuple[Hotel, ...],
    stop: RestStop,
) -> Hotel | None:
    if not hotels:
        return None
    from app.providers.routing import _haversine_km

    best = min(
        hotels,
        key=lambda h: _haversine_km(h.coordinate, stop.coordinate),
    )
    if _haversine_km(best.coordinate, stop.coordinate) > _MAX_HOTEL_MATCH_KM:
        return None
    return best


def compute(
    *,
    departure_at: datetime,
    trip_duration_hours: float,
    rest_stops: tuple[RestStop, ...],
    restaurants_by_slot: dict[MealSlot, tuple[Restaurant, ...]],
    hotels: tuple[Hotel, ...],
    profile: TripProfile,
    include_meal_stops: bool = True,
) -> Optimizations:
    """Bind rest stops to meals (and, when the drive rolls past bedtime,
    to a sleep hotel).

    Behaviour:
    - For each meal slot whose target hour falls between the departure
      and the arrival, find the nearest rest stop and the closest matching
      restaurant. Skip the slot if no rest stop is in tolerance (the
      driver would need to force an unnatural break).
    - If the trip is long enough to cross ~22:00, pick a sleep stop the
      driver naturally reaches around dinner and the closest matching
      hotel. Prevents 12h day/night drives from surprising the user.
    """
    pause_ratio = _pause_ratio(profile)
    prefs = profile.meals
    cap_hours = float(getattr(profile, "daily_driving_cap_hours", 8) or 8)
    wake_hour = getattr(profile, "wake_hour", 8)

    # Multi-day loop: iterate day-by-day. Each day starts either at
    # the trip departure (day 1) or at the previous day's wake-up
    # hour, drives up to `cap_hours`, and — if there's driving left
    # over — closes with a sleep stop. Meals for that day are
    # anchored to THAT day's start moment (breakfast_hour /
    # lunch_hour / dinner_hour applied to the current wall clock).
    #
    # Only the FIRST day's sleep is returned via `sleep_stop`
    # (schema hasn't grown a `sleep_stops` list yet); subsequent-day
    # sleeps are still driven by `day_plan` which uses cap +
    # avg_kmh. Meal_stops covers ALL days so the day view has
    # comida + cena on Day 2, Day 3, etc. instead of only Day 1.
    meal_stops: list[MealStop] = []
    first_sleep: SleepStop | None = None
    all_sleeps: list[SleepStop] = []
    day_start = departure_at
    driving_offset = 0.0  # cumulative driving hours before day_start
    remaining_driving = trip_duration_hours
    day_index = 0

    while remaining_driving > 0.01:
        day_index += 1
        driving_this_day = min(cap_hours, remaining_driving)
        # Wall-clock end of driving for this day (before any post-
        # driving meal/sleep). Includes pause overhead.
        day_drive_end = day_start + timedelta(
            hours=_wall_hours(driving_this_day, pause_ratio),
        )
        is_last_day = remaining_driving - driving_this_day <= 0.01

        # Sleep at end of this day unless it's the last day.
        day_sleep: SleepStop | None = None
        if not is_last_day:
            day_arrival = day_start + timedelta(
                hours=_wall_hours(remaining_driving, pause_ratio),
            )
            day_sleep = _select_sleep_stop(
                departure_at=day_start,
                arrival=day_arrival,
                rest_stops=rest_stops,
                hotels=hotels,
                profile=profile,
                pause_ratio=pause_ratio,
                prefs=prefs,
                driving_offset=driving_offset,
                cap_hours=cap_hours,
            )
            if day_sleep is not None:
                all_sleeps.append(day_sleep)
            if day_index == 1:
                first_sleep = day_sleep

        day_end = day_sleep.at if day_sleep is not None else day_drive_end
        # Gate the meal-stop expansion on the caller's opt-in.
        # When restaurants weren't requested (`include_meal_stops=
        # False`) we skip this entirely — the user asked NOT to
        # see meal recommendations and would be confused by a
        # "próxima parada: comida" hero appearing anyway.
        if include_meal_stops:
            _extend_meals_for_day(
                out=meal_stops,
                day_start=day_start,
                day_end=day_end,
                day_sleep=day_sleep,
                trip_duration_hours=trip_duration_hours,
                rest_stops=rest_stops,
                restaurants_by_slot=restaurants_by_slot,
                profile=profile,
                prefs=prefs,
                pause_ratio=pause_ratio,
                driving_offset=driving_offset,
            )

        remaining_driving -= driving_this_day
        driving_offset += driving_this_day
        if remaining_driving <= 0.01:
            break
        # Wake up next day at `wake_hour` (respect day_sleep.at as
        # floor — you can't wake before you slept). Fall back to
        # day_drive_end when no sleep was selected (rare: cap
        # exhausted with no valid rest stop).
        base = day_sleep.at if day_sleep is not None else day_drive_end
        day_start = _next_wake(base, wake_hour)

    return Optimizations(
        meal_stops=tuple(meal_stops),
        sleep_stop=first_sleep,
        sleep_stops=tuple(all_sleeps),
    )


def _next_wake(reference: datetime, wake_hour: int) -> datetime:
    """Next occurrence of `wake_hour:00` strictly after `reference`."""
    candidate = reference.replace(
        hour=wake_hour, minute=0, second=0, microsecond=0,
    )
    if candidate <= reference:
        candidate += timedelta(days=1)
    return candidate


def _extend_meals_for_day(
    *,
    out: list[MealStop],
    day_start: datetime,
    day_end: datetime,
    day_sleep: SleepStop | None,
    trip_duration_hours: float,
    rest_stops: tuple[RestStop, ...],
    restaurants_by_slot: dict[MealSlot, tuple[Restaurant, ...]],
    profile: TripProfile,
    prefs: MealPreferences,
    pause_ratio: float,
    driving_offset: float = 0.0,
) -> None:
    """Append meal stops for a single day into `out`. Same rules as
    the previous single-day loop, but scoped to `[day_start,
    day_end)` — subsequent days re-enter this helper with their own
    wake moment.
    """
    bedtime = _next_at_hour(
        day_start, getattr(profile, "bedtime_hour", 22),
    )
    # Track names already picked so back-to-back meals at the
    # same hotel spot don't all match the same closest restaurant.
    # Populated from `out` (which carries previous days' picks too)
    # so a chain like Novotel at 200 km doesn't dominate every
    # meal for a driver hitting Novotels along the corridor.
    used_names: set[str] = {
        m.restaurant.name for m in out if m.restaurant is not None
    }
    for slot in (MealSlot.BREAKFAST, MealSlot.LUNCH, MealSlot.DINNER):
        target = _next_at_hour_minute(
            day_start,
            _slot_hour(prefs, slot),
            _slot_minute(prefs, slot),
        )
        if target < day_start:
            continue
        # After the day's driving ends but still before bedtime →
        # snap to the sleep rest_stop (meal in the hotel town).
        if target > day_end:
            # Snap post-driving meals to the sleep rest_stop —
            # they're eaten in the hotel town. Bedtime is the
            # natural cutoff; the earlier `day_end + 6h` clamp
            # was too tight for SAVOUR/cap=4 plans where driving
            # ends at 12:41 and dinner target is 7 h later.
            if day_sleep is not None and target <= bedtime:
                restaurant = _closest_restaurant(
                    restaurants_by_slot.get(slot, ()),
                    day_sleep.rest_stop,
                    exclude_names=frozenset(used_names),
                )
                if restaurant is not None:
                    used_names.add(restaurant.name)
                out.append(
                    MealStop(
                        slot=slot,
                        at=target,
                        rest_stop=day_sleep.rest_stop,
                        restaurant=restaurant,
                    )
                )
            continue
        rest = _nearest_rest_stop(
            rest_stops, day_start, target,
            pause_ratio=pause_ratio,
            driving_offset=driving_offset,
        )
        if rest is None:
            continue
        # Origin-proximity guard only matters on day 1 (day 2+
        # never starts at origin). Applied uniformly here is fine
        # because Day 2+ rest_stops are all past 30 km anyway.
        if rest.distance_from_origin_km < 30.0:
            continue
        # Skip meal-stops within 1 h wall-clock of the trip's global
        # arrival — a driver about to arrive is better off eating
        # on arrival than detouring for a roadside stop.
        if _wall_hours(
            rest.cumulative_driving_hours + 1.0, pause_ratio,
        ) >= _wall_hours(trip_duration_hours, pause_ratio):
            continue
        restaurant = _closest_restaurant(
            restaurants_by_slot.get(slot, ()), rest,
            exclude_names=frozenset(used_names),
        )
        if restaurant is not None:
            used_names.add(restaurant.name)
        meal_at = day_start + timedelta(
            hours=_wall_hours(
                rest.cumulative_driving_hours - driving_offset,
                pause_ratio,
            ),
        )
        if meal_at > day_end:
            continue
        out.append(
            MealStop(
                slot=slot,
                at=meal_at,
                rest_stop=rest,
                restaurant=restaurant,
            )
        )


def _select_sleep_stop(
    *,
    departure_at: datetime,
    arrival: datetime,
    rest_stops: tuple[RestStop, ...],
    hotels: tuple[Hotel, ...],
    profile: TripProfile,
    pause_ratio: float,
    prefs: MealPreferences,
    driving_offset: float = 0.0,
    cap_hours: float | None = None,
) -> SleepStop | None:
    """Pick the sleep stop the driver naturally reaches around
    bedtime, capped at `daily_driving_cap_hours`. See `compute`
    for the wider comments on why the target must be driving-hour
    based, why we widen tolerance to ±3 h here, and why the
    post-hoc [17:00, 06:00] plausibility gate exists.
    """
    sleep_target_hour = getattr(profile, "bedtime_hour", 22)
    late_at = _next_at_hour(departure_at, sleep_target_hour)
    # Skip sleep ONLY when both:
    # 1) the driver can finish today under the daily driving cap
    #    (no cap-forced early stop), AND
    # 2) the trip's continuous arrival is before bedtime.
    # Missing this second-day case caused Day 3+ of a SAVOUR trip
    # to drop the sleep_stop — the remaining trip fit in the day
    # (arrival 18:32 < bedtime 22:00) but the 4 h cap would fire
    # at 12:41, still needing an overnight.
    _effective_cap = cap_hours if cap_hours is not None else float(
        getattr(profile, "daily_driving_cap_hours", 8) or 8,
    )
    _cap_wall = timedelta(
        hours=_wall_hours(_effective_cap, pause_ratio),
    )
    if arrival <= departure_at + _cap_wall and late_at >= arrival:
        return None
    wall_hours_to_bedtime = (
        late_at - departure_at
    ).total_seconds() / 3600.0
    if cap_hours is None:
        cap_hours = float(
            getattr(profile, "daily_driving_cap_hours", 8) or 8,
        )
    # ~1 h per meal slot: sit-down time + parking + service in
    # European roadside stops rarely fits in 30 min once you
    # factor in kids/pets.
    meal_overhead_hours = 1.0 * sum(
        1
        for slot in (
            MealSlot.BREAKFAST, MealSlot.LUNCH, MealSlot.DINNER,
        )
        if departure_at
        <= _next_at_hour_minute(
            departure_at,
            _slot_hour(prefs, slot),
            _slot_minute(prefs, slot),
        )
        < late_at
    )
    available_wall = max(wall_hours_to_bedtime - meal_overhead_hours, 0.0)
    effective_driving_hours = min(
        available_wall / (1.0 + pause_ratio),
        cap_hours,
    )
    if effective_driving_hours <= 0:
        return None
    driving_target = departure_at + timedelta(
        hours=_wall_hours(effective_driving_hours, pause_ratio),
    )
    rest = _nearest_rest_stop(
        rest_stops, departure_at, driving_target,
        tolerance=timedelta(hours=3),
        pause_ratio=pause_ratio,
        driving_offset=driving_offset,
    )
    if rest is None:
        return None
    arrival_at_stop = departure_at + timedelta(
        hours=_wall_hours(
            rest.cumulative_driving_hours - driving_offset, pause_ratio,
        ),
    )
    # Night-window plausibility gate DROPPED (2026-08-25). It kept
    # rejecting legitimate SAVOUR/cap=4 stops that finish driving
    # around 12:00-13:00 — the user opted into a small daily
    # driving budget precisely so the day ends early and the rest
    # is leisure. Rejecting those left Day 2/3 without cena or
    # hotel. The frontend copy is "Terminas de conducir hacia las
    # X" which reads correctly for a 12:41 wall-clock stop; and
    # the origin-proximity + wake-time filters upstream already
    # exclude the km-0 bugs the gate was originally protecting
    # against.
    hotel = _closest_hotel(hotels, rest)
    return SleepStop(
        at=arrival_at_stop,
        rest_stop=rest,
        hotel=hotel,
    )


def _next_at_hour(base: datetime, hour: int) -> datetime:
    """First moment at :00 of `hour` at or after `base`."""
    return _next_at_hour_minute(base, hour, 0)


def _next_at_hour_minute(base: datetime, hour: int, minute: int) -> datetime:
    """First moment at `hour:minute` at or after `base`. Wraps to
    tomorrow if the time has already passed today.
    """
    candidate = base.replace(
        hour=hour, minute=minute, second=0, microsecond=0,
    )
    if candidate < base:
        candidate += timedelta(days=1)
    return candidate

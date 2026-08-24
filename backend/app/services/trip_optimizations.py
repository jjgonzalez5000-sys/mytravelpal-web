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
    TripProfile,
)


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
    sleep_stop: SleepStop | None


def _slot_hour(prefs: MealPreferences, slot: MealSlot) -> int:
    return {
        MealSlot.BREAKFAST: prefs.breakfast_hour,
        MealSlot.LUNCH: prefs.lunch_hour,
        MealSlot.DINNER: prefs.dinner_hour,
    }[slot]


def _nearest_rest_stop(
    stops: tuple[RestStop, ...],
    departure: datetime,
    target: datetime,
) -> RestStop | None:
    """Return the rest stop whose cumulative-driving-time landing lands
    closest to `target` (an absolute clock time). Returns None if there
    are no candidates within ±90 min of the target — no point suggesting
    lunch at 16:00 if the driver won't have a natural break window.
    """
    if not stops:
        return None
    tolerance = timedelta(minutes=90)
    best: RestStop | None = None
    best_delta: timedelta | None = None
    for s in stops:
        arrival = departure + timedelta(hours=s.cumulative_driving_hours)
        delta = arrival - target
        abs_delta = delta if delta >= timedelta(0) else -delta
        if abs_delta > tolerance:
            continue
        if best_delta is None or abs_delta < best_delta:
            best = s
            best_delta = abs_delta
    return best


def _closest_restaurant(
    restaurants: tuple[Restaurant, ...],
    stop: RestStop,
) -> Restaurant | None:
    """Pick the restaurant with the smallest distance to the stop
    location. `restaurants` should already be pre-filtered (profile +
    detour cap + open meal slot).
    """
    if not restaurants:
        return None
    from app.providers.routing import _haversine_km

    return min(
        restaurants,
        key=lambda r: _haversine_km(r.coordinate, stop.coordinate),
    )


def _closest_hotel(
    hotels: tuple[Hotel, ...],
    stop: RestStop,
) -> Hotel | None:
    if not hotels:
        return None
    from app.providers.routing import _haversine_km

    return min(
        hotels,
        key=lambda h: _haversine_km(h.coordinate, stop.coordinate),
    )


def compute(
    *,
    departure_at: datetime,
    trip_duration_hours: float,
    rest_stops: tuple[RestStop, ...],
    restaurants_by_slot: dict[MealSlot, tuple[Restaurant, ...]],
    hotels: tuple[Hotel, ...],
    profile: TripProfile,
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
    arrival = departure_at + timedelta(hours=trip_duration_hours)
    prefs = profile.meals
    meal_stops: list[MealStop] = []

    for slot in (MealSlot.BREAKFAST, MealSlot.LUNCH, MealSlot.DINNER):
        target = _next_at_hour(departure_at, _slot_hour(prefs, slot))
        if target > arrival or target < departure_at:
            continue
        rest = _nearest_rest_stop(rest_stops, departure_at, target)
        if rest is None:
            continue
        restaurant = _closest_restaurant(
            restaurants_by_slot.get(slot, ()), rest,
        )
        meal_stops.append(
            MealStop(
                slot=slot,
                at=departure_at + timedelta(hours=rest.cumulative_driving_hours),
                rest_stop=rest,
                restaurant=restaurant,
            )
        )

    sleep_stop: SleepStop | None = None
    # If the driver would still be on the road at 22:00 local, they're
    # probably going to want to sleep somewhere.
    late_at = _next_at_hour(departure_at, 22)
    if late_at < arrival:
        rest = _nearest_rest_stop(rest_stops, departure_at, late_at)
        if rest is not None:
            hotel = _closest_hotel(hotels, rest)
            sleep_stop = SleepStop(
                at=departure_at + timedelta(hours=rest.cumulative_driving_hours),
                rest_stop=rest,
                hotel=hotel,
            )

    return Optimizations(
        meal_stops=tuple(meal_stops),
        sleep_stop=sleep_stop,
    )


def _next_at_hour(base: datetime, hour: int) -> datetime:
    """First moment at :00 of `hour` at or after `base`."""
    candidate = base.replace(
        hour=hour, minute=0, second=0, microsecond=0,
    )
    if candidate < base:
        candidate += timedelta(days=1)
    return candidate

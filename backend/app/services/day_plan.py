"""Split a long trip into a per-day plan.

Long drives don't map to a single-column UI: a Madrid→Amsterdam trip
crosses 4 countries and 22 hours of driving — no driver eats lunch at
km 100 AND km 1400 on the same day. This service groups everything
(meal stops, sleep stops, hotels, restaurants) into per-day buckets so
the mobile app can render tabs "Day 1 · Day 2 · Day 3".

Trigger condition — we emit multi-day when either:
- Total driving time exceeds `dailyDrivingCapHours` from the profile, OR
- The arrival's local hour exceeds `bedtimeHour` (arriving in the
  middle of the night is a sleep-somewhere signal).

Single-day trips return `None` and the client renders the flat view.

The split is heuristic: we assume the driver stops for the night around
`bedtimeHour` and resumes at `wakeHour`. Real overnight stops from
`Optimizations.sleep_stop` seed day boundaries when present; otherwise
we synthesise them.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, time, timedelta

from app.domain import (
    Coordinate,
    RestStop,
    Route,
    TripProfile,
)
from app.services.trip_optimizations import MealStop, Optimizations


@dataclass(frozen=True, slots=True)
class DayPlan:
    day_index: int              # 1-based
    start_at: datetime
    end_at: datetime
    from_km: float
    to_km: float
    meal_stops: tuple[MealStop, ...]
    rest_stops: tuple[RestStop, ...]
    # Sleep-stop *ending* this day (None on the final day).
    sleep_at: datetime | None
    # Approximate coordinate where the driver would spend the night.
    # Used by the client to surface "hotels near your overnight stop"
    # cards. Derived from `Optimizations.sleep_stop.rest_stop` when
    # one lands in this day; otherwise interpolated from the route
    # geometry at the day's `to_km`.
    sleep_coord: Coordinate | None = None


@dataclass(frozen=True, slots=True)
class MultiDayPlan:
    days: tuple[DayPlan, ...]
    total_days: int


def compute(
    *,
    departure_at: datetime,
    trip_duration_hours: float,
    profile: TripProfile,
    optimizations: Optimizations | None,
    rest_stops: tuple[RestStop, ...],
    route_distance_km: float,
    route: Route | None = None,
) -> MultiDayPlan | None:
    """Return `None` for single-day trips. For multi-day trips returns
    the per-day breakdown.
    """
    arrival_at = departure_at + timedelta(hours=trip_duration_hours)
    cap_hours = float(profile.daily_driving_cap_hours)
    arrival_local_hour = arrival_at.hour
    is_multiday = (
        trip_duration_hours > cap_hours
        or arrival_local_hour >= profile.bedtime_hour
    )
    if not is_multiday:
        return None

    meals = list(optimizations.meal_stops) if optimizations else []
    # Sort by cumulative km so we can slice by day.
    meals.sort(key=lambda m: m.rest_stop.distance_from_origin_km)
    rests = sorted(rest_stops, key=lambda s: s.distance_from_origin_km)

    # Build day boundaries as (start_at, end_at, start_km, end_km).
    # Day 1 starts at departure. Each day drives up to `cap_hours`
    # then sleeps until wake_hour of the next day.
    boundaries: list[tuple[datetime, datetime, float, float]] = []
    current_start = departure_at
    current_start_km = 0.0
    # Effective km / h at the trip's average speed. Guard against
    # zero-hour trips (shouldn't happen, defensive).
    avg_kmh = (
        route_distance_km / trip_duration_hours
        if trip_duration_hours > 0
        else 90.0
    )
    remaining_hours = trip_duration_hours
    day_index = 0
    while remaining_hours > 0:
        day_index += 1
        driving_this_day = min(cap_hours, remaining_hours)
        day_end_driving_at = current_start + timedelta(hours=driving_this_day)
        end_km = current_start_km + driving_this_day * avg_kmh
        boundaries.append(
            (current_start, day_end_driving_at, current_start_km, end_km),
        )
        remaining_hours -= driving_this_day
        current_start_km = end_km
        if remaining_hours <= 0:
            break
        # Sleep until wake_hour of the next day.
        next_wake = _next_wake(day_end_driving_at, profile.wake_hour)
        current_start = next_wake

    days: list[DayPlan] = []
    total = len(boundaries)
    for idx, (start_at, end_at, from_km, to_km) in enumerate(boundaries):
        day_meals = tuple(
            m for m in meals
            if from_km <= m.rest_stop.distance_from_origin_km <= to_km
        )
        day_rests = tuple(
            r for r in rests
            if from_km <= r.distance_from_origin_km <= to_km
        )
        sleep_at = end_at if idx + 1 < total else None
        sleep_coord: Coordinate | None = None
        # If the domain sleep_stop lands in this day, prefer its time
        # AND coord — it targeted a real rest area.
        if (
            optimizations is not None
            and optimizations.sleep_stop is not None
            and sleep_at is not None
            and from_km <= optimizations.sleep_stop.rest_stop.distance_from_origin_km <= to_km
        ):
            sleep_at = optimizations.sleep_stop.at
            sleep_coord = optimizations.sleep_stop.rest_stop.coordinate
        elif sleep_at is not None and route is not None:
            # Otherwise interpolate a rough coord from the route
            # geometry at the day's ending km. Clients use this to
            # rank nearby hotels for the overnight-stop section.
            sleep_coord = _coord_at_km(route, to_km)
        days.append(
            DayPlan(
                day_index=idx + 1,
                start_at=start_at,
                end_at=end_at,
                from_km=round(from_km, 1),
                to_km=round(to_km, 1),
                meal_stops=day_meals,
                rest_stops=day_rests,
                sleep_at=sleep_at,
                sleep_coord=sleep_coord,
            )
        )
    return MultiDayPlan(days=tuple(days), total_days=total)


def _coord_at_km(route: Route, km: float) -> Coordinate | None:
    if not route.geometry or route.distance_km <= 0:
        return None
    fraction = max(0.0, min(1.0, km / route.distance_km))
    idx = int(fraction * (len(route.geometry) - 1))
    return route.geometry[idx]


def _next_wake(reference: datetime, wake_hour: int) -> datetime:
    """Next occurrence of `wake_hour:00` strictly after `reference`."""
    candidate = datetime.combine(
        reference.date(), time(hour=wake_hour), tzinfo=reference.tzinfo,
    )
    if candidate <= reference:
        candidate += timedelta(days=1)
    return candidate


# Note: hotels and restaurants intentionally stay in the flat
# response — they lack a native `distance_from_origin_km` (they're
# off-corridor discovered by POI search, not sequenced along the
# route). Meal stops and rest stops both carry `distance_from_origin_km`
# and are the ones bucketed above.

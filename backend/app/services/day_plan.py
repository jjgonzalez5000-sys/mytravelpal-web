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

import logging
from dataclasses import dataclass
from datetime import datetime, time, timedelta

from app.domain import (
    Coordinate,
    RestStop,
    Route,
    TripProfile,
    Waypoint,
)
_log = logging.getLogger(__name__)


from app.services.trip_optimizations import (
    MealStop,
    Optimizations,
    _pause_ratio,
    _wall_hours,
)


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
    # When this day sits at a waypoint the driver chose (dwell
    # arrival day OR follow-on stay-put days), `dwell_label`
    # carries the waypoint's display name so the mobile renders
    # "Día 2 · Mendrisio" instead of an opaque "km 267 → 267"
    # range.
    dwell_label: str | None = None
    # Human-readable city/place name at the start and end of this day.
    # Populated from reverse-geocoded origin/destination + dwell chain.
    from_name: str | None = None
    to_name: str | None = None
    waypoint_anchors: tuple["WaypointAnchor", ...] = ()

    @property
    def waypoint_labels(self) -> tuple[str, ...]:
        return tuple(a.label for a in self.waypoint_anchors)


@dataclass(frozen=True, slots=True)
class WaypointAnchor:
    label: str
    km: float
    lat: float
    lon: float


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
    waypoints: tuple[Waypoint, ...] = (),
    origin_label: str | None = None,
    destination_label: str | None = None,
    day_overrides: dict[int, dict[str, int | None]] | None = None,
) -> MultiDayPlan | None:
    """Return `None` for single-day trips. For multi-day trips returns
    the per-day breakdown.

    `waypoints` with `dwell_nights >= 1` force a day boundary at
    the waypoint's coordinate and emit `dwell_nights` extra days
    that stay parked there — those days have zero driving hours,
    their `sleep_coord` equals the waypoint's coord, and the
    driving-cap day that arrives at the waypoint ends slightly
    earlier so the driver can settle in.
    """
    arrival_at = departure_at + timedelta(hours=trip_duration_hours)
    cap_hours = float(profile.daily_driving_cap_hours)
    # If a km cap is set, convert to hours using avg speed and apply
    # as a secondary ceiling. Needed both for the is_multiday check
    # and for the per-day boundary loop below.
    _profile_km_cap = getattr(profile, "daily_km_cap", None)
    _overrides = day_overrides or {}
    # Profile-level preferred driving start hour — used on days 2+
    # when no per-day override says otherwise. Falls back to
    # `wake_hour` for pre-preferred-hour profiles.
    _default_start_hour = (
        getattr(profile, "preferred_driving_start_hour", None)
        or profile.wake_hour
    )
    arrival_local_hour = arrival_at.hour
    # A trip with any dwell waypoint is inherently multi-day even
    # if the driving alone would fit in one day (you can't stay
    # 2 nights somewhere in an 8-hour trip).
    has_dwell = any(w.dwell_nights >= 1 for w in waypoints)
    is_multiday = (
        trip_duration_hours > cap_hours
        or arrival_local_hour >= profile.bedtime_hour
        or has_dwell
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
    #
    # When `optimizations.sleep_stop` is set (the trip planner picked
    # a real rest area for the night, with pause overhead folded in),
    # we seed Day 1's boundary directly from it — otherwise a raw
    # `dep + cap_hours` computation produces "sleep at 16:00" while
    # the promoted sleep card correctly says "sleep at 17:01" (6 h
    # driving × 1.17 pause overhead). Same source of truth on both
    # surfaces or the two disagree by exactly the pause overhead.
    # Each boundary carries an optional `dwell_at` coordinate +
    # optional `dwell_label`: non-None coordinate means the day
    # is anchored at a waypoint (arrival day OR follow-on stay-
    # put day). The label carries the waypoint's display name
    # for the day header.
    boundaries: list[
        tuple[
            datetime, datetime, float, float,
            Coordinate | None, str | None,
        ]
    ] = []
    current_start = departure_at
    # Day-1 start_hour override — when the user tapped the pencil on
    # day 1 and picked a specific hour (e.g. leave at 10:00 instead
    # of the planned 09:00), shift the departure forward. If the
    # picked hour is BEFORE departure_at (they picked 07:00 and
    # departure was 09:00), the earliest legal option is departure_at
    # itself — don't move backwards.
    _day1_over = (day_overrides or {}).get(1) or {}
    _day1_start_hour = _day1_over.get("start_hour")
    if _day1_start_hour is not None:
        current_start = current_start.replace(
            hour=_day1_start_hour, minute=0, second=0, microsecond=0,
        )
    current_start_km = 0.0
    # Project dwell waypoints onto the route geometry so we can
    # detect when the driving cap for a day would carry us past a
    # forced overnight anchor. Pass-through waypoints (dwell 0)
    # are ignored here — they still influence routing (via OSRM)
    # but don't force day boundaries.
    dwell_anchors: list[tuple[float, Waypoint]] = []
    if route is not None:
        for wp in waypoints:
            if wp.dwell_nights < 1:
                continue
            km = _km_at_coord(route, wp.coordinate)
            if km is None or km <= 5.0 or km >= route.distance_km - 5.0:
                continue
            dwell_anchors.append((km, wp))
    dwell_anchors.sort(key=lambda t: t[0])
    # Pass-through waypoints (dwell=0) with a label — these are the
    # inspire-flow stops the user wants to see in the day timeline.
    pass_anchors: list[WaypointAnchor] = []
    if route is not None:
        for wp in waypoints:
            if wp.dwell_nights >= 1:
                _log.info(
                    "pass_anchor SKIP dwell>=1 label=%r dwell=%d",
                    wp.label, wp.dwell_nights,
                )
                continue
            if not wp.label:
                _log.info(
                    "pass_anchor SKIP no-label lat=%.4f lon=%.4f",
                    wp.coordinate.lat, wp.coordinate.lon,
                )
                continue
            km = _km_at_coord(route, wp.coordinate)
            if km is None:
                _log.info(
                    "pass_anchor SKIP off-corridor (>30km) label=%r lat=%.4f lon=%.4f",
                    wp.label, wp.coordinate.lat, wp.coordinate.lon,
                )
                continue
            _log.info(
                "pass_anchor ADD label=%r km=%.1f", wp.label, km,
            )
            pass_anchors.append(WaypointAnchor(
                label=wp.label, km=round(km, 1),
                lat=wp.coordinate.lat, lon=wp.coordinate.lon,
            ))
    pass_anchors.sort(key=lambda a: a.km)
    dwell_idx = 0
    # Effective km / h at the trip's average speed. Guard against
    # zero-hour trips (shouldn't happen, defensive).
    avg_kmh = (
        route_distance_km / trip_duration_hours
        if trip_duration_hours > 0
        else 90.0
    )
    # Apply km cap to the profile-level cap_hours so is_multiday and
    # the first-day boundary are consistent with the per-day loop.
    if _profile_km_cap and avg_kmh > 0:
        cap_hours = min(cap_hours, _profile_km_cap / max(avg_kmh, 30.0))
    remaining_hours = trip_duration_hours
    day_index = 0
    opt_sleep = (
        optimizations.sleep_stop if optimizations is not None else None
    )
    opt_sleep_consumed = False
    # Fold pause overhead into wall-clock day boundaries so middle
    # days don't sleep at 16:00 (raw 08:00 + 8 h driving) — a real
    # driver takes ~15 % more clock time than pure road time. Same
    # ratio the trip-optimizations service uses, kept in sync so
    # the promoted "sleep" card and the multi-day plan agree.
    pause_ratio = _pause_ratio(profile)
    while remaining_hours > 0:
        day_index += 1
        # Per-day override tweaks (from the ResultScreen edit sheet).
        _day_over = _overrides.get(day_index) or {}
        _this_day_cap = float(
            _day_over.get("daily_driving_cap_hours") or cap_hours
        )
        # km cap: convert to hours using route avg speed.
        _day_km_cap = _day_over.get("daily_km_cap") or getattr(
            profile, "daily_km_cap", None
        )
        if _day_km_cap and avg_kmh > 0:
            _this_day_cap = min(
                _this_day_cap, _day_km_cap / max(avg_kmh, 30.0)
            )
        # Day 1: honour the opt sleep-stop when present. It already
        # respects `cap_hours` and pause overhead, and its `at` is
        # what the promoted card shows.
        if day_index == 1 and opt_sleep is not None:
            driving_this_day = opt_sleep.rest_stop.cumulative_driving_hours
            day_end_driving_at = _extend_end_with_meals(
                current_start, opt_sleep.at, meals,
            )
            end_km = opt_sleep.rest_stop.distance_from_origin_km
            opt_sleep_consumed = True
        else:
            driving_this_day = min(_this_day_cap, remaining_hours)
            raw_drive_end = current_start + timedelta(
                hours=_wall_hours(driving_this_day, pause_ratio),
            )
            # Fold meal-stop overhead into the wall-clock end. A 5.5 h
            # driving day that swallows a lunch stop lands ~1 h later
            # than pure driving time suggests — testers saw "termina
            # a las 13:45" on a day with lunch scheduled at 13:00,
            # which is impossible (the driver is still eating). Same
            # correction the trip-optimizations service uses for the
            # sleep-hour budget; kept in sync here so day boundaries
            # and the meal cards read as one coherent timeline.
            day_end_driving_at = _extend_end_with_meals(
                current_start, raw_drive_end, meals,
            )
            end_km = current_start_km + driving_this_day * avg_kmh
        # Clip to the next dwell waypoint if this day would drive
        # past it. Arriving 20 km short of the anchor is fine; we
        # snap the day's end to the anchor exactly.
        clipped_at_dwell: Waypoint | None = None
        if dwell_idx < len(dwell_anchors):
            next_dwell_km, next_dwell_wp = dwell_anchors[dwell_idx]
            if end_km > next_dwell_km > current_start_km:
                clip_ratio = (
                    (next_dwell_km - current_start_km)
                    / max(end_km - current_start_km, 1e-6)
                )
                driving_this_day = driving_this_day * clip_ratio
                raw_drive_end = current_start + timedelta(
                    hours=_wall_hours(driving_this_day, pause_ratio),
                )
                day_end_driving_at = _extend_end_with_meals(
                    current_start, raw_drive_end, meals,
                )
                end_km = next_dwell_km
                clipped_at_dwell = next_dwell_wp
        boundaries.append(
            (current_start, day_end_driving_at, current_start_km, end_km,
             None, None),
        )
        remaining_hours -= driving_this_day
        current_start_km = end_km
        # Emit N-1 stay-put boundaries at the dwell anchor.
        # `dwell_nights=1` means "sleep ONE night here" — the
        # arrival day (already emitted) IS that night. Zero extra
        # days are needed. `dwell_nights=2` = one full stay-put
        # day between arrival and continuation, and so on.
        if clipped_at_dwell is not None:
            dwell_idx += 1
            # Mark the arrival boundary itself as a dwell day so
            # the mobile renderer picks up the waypoint label
            # AND uses the waypoint coord as sleep_coord (rather
            # than interpolating a coord along the route that
            # would drift a few km off the actual overnight).
            _prev = boundaries[-1]
            boundaries[-1] = (
                _prev[0], _prev[1], _prev[2], _prev[3],
                clipped_at_dwell.coordinate,
                clipped_at_dwell.label,
            )
            # Dwell arrival day: preserve profile wake_hour for stay
            # boundaries (they don't drive). The per-day override
            # applies only to driving-day starts.
            stay_start = _next_wake(day_end_driving_at, profile.wake_hour)
            for _ in range(clipped_at_dwell.dwell_nights - 1):
                stay_end = stay_start.replace(
                    hour=profile.bedtime_hour, minute=0, second=0,
                    microsecond=0,
                )
                if stay_end <= stay_start:
                    stay_end += timedelta(days=1)
                boundaries.append(
                    (stay_start, stay_end, current_start_km,
                     current_start_km, clipped_at_dwell.coordinate,
                     clipped_at_dwell.label),
                )
                stay_start = _next_wake(stay_end, profile.wake_hour)
            current_start = stay_start
            if remaining_hours <= 0:
                break
            continue
        if remaining_hours <= 0:
            break
        # Start next driving day at the profile's preferred hour,
        # unless the NEXT day (day_index + 1) has an explicit
        # start_hour override from the ResultScreen edit sheet.
        _next_over = _overrides.get(day_index + 1) or {}
        _next_start_hour = (
            _next_over.get("start_hour") or _default_start_hour
        )
        next_wake = _next_wake(day_end_driving_at, _next_start_hour)
        current_start = next_wake

    days: list[DayPlan] = []
    total = len(boundaries)
    for idx, (
        start_at, end_at, from_km, to_km, dwell_coord, dwell_label,
    ) in enumerate(boundaries):
        # Bucket meals by their wall-clock `at`, NOT by km — a
        # multi-day trip has meals at the sleep spot (same km on
        # both ends of the overnight break) that would otherwise
        # get assigned to the wrong day. Day N owns any meal from
        # its `start_at` up to (but not including) Day N+1's
        # `start_at`; the last day owns everything after its
        # `start_at`.
        next_start = (
            boundaries[idx + 1][0] if idx + 1 < len(boundaries) else None
        )
        day_meals = tuple(
            m for m in meals
            if m.at >= start_at
            and (next_start is None or m.at < next_start)
        )
        # Rest stops still make sense to bucket by km — they're
        # geographic markers, not clock events.
        lower_ok = (
            (lambda km: km >= from_km) if idx == 0
            else (lambda km: km > from_km)
        )
        day_rests = tuple(
            r for r in rests
            if lower_ok(r.distance_from_origin_km)
            and r.distance_from_origin_km <= to_km
        )
        sleep_at = end_at if idx + 1 < total else None
        sleep_coord: Coordinate | None = None
        # Dwell days (stay-put at a waypoint) sleep at the waypoint
        # coord — no interpolation, no ambiguity. Wins over all
        # other seeding rules.
        if dwell_coord is not None:
            sleep_coord = dwell_coord
            sleep_at = end_at
        # Day 1: opt_sleep already seeded the boundary so end_at IS
        # the sleep time and coord comes from the rest area. Later
        # days: fall through to route-geometry interpolation.
        elif idx == 0 and opt_sleep_consumed and sleep_at is not None:
            sleep_coord = opt_sleep.rest_stop.coordinate  # type: ignore[union-attr]
        elif sleep_at is not None and route is not None:
            # Otherwise interpolate a rough coord from the route
            # geometry at the day's ending km. Clients use this to
            # rank nearby hotels for the overnight-stop section.
            sleep_coord = _coord_at_km(route, to_km)
        # from_name: origin on day 1, previous dwell on later days.
        prev_dwell = boundaries[idx - 1][5] if idx > 0 else None
        day_from_name = origin_label if idx == 0 else prev_dwell
        # to_name: dwell_label of this boundary, or destination on last day.
        day_to_name = (
            destination_label if idx + 1 == total else dwell_label
        )
        day_anchors = tuple(
            a for a in pass_anchors
            if a.km > from_km and a.km <= to_km
        )
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
                dwell_label=dwell_label,
                from_name=day_from_name,
                to_name=day_to_name,
                waypoint_anchors=day_anchors,
            )
        )
    return MultiDayPlan(days=tuple(days), total_days=total)


# Wall-clock overhead we assume for each meal stop that falls
# inside a day's driving window. 1 h covers sit-down time + parking
# + service at a European roadside restaurant; matches the value
# `_select_sleep_stop` reserves in `trip_optimizations.py`.
_MEAL_OVERHEAD_HOURS = 1.0


def _extend_end_with_meals(
    start: datetime,
    raw_end: datetime,
    meals: list[MealStop],
) -> datetime:
    """Shift `raw_end` forward by one `_MEAL_OVERHEAD_HOURS` for each
    meal stop scheduled inside the growing `[start, end_at)` window.

    Iteration is safe: meals are considered in `at` order, so
    extending the window can only pull *later* meals into scope —
    once a meal falls beyond the current `end_at`, everything after
    it does too and we stop. Pure driving hours + pauses land in
    `raw_end`; this helper folds in only the meal breaks that
    genuinely interrupt driving (meals scheduled AFTER `raw_end`
    happen post-drive and don't push the day's driving-end later).
    """
    end_at = raw_end
    sorted_meals = sorted(
        (m for m in meals if m.at >= start),
        key=lambda m: m.at,
    )
    for m in sorted_meals:
        if m.at < end_at:
            end_at += timedelta(hours=_MEAL_OVERHEAD_HOURS)
        else:
            break
    return end_at


def _coord_at_km(route: Route, km: float) -> Coordinate | None:
    if not route.geometry or route.distance_km <= 0:
        return None
    fraction = max(0.0, min(1.0, km / route.distance_km))
    idx = int(fraction * (len(route.geometry) - 1))
    return route.geometry[idx]


def _km_at_coord(route: Route, coord: Coordinate) -> float | None:
    """Inverse of `_coord_at_km`: find the km-along-route closest to
    the given coord by scanning the polyline. Used to place dwell
    waypoints as forced day boundaries. Naive O(n) scan is fine —
    route.geometry rarely exceeds 500 points and this fires once
    per waypoint per plan.
    """
    if not route.geometry or route.distance_km <= 0:
        return None
    from math import radians, cos, sin, asin, sqrt

    def _haversine(a: Coordinate, b: Coordinate) -> float:
        lat1, lon1, lat2, lon2 = map(
            radians, (a.lat, a.lon, b.lat, b.lon),
        )
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
        return 2 * 6371.0 * asin(sqrt(h))

    best_idx = 0
    best_d = float("inf")
    for i, p in enumerate(route.geometry):
        d = _haversine(p, coord)
        if d < best_d:
            best_d = d
            best_idx = i
    # If the closest polyline vertex is farther than 30 km, the
    # waypoint is off-corridor — refuse to anchor.
    if best_d > 30.0:
        return None
    fraction = best_idx / max(len(route.geometry) - 1, 1)
    return fraction * route.distance_km


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

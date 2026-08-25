"""Derive which recommendation sections to surface for a given trip.

The purpose is to stop dumping every possible suggestion at the user
regardless of what kind of trip they're taking. A 3 h motorway push
does not need a hotel section. A 14 h drive across the Alps at
`travel_pace=savour` does. The client asks; this service answers.

Pure function, no external calls. Called once per `/trips/plan` after
the route is known.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from app.domain import (
    BreakStyle,
    OvernightPolicy,
    Route,
    TravelPace,
    TripProfile,
)


@dataclass(frozen=True, slots=True)
class RecommendationScope:
    """What the client should surface for this trip.

    The client is trusted to hide sections when flagged off — the
    server always populates them anyway (they're small) so we don't
    starve the AI narrative or the "always available on request" tabs.
    """

    show_rest_stops: bool
    show_hotels: bool
    show_restaurants: bool
    requires_overnight: bool
    rest_stops_count_target: int  # 0-3
    """Soft cap on how many rest stops to render. 0 = hide the section.
    """
    arrival_after_bedtime: bool
    """True when the projected arrival lands after the user's
    configured bedtime → the client shows a hint suggesting a hotel.
    """
    arrival_local_hour: int
    """Projected arrival hour (24 h clock) using the desired departure
    time. Free-flow duration, no traffic adjustment — this is a coarse
    hint, not a precise forecast.
    """
    reason: str
    """Human-readable one-liner explaining why the scope is what it is.
    Useful for tooltips and for the narrative prompt.
    """


def derive_scope(
    profile: TripProfile,
    route: Route,
    desired_departure_at: datetime,
) -> RecommendationScope:
    """Turn the trip profile + route into a rendering scope.

    Rules:
    1. `travel_pace=push` → hide rest stops (target 0), hotels only if
       requires_overnight is forced by policy or cap.
    2. `travel_pace=steady` → up to 2 rest stops when trip > 3 h,
       hotels only if requires_overnight.
    3. `travel_pace=savour` → up to 3 rest stops, hotels if the trip
       crosses bedtime, restaurants always.
    4. `overnight_policy=never` → hotels off unless the client toggle
       is on.
    5. `overnight_policy=always_if_long` → hotels forced when trip > 6 h.
    6. `daily_driving_cap_hours` — trips exceeding the cap always
       require overnight regardless of pace.
    7. `break_style` — passed through to the client to bias the tile
       ordering (foodie foregrounds restaurants, minimal hides them).
    """
    duration_hours = route.free_flow_duration.total_seconds() / 3600.0
    arrival = desired_departure_at + route.free_flow_duration
    bedtime = _next_at_hour(desired_departure_at, profile.bedtime_hour)
    arrival_after_bedtime = arrival > bedtime and duration_hours >= 1.0

    requires_overnight = _requires_overnight(
        profile=profile,
        duration_hours=duration_hours,
        arrival_after_bedtime=arrival_after_bedtime,
    )

    show_hotels = _show_hotels(
        profile=profile,
        duration_hours=duration_hours,
        requires_overnight=requires_overnight,
    )

    rest_target = _rest_stops_target(profile, duration_hours)
    show_rest_stops = rest_target > 0

    show_restaurants = profile.break_style is not BreakStyle.MINIMAL

    return RecommendationScope(
        show_rest_stops=show_rest_stops,
        show_hotels=show_hotels,
        show_restaurants=show_restaurants,
        requires_overnight=requires_overnight,
        rest_stops_count_target=rest_target,
        arrival_after_bedtime=arrival_after_bedtime,
        arrival_local_hour=arrival.hour,
        reason=_reason(
            profile=profile,
            duration_hours=duration_hours,
            requires_overnight=requires_overnight,
            arrival_after_bedtime=arrival_after_bedtime,
        ),
    )


def _requires_overnight(
    *,
    profile: TripProfile,
    duration_hours: float,
    arrival_after_bedtime: bool,
) -> bool:
    if profile.overnight_policy is OvernightPolicy.NEVER:
        return False
    if profile.overnight_policy is OvernightPolicy.ALWAYS_IF_LONG:
        if duration_hours > 6.0:
            return True
    if duration_hours > profile.daily_driving_cap_hours:
        return True
    if profile.overnight_policy is OvernightPolicy.IF_NEEDED and \
            arrival_after_bedtime:
        return True
    return False


def _show_hotels(
    *,
    profile: TripProfile,
    duration_hours: float,
    requires_overnight: bool,
) -> bool:
    if requires_overnight:
        return True
    if profile.overnight_policy is OvernightPolicy.NEVER:
        return False
    # `savour` shows hotels for trips > 4 h so travellers who want to
    # extend into two days always have the option one tap away.
    if profile.travel_pace is TravelPace.SAVOUR and duration_hours > 4.0:
        return True
    return False


def _rest_stops_target(profile: TripProfile, duration_hours: float) -> int:
    if profile.travel_pace is TravelPace.PUSH:
        # Push wants to be left alone; only show a single stop on
        # marathons > 8 h and never for shorter runs.
        return 1 if duration_hours >= 8.0 else 0
    if profile.travel_pace is TravelPace.STEADY:
        if duration_hours < 3.0:
            return 0
        if duration_hours < 6.0:
            return 1
        return 2
    # savour
    if duration_hours < 2.0:
        return 0
    if duration_hours < 5.0:
        return 2
    return 3


def _next_at_hour(base: datetime, hour: int) -> datetime:
    candidate = base.replace(hour=hour, minute=0, second=0, microsecond=0)
    if candidate <= base:
        candidate = candidate + timedelta(days=1)
    return candidate


def _reason(
    *,
    profile: TripProfile,
    duration_hours: float,
    requires_overnight: bool,
    arrival_after_bedtime: bool,
) -> str:
    if requires_overnight and arrival_after_bedtime:
        return (
            f"trip ~{duration_hours:.1f} h ends past bedtime "
            f"({profile.bedtime_hour:02d}:00) — split recommended"
        )
    if requires_overnight and duration_hours > profile.daily_driving_cap_hours:
        return (
            f"trip ~{duration_hours:.1f} h exceeds daily cap of "
            f"{profile.daily_driving_cap_hours} h"
        )
    if requires_overnight:
        return "policy asks for overnight on long trips"
    if profile.travel_pace is TravelPace.PUSH:
        return "push pace: sections minimised"
    if profile.travel_pace is TravelPace.SAVOUR:
        return "savour pace: sections foregrounded"
    return "steady pace: default scope"

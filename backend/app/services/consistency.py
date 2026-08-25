"""Consistency checks over the assembled trip plan.

The planner stitches together data from many providers (routing, rest
stops, restaurants, hotels, meal slots). Occasionally two pieces of
that data contradict each other — e.g. the app tells a driver "lunch at
13:00, at km 350 from origin" when they only just left at 12:00.

This module runs cheap deterministic sanity checks after the plan is
built and emits `Issue` records that the API surfaces as warnings. It
never mutates the plan; the caller decides whether to display, hide, or
hard-fail on each issue.

Design notes:
- Pure. No I/O. Trivially unit-testable.
- Additive: each check is a small function; new checks slot in without
  touching existing ones.
- Severity is advisory. Anything that would be physically impossible
  (e.g. 400 km/h implied) is `error`; merely improbable is `warning`.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum

from app.domain import FuelType, Route
from app.providers.fuel import FuelPrice
from app.services.fuel_cost import FuelCostEstimate
from app.services.trip_optimizations import MealStop, Optimizations, SleepStop


# Above this the plan is physically impossible on European roads
# (Autobahn cruising sits ~130, real average with tolls ~110). We give a
# generous margin so short segments that happen to include a downhill
# motorway stretch don't false-trip.
_MAX_PLAUSIBLE_KMH = 140.0
# Between "plausible upper bound" and "impossible" we still flag as a
# warning — the plan probably won't kill anyone but the numbers don't
# add up cleanly, and surfacing it lets us tighten upstream logic.
_SUSPICIOUS_KMH = 115.0
# A meal that lands within this many minutes of arrival is functionally
# not a meal stop — the driver would eat 5 min from destination.
_MIN_MEAL_BUFFER_MIN = 20


class Severity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"


@dataclass(frozen=True, slots=True)
class Issue:
    code: str
    severity: Severity
    message: str


def check_trip(
    *,
    departure_at: datetime,
    arrival_at: datetime,
    optimizations: Optimizations | None,
    route: Route | None = None,
    fuel_cost: FuelCostEstimate | None = None,
    fuel_prices: tuple[FuelPrice, ...] = (),
) -> tuple[Issue, ...]:
    """Run all consistency checks and return the collected issues.

    Ordered so the most severe issues come first — makes it trivial for
    the client to pop the top one into a banner.

    Optional args reflect data that isn't always available: `route` and
    `fuel_cost` only appear when a profile is present; `fuel_prices`
    empty when the provider returned nothing. Absent inputs simply skip
    their respective checks — no false positives from missing data.
    """
    issues: list[Issue] = []
    if optimizations is not None:
        for meal in optimizations.meal_stops:
            issues.extend(
                _check_meal_stop(
                    meal,
                    departure_at=departure_at,
                    arrival_at=arrival_at,
                ),
            )
        if optimizations.sleep_stop is not None:
            issues.extend(
                _check_sleep_stop(
                    optimizations.sleep_stop,
                    departure_at=departure_at,
                    arrival_at=arrival_at,
                ),
            )

    if fuel_cost is not None:
        issues.extend(
            _check_fuel(
                fuel_cost=fuel_cost, route=route, fuel_prices=fuel_prices,
            ),
        )

    _rank = {Severity.ERROR: 0, Severity.WARNING: 1, Severity.INFO: 2}
    issues.sort(key=lambda i: _rank[i.severity])
    return tuple(issues)


def _check_meal_stop(
    meal: MealStop,
    *,
    departure_at: datetime,
    arrival_at: datetime,
) -> list[Issue]:
    """Sanity-check a single meal stop against the trip timeline.

    Three failure modes worth catching:
    1. Meal `at` before departure or after arrival (temporal impossibility).
    2. Distance-from-origin implies an average speed no car sustains on a
       European motorway network — the "12:00 depart, lunch at 13:00,
       350 km" case that motivated this module.
    3. Meal lands so close to arrival that the driver may as well eat at
       the destination — probably a mis-picked rest stop.
    """
    out: list[Issue] = []
    label = meal.slot.value

    if meal.at < departure_at:
        out.append(Issue(
            code="meal.before_departure",
            severity=Severity.ERROR,
            message=(
                f"{label} stop scheduled at {meal.at.isoformat()} but the "
                f"trip only starts at {departure_at.isoformat()}."
            ),
        ))
        return out

    if meal.at > arrival_at:
        out.append(Issue(
            code="meal.after_arrival",
            severity=Severity.ERROR,
            message=(
                f"{label} stop scheduled at {meal.at.isoformat()} but the "
                f"trip already ends at {arrival_at.isoformat()}."
            ),
        ))
        return out

    elapsed_hours = (meal.at - departure_at).total_seconds() / 3600.0
    km = meal.rest_stop.distance_from_origin_km
    if elapsed_hours > 0 and km > 0:
        implied_kmh = km / elapsed_hours
        if implied_kmh > _MAX_PLAUSIBLE_KMH:
            out.append(Issue(
                code="meal.impossible_speed",
                severity=Severity.ERROR,
                message=(
                    f"{label} stop at km {km:.0f} would need ~"
                    f"{implied_kmh:.0f} km/h from a {departure_at.isoformat()} "
                    f"departure — physically impossible."
                ),
            ))
        elif implied_kmh > _SUSPICIOUS_KMH:
            out.append(Issue(
                code="meal.suspicious_speed",
                severity=Severity.WARNING,
                message=(
                    f"{label} stop at km {km:.0f} implies ~"
                    f"{implied_kmh:.0f} km/h average — check the rest-stop "
                    f"cumulative time."
                ),
            ))

    remaining_min = (arrival_at - meal.at).total_seconds() / 60.0
    if remaining_min < _MIN_MEAL_BUFFER_MIN:
        out.append(Issue(
            code="meal.too_close_to_arrival",
            severity=Severity.WARNING,
            message=(
                f"{label} stop lands {remaining_min:.0f} min before arrival — "
                f"the driver would reach the destination before finishing."
            ),
        ))

    return out


def _check_sleep_stop(
    sleep: SleepStop,
    *,
    departure_at: datetime,
    arrival_at: datetime,
) -> list[Issue]:
    """Same speed / timeline sanity as meal stops, applied to the sleep
    hotel. A sleep stop that lands before departure or implies teleport
    speeds is as broken as its lunch equivalent — same bug class, so we
    reuse the same thresholds.
    """
    out: list[Issue] = []
    if sleep.at < departure_at:
        out.append(Issue(
            code="sleep.before_departure",
            severity=Severity.ERROR,
            message=(
                f"Sleep stop scheduled at {sleep.at.isoformat()} but the "
                f"trip only starts at {departure_at.isoformat()}."
            ),
        ))
        return out

    if sleep.at > arrival_at:
        out.append(Issue(
            code="sleep.after_arrival",
            severity=Severity.ERROR,
            message=(
                f"Sleep stop scheduled at {sleep.at.isoformat()} but the "
                f"trip already ends at {arrival_at.isoformat()}."
            ),
        ))
        return out

    elapsed_hours = (sleep.at - departure_at).total_seconds() / 3600.0
    km = sleep.rest_stop.distance_from_origin_km
    if elapsed_hours > 0 and km > 0:
        implied_kmh = km / elapsed_hours
        if implied_kmh > _MAX_PLAUSIBLE_KMH:
            out.append(Issue(
                code="sleep.impossible_speed",
                severity=Severity.ERROR,
                message=(
                    f"Sleep stop at km {km:.0f} would need ~{implied_kmh:.0f} "
                    f"km/h from a {departure_at.isoformat()} departure — "
                    f"physically impossible."
                ),
            ))
        elif implied_kmh > _SUSPICIOUS_KMH:
            out.append(Issue(
                code="sleep.suspicious_speed",
                severity=Severity.WARNING,
                message=(
                    f"Sleep stop at km {km:.0f} implies ~{implied_kmh:.0f} "
                    f"km/h average — check the rest-stop cumulative time."
                ),
            ))
    return out


# Below this many stations for a long combustion trip we assume the
# provider is short on data. The driver can still refuel, but the app
# has no visibility to guide them — worth a warning.
_LONG_TRIP_KM_FOR_FUEL_COVERAGE = 500.0


def _check_fuel(
    *,
    fuel_cost: FuelCostEstimate,
    route: Route | None,
    fuel_prices: tuple[FuelPrice, ...],
) -> list[Issue]:
    """Two fuel-side sanity checks:

    1. EV whose range doesn't cover the route → error. `fuel_cost` also
       carries a driver-facing note, but promoting it to an `Issue`
       lets the client render it consistently with the other issues.
    2. Combustion trip long enough to require a mid-trip refuel, but
       the provider returned zero fuel stations. The driver isn't
       flying blind, but the app can't say "cheapest fuel here" — flag
       so the UI can hint at the gap.
    """
    out: list[Issue] = []
    if not fuel_cost.range_ok:
        note = " " + fuel_cost.notes[0] if fuel_cost.notes else ""
        out.append(Issue(
            code="fuel.range_exceeded",
            severity=Severity.ERROR,
            message=(
                f"Vehicle cannot cover the route on a single "
                f"{fuel_cost.unit_label} — recharging or refueling "
                f"required en route.{note}"
            ),
        ))

    if (
        route is not None
        and fuel_cost.fuel_type is not FuelType.ELECTRIC
        and route.distance_km >= _LONG_TRIP_KM_FOR_FUEL_COVERAGE
        and not fuel_prices
    ):
        out.append(Issue(
            code="fuel.no_stations_visible",
            severity=Severity.WARNING,
            message=(
                f"Trip is {route.distance_km:.0f} km but no fuel stations "
                f"are visible along the route — pricing and refuel picks "
                f"are unavailable for this leg."
            ),
        ))
    return out

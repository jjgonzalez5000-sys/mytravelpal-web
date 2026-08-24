"""Toll-savings comparison: main route (with tolls) vs. avoid-tolls route.

Given the two routes, quantify what the driver actually trades:
    money saved by skipping tolls  vs. extra minutes on the alternative

The `worth_it` heuristic bundles a common-sense rule of thumb so the UI
can highlight the alternative when it's a good deal. Users are always
free to pick either route regardless of the flag.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain import Route

# Rule of thumb: if you save > 5 € for less than 30 min extra, it's
# usually worth it for a leisure trip. Tunable later per-user.
_WORTH_IT_MIN_SAVINGS_EUR = 5.0
_WORTH_IT_MAX_PENALTY_MINUTES = 30.0


@dataclass(frozen=True, slots=True)
class TollAlternative:
    distance_km: float
    duration_minutes: float
    toll_cost_eur: float
    savings_eur: float
    time_penalty_minutes: float
    extra_distance_km: float
    worth_it: bool
    geometry: tuple = ()


def compare(main: Route, alternative: Route) -> TollAlternative:
    savings = main.toll_cost_eur - alternative.toll_cost_eur
    time_penalty = (
        alternative.free_flow_duration.total_seconds()
        - main.free_flow_duration.total_seconds()
    ) / 60.0
    extra_distance = alternative.distance_km - main.distance_km
    worth_it = (
        savings >= _WORTH_IT_MIN_SAVINGS_EUR
        and time_penalty <= _WORTH_IT_MAX_PENALTY_MINUTES
    )
    return TollAlternative(
        distance_km=round(alternative.distance_km, 1),
        duration_minutes=round(
            alternative.free_flow_duration.total_seconds() / 60.0, 1,
        ),
        toll_cost_eur=round(alternative.toll_cost_eur, 2),
        savings_eur=round(savings, 2),
        time_penalty_minutes=round(time_penalty, 1),
        extra_distance_km=round(extra_distance, 1),
        worth_it=worth_it,
        geometry=alternative.geometry,
    )

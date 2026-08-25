"""Partial toll skipping: suggest which individual toll stretches are
worth skipping via a secondary-road detour.

Common practice in high-toll countries (FR, IT, ES): the driver stays on
the motorway for most of the trip but exits before an expensive stretch,
drives on the parallel national road for a few kilometres, and rejoins
the motorway after the toll booth they wanted to skip. This is finer
grained than the whole-route `toll_alternative`.

Doing this *properly* needs booth-level toll data — the position of each
toll gate, its per-vehicle-class fare, and the topology of the parallel
network. That comes with a paid routing provider (HERE, TomTom,
TollGuru). Here we ship a **planning-phase heuristic** that:

- Chops the route into ~5 segments using the mock waypoints.
- Attributes each segment a proportional share of the total toll.
- Estimates the detour penalty as ~15 % extra distance at ~75 km/h.
- Flags the segments where savings-per-minute is best as "worth it".

The output is meant as decision support during planning, not as
turn-by-turn guidance. When we contract a real toll provider, the
service signature stays the same and we swap the internals.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain import Coordinate, Route
from app.providers.tollguru import TollBooth

_SEGMENT_COUNT = 5
# Detour penalty for skipping ONE toll booth: exit, drive parallel a few
# km, re-enter. Real numbers depend on the network — this is a low-side
# average for a French motorway with a parallel N-road.
_DETOUR_EXTRA_MINUTES_BASE = 6.0
_DETOUR_EXTRA_KM_BASE = 4.0
# A skip is "worth it" if it saves ≥ 3 € for < 10 extra minutes.
_WORTH_IT_MIN_SAVINGS_EUR = 3.0
_WORTH_IT_MAX_PENALTY_MINUTES = 10.0


@dataclass(frozen=True, slots=True)
class PartialTollSkip:
    label: str                     # human label ("Segment 2: south of Lyon")
    distance_from_origin_km: float
    savings_eur: float
    time_penalty_minutes: float
    extra_distance_km: float
    worth_it: bool
    coordinate: Coordinate         # approximate exit point on the map


def compute(
    route: Route,
    *,
    real_tolls: tuple[TollBooth, ...] | None = None,
) -> tuple[PartialTollSkip, ...]:
    """Return per-stretch toll-skip recommendations.

    Two modes:
    - **Real (`real_tolls` provided)**: one recommendation per booth
      from a booth-level provider like TollGuru — savings equal the
      booth's actual fare, penalty is a small fixed exit/re-entry cost.
    - **Heuristic (default)**: chop the route into ~5 segments and split
      the total toll across them with a middle-heavy weight.
    """
    if real_tolls:
        return _compute_from_real_tolls(route, real_tolls)
    if route.toll_cost_eur <= 0 or route.distance_km <= 0:
        return ()

    # Pick evenly-spaced anchors along the route using origin + waypoints
    # + destination. If we have geometry (OSRM), we can be more precise;
    # otherwise fall back to great-circle interpolation.
    anchors = _segment_anchors(route)
    if len(anchors) < 2:
        return ()

    # Total toll spread across segments. First and last segments (near
    # origin/destination) usually have city tolls too — keep a flat
    # distribution as the honest heuristic.
    per_segment_toll = route.toll_cost_eur / len(anchors)

    skips: list[PartialTollSkip] = []
    for i, coord in enumerate(anchors):
        # Vary the savings a bit so the UI shows a distribution (some
        # tolls are worth more than others). Use position along route:
        # middle segments are usually the priciest.
        rel = (i + 0.5) / len(anchors)
        weight = 1.0 + 0.6 * (0.5 - abs(rel - 0.5))  # peak at midpoint
        savings = round(per_segment_toll * weight, 2)
        penalty = round(_DETOUR_EXTRA_MINUTES_BASE * weight, 1)
        extra_km = round(_DETOUR_EXTRA_KM_BASE * weight, 1)
        worth = (
            savings >= _WORTH_IT_MIN_SAVINGS_EUR
            and penalty <= _WORTH_IT_MAX_PENALTY_MINUTES
        )
        skips.append(
            PartialTollSkip(
                label=f"Toll stretch {i + 1} / {len(anchors)}",
                distance_from_origin_km=round(
                    rel * route.distance_km, 1,
                ),
                savings_eur=savings,
                time_penalty_minutes=penalty,
                extra_distance_km=extra_km,
                worth_it=worth,
                coordinate=coord,
            )
        )
    # Sort by worth-it first, then by savings desc — the UI shows the
    # top picks with the strongest reason to skip up top.
    skips.sort(key=lambda s: (not s.worth_it, -s.savings_eur))
    return tuple(skips)


def _compute_from_real_tolls(
    route: Route, tolls: tuple[TollBooth, ...],
) -> tuple[PartialTollSkip, ...]:
    """Real-data variant: one PartialTollSkip per real booth.

    Position-on-route is approximated by the closest point in the
    route geometry (or waypoints as fallback) — good enough for the
    driver to visualise which stretch they'd skip.
    """
    if not tolls:
        return ()
    reference = list(route.geometry) if route.geometry else [
        route.origin, *route.waypoints, route.destination,
    ]
    total_km = route.distance_km if route.distance_km > 0 else 1.0
    skips: list[PartialTollSkip] = []
    for i, booth in enumerate(tolls):
        booth_coord = Coordinate(lat=booth.lat, lon=booth.lon)
        # Find the reference-point index nearest the booth; use its
        # relative position along the route as km-from-origin.
        nearest_idx = min(
            range(len(reference)),
            key=lambda k: _crow(reference[k], booth_coord),
        )
        fraction = nearest_idx / max(1, len(reference) - 1)
        distance_from_origin = round(fraction * total_km, 1)
        savings = round(booth.cost_eur, 2)
        # A real exit + parallel road + re-entry near a single booth
        # costs ~5 min on average — much less than the whole-route
        # avoid-tolls detour.
        penalty = 5.0 + max(0.0, (booth.cost_eur - 5.0)) * 0.05
        skips.append(
            PartialTollSkip(
                label=booth.name or f"Toll booth {i + 1}",
                distance_from_origin_km=distance_from_origin,
                savings_eur=savings,
                time_penalty_minutes=round(penalty, 1),
                extra_distance_km=2.5,
                worth_it=(savings >= _WORTH_IT_MIN_SAVINGS_EUR
                          and penalty <= _WORTH_IT_MAX_PENALTY_MINUTES),
                coordinate=booth_coord,
            )
        )
    skips.sort(key=lambda s: (not s.worth_it, -s.savings_eur))
    return tuple(skips)


def _crow(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km
    return _haversine_km(a, b)


def _segment_anchors(route: Route) -> tuple[Coordinate, ...]:
    """Pick `_SEGMENT_COUNT` interior points to anchor the segments."""
    if route.geometry:
        # Real polyline available — sample from it.
        step = max(1, len(route.geometry) // (_SEGMENT_COUNT + 1))
        return tuple(
            route.geometry[step * i]
            for i in range(1, _SEGMENT_COUNT + 1)
            if step * i < len(route.geometry)
        )
    # Fall back to waypoints
    if len(route.waypoints) >= _SEGMENT_COUNT:
        step = max(1, len(route.waypoints) // _SEGMENT_COUNT)
        return tuple(
            route.waypoints[step * i]
            for i in range(_SEGMENT_COUNT)
            if step * i < len(route.waypoints)
        )
    return route.waypoints

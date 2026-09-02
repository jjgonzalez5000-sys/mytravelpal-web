"""Intra-section toll bypass suggestions.

For each HERE toll section (operator entry gate → exit gate with a
known fare), we find intermediate toll gates via OSM Overpass, then
price each adjacent pair (exit_at_gate_i, reenter_at_gate_j) using
cached HERE sub-queries.

The bypass saves the driver the fare between gate_i and gate_j but
adds time/distance on the parallel national road.  We surface only
options where savings > 2 € AND savings-per-minute > 0.30 €/min.

Output is intentionally separate from `partial_toll_skips` so the
mobile can render them under the relevant day/section block.
"""

from __future__ import annotations

import asyncio
import logging
import math
from dataclasses import dataclass
from typing import Any

from app.domain import Coordinate
from app.providers.osm_toll_gates import OsmTollGateProvider, TollGate, sort_gates_along_axis
from app.providers.tollguru import TollBooth

_log = logging.getLogger(__name__)

# A skip is worth surfacing only when savings clear these thresholds.
_MIN_SAVINGS_EUR = 2.0       # below €2 it's barely worth the hassle
_MAX_TIME_PENALTY_MIN = 60.0 # don't suggest detours longer than 1 h

# Assumed speed on a parallel national road when bypassing a motorway stretch.
_FREE_ROAD_SPEED_KMH = 70.0

# Road-factor: real road distance is ~25 % longer than crow-flies.
_ROAD_FACTOR = 1.25


@dataclass(frozen=True, slots=True)
class IntraSectionSkip:
    section_name: str       # "Vienne → Lancon"
    exit_gate_name: str     # where to exit the motorway
    exit_lat: float
    exit_lon: float
    reentry_gate_name: str  # where to re-enter
    reentry_lat: float
    reentry_lon: float
    full_section_eur: float
    bypass_eur: float       # cost of first half + second half
    savings_eur: float
    free_road_km: float
    time_penalty_minutes: float
    worth_it: bool


async def compute(
    booths: tuple[TollBooth, ...],
    osm_provider: OsmTollGateProvider,
    here_provider: Any = None,  # reserved for TollGuru booth-level upgrade
    *,
    max_skips_per_section: int = 3,
) -> list[IntraSectionSkip]:
    """Return bypass options across all toll sections in *booths*."""
    if not booths:
        return []

    tasks = [
        _process_section(
            booth, osm_provider, here_provider,
            max_skips=max_skips_per_section,
        )
        for booth in booths
        if booth.exit_lat and booth.exit_lon  # section must have both gates
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    skips: list[IntraSectionSkip] = []
    for r in results:
        if isinstance(r, Exception):
            _log.warning("intra_section_skips section error: %r", r)
        elif isinstance(r, list):
            skips.extend(r)
    skips.sort(key=lambda s: (-s.savings_eur, s.time_penalty_minutes))
    return skips


async def _process_section(
    booth: TollBooth,
    osm_provider: OsmTollGateProvider,
    here_provider,
    *,
    max_skips: int,
) -> list[IntraSectionSkip]:
    entry = Coordinate(lat=booth.lat, lon=booth.lon)
    exit_ = Coordinate(lat=booth.exit_lat, lon=booth.exit_lon)

    raw_gates = await osm_provider.gates_in_section(
        entry.lat, entry.lon, exit_.lat, exit_.lon,
    )
    if not raw_gates:
        return []

    # Sort gates in travel order, then filter out gates from other
    # motorways.  Prefer filtering by OSM operator tag (most accurate);
    # fall back to a geometric corridor if operator data is sparse.
    gates = sort_gates_along_axis(raw_gates, entry.lat, entry.lon, exit_.lat, exit_.lon)
    gates = _filter_by_operator(gates, booth.operator, fallback_perp_km=20.0,
                                 entry=entry, exit_=exit_)
    gates = _exclude_endpoints(gates, entry, exit_, min_km=3.0)
    if len(gates) < 2:
        return []

    # Test each adjacent pair (gate_i → gate_i+1) as bypass window.
    pairs = list(zip(gates, gates[1:]))
    # Evaluate all adjacent pairs and let the savings+penalty filters trim.
    # _midpoint_pairs was selecting only 5 around the midpoint; since
    # savings-per-minute is constant per section (savings ∝ distance,
    # penalty ∝ distance), the best option is the one with highest
    # absolute savings = longest bypass = pairs furthest apart.
    # Sort by descending crow-flies distance to surface the best first.
    pairs.sort(
        key=lambda p: -_haversine(p[0].lat, p[0].lon, p[1].lat, p[1].lon),
    )

    section_km = _haversine(entry.lat, entry.lon, exit_.lat, exit_.lon)
    if section_km <= 0:
        return []

    # HERE sub-queries for gate→gate are unreliable: the routing API
    # picks free roads for short segments and returns €0.  We use
    # proportional interpolation instead — EU motorway tariffs are
    # quasi-linear with distance (operators charge per km driven).
    # Savings = section_fare × (skipped_km / section_km).
    # When TollGuru is available, swap this for its booth-level fares.
    skips: list[IntraSectionSkip] = []
    for g_exit, g_reentry in pairs:
        crow_skip_km = _haversine(g_exit.lat, g_exit.lon, g_reentry.lat, g_reentry.lon)
        if crow_skip_km <= 0:
            continue
        savings = round(booth.cost_eur * (crow_skip_km / section_km), 2)
        if savings < _MIN_SAVINGS_EUR:
            continue
        bypass_eur = round(booth.cost_eur - savings, 2)
        free_km = round(crow_skip_km * _ROAD_FACTOR, 1)
        penalty = round(free_km / _FREE_ROAD_SPEED_KMH * 60, 1)
        if penalty <= 0:
            penalty = 1.0
        if penalty > _MAX_TIME_PENALTY_MIN:
            continue
        skips.append(IntraSectionSkip(
            section_name=booth.name,
            exit_gate_name=g_exit.name or f"Gate at {g_exit.lat:.3f}",
            exit_lat=g_exit.lat,
            exit_lon=g_exit.lon,
            reentry_gate_name=g_reentry.name or f"Gate at {g_reentry.lat:.3f}",
            reentry_lat=g_reentry.lat,
            reentry_lon=g_reentry.lon,
            full_section_eur=booth.cost_eur,
            bypass_eur=bypass_eur,
            savings_eur=savings,
            free_road_km=free_km,
            time_penalty_minutes=penalty,
            worth_it=True,
        ))
    skips.sort(key=lambda s: -s.savings_eur)
    return skips[:max_skips]


def _filter_by_operator(
    gates: list[TollGate],
    section_operator: str,
    *,
    fallback_perp_km: float,
    entry: Coordinate,
    exit_: Coordinate,
) -> list[TollGate]:
    """Filter gates to those belonging to the same toll operator.

    When the section operator (e.g. "ASF") is known AND enough gates have
    a matching operator tag, use operator matching — it works even when
    the motorway takes a curved path (e.g. A7 bending through Avignon).
    Fall back to geometric corridor filtering when OSM tags are absent.
    """
    if section_operator:
        op_lower = section_operator.lower()
        by_operator = [
            g for g in gates
            if g.operator and g.operator.lower() == op_lower
        ]
        if len(by_operator) >= 2:
            return by_operator
        # Some gates on the same motorway may lack an operator tag — include
        # untagged gates only when they sit inside the bbox of the matched
        # gates + the section endpoints, so nearby parallel motorways are
        # still excluded.
        if by_operator:
            all_lats = [g.lat for g in by_operator] + [entry.lat, exit_.lat]
            all_lons = [g.lon for g in by_operator] + [entry.lon, exit_.lon]
            pad = 0.1
            s, n = min(all_lats) - pad, max(all_lats) + pad
            w, e = min(all_lons) - pad, max(all_lons) + pad
            return [
                g for g in gates
                if g.operator.lower() == op_lower
                or (not g.operator and s <= g.lat <= n and w <= g.lon <= e)
            ]

    # Fallback: perpendicular distance from entry→exit axis.
    dlat = exit_.lat - entry.lat
    dlon = exit_.lon - entry.lon
    norm = math.sqrt(dlat ** 2 + dlon ** 2) or 1.0

    def perp_km(g: TollGate) -> float:
        cross = ((g.lat - entry.lat) * dlon - (g.lon - entry.lon) * dlat) / norm
        return abs(cross) * 111.0

    return [g for g in gates if perp_km(g) <= fallback_perp_km]


def _exclude_endpoints(
    gates: list[TollGate],
    entry: Coordinate,
    exit_: Coordinate,
    min_km: float,
) -> list[TollGate]:
    return [
        g for g in gates
        if _haversine(g.lat, g.lon, entry.lat, entry.lon) > min_km
        and _haversine(g.lat, g.lon, exit_.lat, exit_.lon) > min_km
    ]


def _midpoint_pairs(
    pairs: list[tuple[TollGate, TollGate]],
    entry: Coordinate,
    exit_: Coordinate,
    max_pairs: int,
) -> list[tuple[TollGate, TollGate]]:
    """Return the pairs whose midpoint is closest to the section midpoint."""
    mid_lat = (entry.lat + exit_.lat) / 2
    mid_lon = (entry.lon + exit_.lon) / 2

    def dist_to_mid(pair: tuple[TollGate, TollGate]) -> float:
        ge, gr = pair
        m_lat = (ge.lat + gr.lat) / 2
        m_lon = (ge.lon + gr.lon) / 2
        return _haversine(m_lat, m_lon, mid_lat, mid_lon)

    return sorted(pairs, key=dist_to_mid)[:max_pairs]


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))

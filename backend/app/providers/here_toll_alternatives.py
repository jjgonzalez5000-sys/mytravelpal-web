"""HERE Routing v8 based toll-skip alternative computation.

For each `PartialTollSkip` candidate we already know its position on
the route (`skip.coordinate`). To turn the "generic +8 min +2.5 km"
heuristic into REAL numbers, we:

1. Pick two anchor coordinates ~15 km before and after the skip
   along the actual route polyline (via `_PolylineWalker`).
2. Ask HERE Routing v8 for a route between the anchors WITH
   `avoid[features]=tollRoad` — this returns the real non-toll
   alternative through secondary roads.
3. Compare the alternative's `duration` + `length` to the same
   span on the original route → real minute + km penalty.
4. Decode the HERE flexible polyline into a list of coordinates
   the mobile client can render on the map as an alternate route
   preview.

Fans out across all skips in parallel via `asyncio.gather`. Skips
whose HERE call fails degrade to the heuristic penalty already in
the `PartialTollSkip` — nothing crashes, just less detail.
"""

from __future__ import annotations

import asyncio
import logging
import os
from dataclasses import replace
from typing import Any

import httpx

from app.domain import Coordinate, Route
from app.services.partial_toll_skips import (
    _WORTH_IT_MAX_PENALTY_MINUTES,
    _WORTH_IT_MIN_SAVINGS_EUR,
    PartialTollSkip,
)

_log = logging.getLogger(__name__)

_ENDPOINT = "https://router.hereapi.com/v8/routes"
_TIMEOUT_S = 8.0
# Routing a few hundred km with toll avoidance takes noticeably longer.
_TIMEOUT_LONG_S = 20.0

# How far before / after the skip point to anchor the alternative
# routing request. 15 km is enough to include the exit + re-entry
# ramps around a typical toll stretch while still keeping the
# request small (fewer secondary roads to score).
_ANCHOR_KM = 15.0

# In-memory cache keyed by rounded anchor coords → (penalty_min,
# penalty_km, geometry). Fares along a corridor rarely change so a
# 24 h TTL keeps repeat plans cheap.
_CACHE: dict[
    tuple[float, float, float, float],
    tuple[float, float, tuple[Coordinate, ...], float],
] = {}
_CACHE_TTL_S = 24 * 60 * 60


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


class _PolylineWalker:
    """Walks a `Route.geometry` polyline to find the point N km
    before or after a target position. Same shape as the one in
    `rest_stops.py` — kept local so this module doesn't reach into
    another service's internals.
    """

    __slots__ = ("_pts", "_cum")

    def __init__(self, route: Route) -> None:
        from app.providers.routing import _haversine_km
        pts = route.geometry or ()
        cum: list[float] = [0.0]
        acc = 0.0
        for i in range(1, len(pts)):
            acc += _haversine_km(pts[i - 1], pts[i])
            cum.append(acc)
        self._pts = pts
        self._cum = cum

    def _index_at(self, km: float) -> int:
        """Polyline index at approximately `km` from origin."""
        target = max(0.0, min(km, self._cum[-1]))
        lo, hi = 0, len(self._cum) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if self._cum[mid] < target:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def anchor(self, km: float) -> Coordinate | None:
        """Return the polyline point closest to `km` from origin.
        None when the route has no geometry."""
        if not self._pts:
            return None
        return self._pts[self._index_at(km)]

    def distance_between(self, km_from: float, km_to: float) -> float:
        """Real polyline km between two km-from-origin marks. Used
        to derive the original leg's actual distance (curvy roads
        are longer than the great-circle 2*_ANCHOR_KM assumption)."""
        if not self._pts:
            return 0.0
        i0 = self._index_at(km_from)
        i1 = self._index_at(km_to)
        if i1 < i0:
            i0, i1 = i1, i0
        return max(0.0, self._cum[i1] - self._cum[i0])


def _cache_key(
    a: Coordinate, b: Coordinate, avoid_tolls: bool = True,
) -> tuple[float, float, float, float, bool]:
    return (
        round(a.lat, 3), round(a.lon, 3),
        round(b.lat, 3), round(b.lon, 3),
        avoid_tolls,
    )


def _cached(
    a: Coordinate, b: Coordinate, avoid_tolls: bool = True,
) -> tuple | None:
    import time
    ck = _cache_key(a, b, avoid_tolls)
    entry = _CACHE.get(ck)
    if entry is None:
        return None
    duration_min, distance_km, geom, ts = entry
    if time.time() - ts > _CACHE_TTL_S:
        _CACHE.pop(ck, None)
        return None
    return (duration_min, distance_km, geom)


def _remember(
    a: Coordinate,
    b: Coordinate,
    duration_min: float,
    distance_km: float,
    geom: tuple[Coordinate, ...],
    avoid_tolls: bool = True,
) -> None:
    import time
    _CACHE[_cache_key(a, b, avoid_tolls)] = (
        duration_min, distance_km, geom, time.time(),
    )


# A long alternative route can carry thousands of points; the client only
# draws it as a preview line, so keep it light.
_MAX_ALT_POINTS = 600


def _decimate(
    coords: list[Coordinate], limit: int = _MAX_ALT_POINTS,
) -> list[Coordinate]:
    if len(coords) <= limit:
        return coords
    step = -(-len(coords) // limit)  # ceil division
    thinned = coords[::step]
    if thinned[-1] != coords[-1]:
        thinned.append(coords[-1])
    return thinned


async def _fetch_alternative(
    client: httpx.AsyncClient,
    anchor_before: Coordinate,
    anchor_after: Coordinate,
    key: str,
    *,
    avoid_tolls: bool = True,
) -> tuple[float, float, tuple[Coordinate, ...]] | None:
    """One HERE request between two anchors. With ``avoid_tolls`` it
    returns the non-toll alternative; without it, the normal route over
    the same span (the baseline to compare against). Returns
    (duration_min, distance_km, polyline_coords) or None on failure.
    """
    cached = _cached(anchor_before, anchor_after, avoid_tolls)
    if cached is not None:
        return cached
    params: dict[str, Any] = {
        "transportMode": "car",
        "origin": f"{anchor_before.lat:.5f},{anchor_before.lon:.5f}",
        "destination": f"{anchor_after.lat:.5f},{anchor_after.lon:.5f}",
        "return": "summary,polyline" if avoid_tolls else "summary",
        "apiKey": key,
    }
    if avoid_tolls:
        params["avoid[features]"] = "tollRoad"
    try:
        r = await client.get(_ENDPOINT, params=params)
    except Exception as exc:  # noqa: BLE001
        _log.warning("HERE toll-alt request failed: %r", exc)
        return None
    if r.status_code != 200:
        _log.warning(
            "HERE toll-alt HTTP %s: %s", r.status_code, r.text[:200],
        )
        return None
    try:
        body = r.json()
    except ValueError:
        return None
    routes = body.get("routes") or []
    if not routes:
        return None
    total_duration_s = 0.0
    total_length_m = 0.0
    coords: list[Coordinate] = []
    for section in routes[0].get("sections") or []:
        summary = section.get("summary") or {}
        total_duration_s += float(summary.get("duration") or 0)
        total_length_m += float(summary.get("length") or 0)
        poly = section.get("polyline")
        if poly:
            decoded = _decode_flexpolyline(poly)
            if decoded:
                coords.extend(decoded)
    if avoid_tolls and not coords:
        return None
    if total_duration_s <= 0 or total_length_m <= 0:
        return None
    coords = _decimate(coords)
    duration_min = total_duration_s / 60.0
    distance_km = total_length_m / 1000.0
    _remember(
        anchor_before, anchor_after, duration_min, distance_km,
        tuple(coords), avoid_tolls,
    )
    return (duration_min, distance_km, tuple(coords))


def _decode_flexpolyline(encoded: str) -> list[Coordinate]:
    """Decode a HERE Flexible Polyline string into (lat, lon)
    Coordinates. Wraps the `flexpolyline` library so this file is
    the only import site (easy to swap the impl later).
    """
    try:
        from flexpolyline import decode  # type: ignore[import-not-found]
    except ImportError:
        _log.warning(
            "flexpolyline not installed — toll-alt geometry unavailable",
        )
        return []
    try:
        raw = decode(encoded)
    except Exception as exc:  # noqa: BLE001
        _log.warning("flexpolyline decode failed: %r", exc)
        return []
    out: list[Coordinate] = []
    for row in raw:
        try:
            lat, lon = float(row[0]), float(row[1])
        except (TypeError, ValueError, IndexError):
            continue
        out.append(Coordinate(lat=lat, lon=lon))
    return out


async def _enrich_skips(
    route: Route,
    skips: tuple[PartialTollSkip, ...],
    *,
    average_kmh: float = 125.0,
) -> tuple[PartialTollSkip, ...]:
    """For each skip, replace the heuristic penalty + generic
    ``extra_distance_km`` with real HERE-derived numbers and attach
    the alternative polyline geometry. Returns a NEW tuple — never
    mutates the input skips.

    ``average_kmh`` is the assumed cruising speed on the original
    TOLL motorway for the same span (~125 km/h covers EU motorway
    reality: 130 in FR, 120 in ES/IT, 110 with rain). Used only for
    the delta calculation — the mobile client shows the delta, not
    the absolute values.
    """
    key = _api_key()
    if not key or not skips:
        return skips
    if not route.geometry:
        return skips

    walker = _PolylineWalker(route)
    if walker.anchor(0) is None:
        return skips

    async def _for_skip(skip: PartialTollSkip) -> PartialTollSkip:
        km0 = skip.distance_from_origin_km
        long_span = _is_long_span(skip)
        if long_span:
            # Closed-system toll (ticket in, ticket out): the fare covers
            # the whole stretch between the two gates, so the detour has
            # to be measured over that stretch. A window around the entry
            # says nothing about it (it produced "+3 min" for a 340 km
            # motorway section).
            anchor_before = skip.coordinate
            anchor_after = skip.exit_coordinate
            span_from_km = km0
            span_to_km = skip.end_distance_from_origin_km or km0
        else:
            anchor_before = walker.anchor(km0 - _ANCHOR_KM)
            anchor_after = walker.anchor(km0 + _ANCHOR_KM)
            span_from_km = km0 - _ANCHOR_KM
            span_to_km = km0 + _ANCHOR_KM
        if anchor_before is None or anchor_after is None:
            return skip
        # Deduplicate anchors that landed on the same coord (short
        # trip / anchor over-shot the endpoints).
        if anchor_before.lat == anchor_after.lat and \
                anchor_before.lon == anchor_after.lon:
            return skip
        timeout = _TIMEOUT_LONG_S if long_span else _TIMEOUT_S
        async with httpx.AsyncClient(timeout=timeout) as client:
            result = await _fetch_alternative(
                client, anchor_before, anchor_after, key,
            )
            baseline = None
            if long_span and result is not None:
                # Same span on the normal (tolled) route, from HERE too,
                # so both numbers use the same speed model.
                baseline = await _fetch_alternative(
                    client, anchor_before, anchor_after, key,
                    avoid_tolls=False,
                )
        if result is None:
            return skip
        if long_span and baseline is None:
            return skip  # cannot verify → dropped by the caller
        alt_duration_min, alt_distance_km, geom = result
        if baseline is not None:
            original_duration_min, original_distance_km, _ = baseline
        else:
            # Real polyline distance for the ORIGINAL toll leg between
            # the anchors — curvy roads are longer than the great-circle
            # `2 * _ANCHOR_KM` estimate. Missing → fall back to the
            # 30 km straight-line default.
            original_distance_km = walker.distance_between(
                span_from_km, span_to_km,
            )
            if original_distance_km <= 0:
                original_distance_km = 2.0 * _ANCHOR_KM
            original_duration_min = (
                original_distance_km / average_kmh
            ) * 60.0
        # Guard against negative deltas (a shorter alt route wraps
        # to 0). A FLOOR of ~2 min / 0.5 km reflects the real cost
        # of exiting + re-entering the motorway even when the
        # secondary parallel road happens to be similar in length.
        penalty_min = max(
            2.0,
            alt_duration_min - original_duration_min,
        )
        extra_km = max(
            0.5,
            alt_distance_km - original_distance_km,
        )
        penalty_rounded = round(penalty_min, 1)
        return replace(
            skip,
            time_penalty_minutes=penalty_rounded,
            extra_distance_km=round(extra_km, 1),
            alternative_geometry=geom,
            # The heuristic flagged this before the real penalty was
            # known; decide again with the measured number.
            worth_it=(
                skip.savings_eur >= _WORTH_IT_MIN_SAVINGS_EUR
                and penalty_rounded <= _WORTH_IT_MAX_PENALTY_MINUTES
            ),
        )

    return tuple(await asyncio.gather(*(_for_skip(s) for s in skips)))


def _is_long_span(skip: PartialTollSkip) -> bool:
    """True for a closed-system toll whose gates are far apart, i.e.
    one fare covering a whole motorway stretch."""
    if skip.exit_coordinate is None or skip.end_distance_from_origin_km is None:
        return False
    return (
        skip.end_distance_from_origin_km - skip.distance_from_origin_km
        > 2.0 * _ANCHOR_KM
    )


async def enrich_skips_with_alternatives(
    route: Route,
    skips: tuple[PartialTollSkip, ...],
    *,
    average_kmh: float = 125.0,
) -> tuple[PartialTollSkip, ...]:
    """Attach real HERE detour numbers to each skip (see ``_enrich_skips``)
    and drop the long closed-system stretches whose detour could not be
    measured. The generic "+5 min / +2.5 km" default only makes sense for
    a single barrier; showing it for a stretch of hundreds of km would be
    a made-up number, so those are not offered at all."""
    enriched = await _enrich_skips(route, skips, average_kmh=average_kmh)
    return tuple(
        s for s in enriched
        if not (_is_long_span(s) and not s.alternative_geometry)
    )

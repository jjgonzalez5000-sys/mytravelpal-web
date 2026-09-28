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
from app.services.partial_toll_skips import PartialTollSkip

_log = logging.getLogger(__name__)

_ENDPOINT = "https://router.hereapi.com/v8/routes"
_TIMEOUT_S = 8.0

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

    def anchor(self, km: float) -> Coordinate | None:
        """Return the polyline point closest to `km` from origin.
        None when the route has no geometry."""
        if not self._pts:
            return None
        target = max(0.0, min(km, self._cum[-1]))
        # Binary search — the cum list is monotonically non-decreasing.
        lo, hi = 0, len(self._cum) - 1
        while lo < hi:
            mid = (lo + hi) // 2
            if self._cum[mid] < target:
                lo = mid + 1
            else:
                hi = mid
        return self._pts[lo]


def _cache_key(a: Coordinate, b: Coordinate) -> tuple[float, float, float, float]:
    return (round(a.lat, 3), round(a.lon, 3), round(b.lat, 3), round(b.lon, 3))


def _cached(a: Coordinate, b: Coordinate) -> tuple | None:
    import time
    entry = _CACHE.get(_cache_key(a, b))
    if entry is None:
        return None
    duration_min, distance_km, geom, ts = entry
    if time.time() - ts > _CACHE_TTL_S:
        _CACHE.pop(_cache_key(a, b), None)
        return None
    return (duration_min, distance_km, geom)


def _remember(
    a: Coordinate,
    b: Coordinate,
    duration_min: float,
    distance_km: float,
    geom: tuple[Coordinate, ...],
) -> None:
    import time
    _CACHE[_cache_key(a, b)] = (duration_min, distance_km, geom, time.time())


async def _fetch_alternative(
    client: httpx.AsyncClient,
    anchor_before: Coordinate,
    anchor_after: Coordinate,
    key: str,
) -> tuple[float, float, tuple[Coordinate, ...]] | None:
    """One HERE request between two anchors avoiding tolls. Returns
    (duration_min, distance_km, polyline_coords) or None on failure.
    """
    cached = _cached(anchor_before, anchor_after)
    if cached is not None:
        return cached
    params: dict[str, Any] = {
        "transportMode": "car",
        "origin": f"{anchor_before.lat:.5f},{anchor_before.lon:.5f}",
        "destination": f"{anchor_after.lat:.5f},{anchor_after.lon:.5f}",
        "return": "summary,polyline",
        "avoid[features]": "tollRoad",
        "apiKey": key,
    }
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
    if not coords:
        return None
    duration_min = total_duration_s / 60.0
    distance_km = total_length_m / 1000.0
    _remember(
        anchor_before, anchor_after, duration_min, distance_km, tuple(coords),
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


async def enrich_skips_with_alternatives(
    route: Route,
    skips: tuple[PartialTollSkip, ...],
    *,
    average_kmh: float = 110.0,
) -> tuple[PartialTollSkip, ...]:
    """For each skip, replace the heuristic penalty + generic
    ``extra_distance_km`` with real HERE-derived numbers and attach
    the alternative polyline geometry. Returns a NEW tuple — never
    mutates the input skips.

    ``average_kmh`` is the assumed speed on the original toll route
    for the same span, used to derive the ORIGINAL leg's duration
    without another HERE call. Rough but adequate — the interesting
    number for the driver is the DELTA, not either absolute figure.
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
        anchor_before = walker.anchor(km0 - _ANCHOR_KM)
        anchor_after = walker.anchor(km0 + _ANCHOR_KM)
        if anchor_before is None or anchor_after is None:
            return skip
        # Deduplicate anchors that landed on the same coord (short
        # trip / anchor over-shot the endpoints).
        if anchor_before.lat == anchor_after.lat and \
                anchor_before.lon == anchor_after.lon:
            return skip
        async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
            result = await _fetch_alternative(
                client, anchor_before, anchor_after, key,
            )
        if result is None:
            return skip
        alt_duration_min, alt_distance_km, geom = result
        # Original leg duration ~= 2 * anchor_km at average_kmh.
        original_duration_min = (2.0 * _ANCHOR_KM / average_kmh) * 60.0
        original_distance_km = 2.0 * _ANCHOR_KM
        penalty_min = max(0.0, alt_duration_min - original_duration_min)
        extra_km = max(0.0, alt_distance_km - original_distance_km)
        return replace(
            skip,
            time_penalty_minutes=round(penalty_min, 1),
            extra_distance_km=round(extra_km, 1),
            alternative_geometry=geom,
        )

    return tuple(await asyncio.gather(*(_for_skip(s) for s in skips)))

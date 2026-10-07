"""HERE Places fallback for rest-stop enrichment.

Overpass is the primary source (`rest_stops_enrichment.py`) because
it's free + covers a lot of OSM-tagged autoroute service areas. When
Overpass returns nothing named for a given rest-stop coord (sparse
OSM regions like the A-31 Toledo → Murcia corridor), we ask HERE
Browse to name a nearby service area / rest area / restaurant / cafe
so the driver at least sees a real POI.

HERE free tier: 30k requests/mo. With ~2 rest stops per plan and the
fallback firing only when Overpass returned unnamed (roughly 20-30 %
of stops today), a closed beta of ~50 daily-active users well fits
inside the free tier.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any

import httpx

from app.domain import Coordinate, RestStopType

_log = logging.getLogger(__name__)

_ENDPOINT = "https://browse.search.hereapi.com/v1/browse"
_TIMEOUT_S = 5.0
_TTL_S = 24 * 3600
# HERE Places categories relevant to a rest break. Order matters —
# we prefer service_area > rest_area > restaurant > cafe > fuel.
# 700-7900-0116 Rest Area · 700-7900-0128 Service Area
# 100-1000-0000 Restaurant · 100-1200-0000 Coffee/Tea
# 700-7600-0000 Automotive Fueling (fallback so we always have SOMETHING)
_CATEGORIES = (
    "700-7900-0128,700-7900-0116,100-1000-0000,100-1200-0000,700-7600-0000"
)

_CACHE: dict[str, tuple[float, dict[str, Any] | None]] = {}

# HERE category id → our RestStopType. First matching category wins.
_CATEGORY_MAP: tuple[tuple[str, RestStopType], ...] = (
    ("700-7900-0128", RestStopType.SERVICE_AREA),
    ("700-7900-0116", RestStopType.REST_AREA),
    ("100-1000", RestStopType.REST_AREA),      # any restaurant subcat
    ("100-1200", RestStopType.REST_AREA),      # any coffee/tea subcat
    ("700-7600", RestStopType.GAS_STATION),    # any fuel subcat
)


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


def _cache_key(lat: float, lon: float, radius_m: int) -> str:
    return f"{round(lat, 3)},{round(lon, 3)}|{radius_m}"


def _classify(item: dict) -> RestStopType:
    for cat in item.get("categories") or []:
        cid = cat.get("id") or ""
        for prefix, kind in _CATEGORY_MAP:
            if cid.startswith(prefix):
                return kind
    return RestStopType.UNKNOWN


async def find_rest_stop_near(
    coord: Coordinate,
    *,
    radius_m: int = 15000,
    client: httpx.AsyncClient | None = None,
) -> dict[str, Any] | None:
    """Return the best-ranked named rest-stop candidate near `coord`,
    or None when HERE is unavailable / no results / API key missing.

    Shape: `{name, coordinate, stop_type, here_id, here_address}`.
    Ranking mirrors the Overpass path: SERVICE_AREA > REST_AREA >
    GAS_STATION, tie-broken by distance.
    """
    key = _api_key()
    if not key:
        return None
    ck = _cache_key(coord.lat, coord.lon, radius_m)
    cached = _CACHE.get(ck)
    if cached is not None:
        ts, val = cached
        if time.monotonic() - ts < _TTL_S:
            return val

    params = {
        "at": f"{coord.lat:.5f},{coord.lon:.5f}",
        # `in=circle` restricts to the radius. Overrides `at` when both
        # present in v1/browse; the `at` alone acts as a bias.
        "in": f"circle:{coord.lat:.5f},{coord.lon:.5f};r={radius_m}",
        "categories": _CATEGORIES,
        "limit": "20",
        "apiKey": key,
    }
    owns_client = client is None
    http = client or httpx.AsyncClient(timeout=_TIMEOUT_S)
    try:
        r = await http.get(_ENDPOINT, params=params)
    except Exception as exc:  # noqa: BLE001
        _log.warning("HERE Browse rest-stop failed at %s: %r", ck, exc)
        return None
    finally:
        if owns_client:
            await http.aclose()

    if r.status_code != 200:
        _log.warning(
            "HERE Browse HTTP %s for %s: %s",
            r.status_code, ck, r.text[:200],
        )
        return None
    try:
        body = r.json()
    except ValueError:
        return None
    items = body.get("items") or []
    if not items:
        _CACHE[ck] = (time.monotonic(), None)
        return None

    # Rank by (priority, distance). HERE returns items sorted by
    # distance already; we re-sort so a nearby restaurant doesn't
    # beat a slightly-farther service area.
    _priority = {
        RestStopType.SERVICE_AREA: 0,
        RestStopType.REST_AREA: 1,
        RestStopType.GAS_STATION: 2,
        RestStopType.UNKNOWN: 99,
    }
    best: tuple[int, float] = (99, float("inf"))
    winner: dict[str, Any] | None = None
    for it in items:
        kind = _classify(it)
        if kind == RestStopType.UNKNOWN:
            continue
        pos = it.get("position") or {}
        lat = pos.get("lat")
        lon = pos.get("lng")
        if lat is None or lon is None:
            continue
        distance = float(it.get("distance") or 0)
        score = (_priority[kind], distance)
        if score < best:
            best = score
            addr = it.get("address") or {}
            winner = {
                "name": str(it.get("title") or ""),
                "coordinate": Coordinate(lat=float(lat), lon=float(lon)),
                "stop_type": kind,
                "here_id": str(it.get("id") or ""),
                "here_address": str(addr.get("label") or ""),
            }

    _CACHE[ck] = (time.monotonic(), winner)
    return winner

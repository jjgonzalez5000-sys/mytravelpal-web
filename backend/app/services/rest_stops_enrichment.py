"""Enrich `RestStop` objects with kid / pet / RV amenity flags.

We look up OSM tags via Overpass around each rest-stop coordinate. The
enrichment is entirely optional: an Overpass timeout or empty response
degrades gracefully — the stops flow through unchanged with all three
flags set to `False`. We NEVER guess a flag; absent tag = absent flag.

Design notes:
- Single Overpass query per plan (all coords fanned out via
  `around:` union), not one query per stop. On a 3-stop plan this
  saves ~15 s vs. sequential lookups.
- Response cached in-memory keyed by rounded coord (24 h TTL) so
  a re-plan for the same route doesn't re-hit Overpass.
- Tags mapped: kid → `playground=yes`, `changing_table=yes`,
  `baby_feeding=yes`. Pet → `dog_area=yes`, `dog_park=yes`,
  `amenity=dog_toilet`. RV → `caravan=yes`, `motorhome=yes`,
  `sanitary_dump_station=yes`.
"""

from __future__ import annotations

import logging
import time
from dataclasses import replace

from app.domain import Coordinate, RestStop, RestStopType
from app.providers.overpass import (
    _CORRIDOR_METERS,
    _new_overpass_client,
    _query,
)

_log = logging.getLogger(__name__)

# ~800 m radius around each rest-stop coord. Wider than a strict
# match so a stop marker sitting on the highway centerline still
# picks up the tags of the actual service-area POI a couple of
# hundred meters off the road. Kept below `_CORRIDOR_METERS` (3 km)
# so we don't drag in an unrelated village a km away.
_REST_STOP_RADIUS_M = 800

# 24 h cache — OSM amenity tags change over days/weeks, not
# minutes. Key is (round(lat, 3), round(lon, 3)) so nearby coords
# on repeated plans hit the same cache entry.
_CACHE_TTL_S = 24 * 60 * 60
# The cache now holds the full enrichment payload — flags AND the
# closest amenity's name / type — so a re-plan for the same route
# skips Overpass entirely.
_CACHE: dict[tuple[float, float], tuple[float, dict]] = {}


def _cache_key(coord: Coordinate) -> tuple[float, float]:
    return (round(coord.lat, 3), round(coord.lon, 3))


def _cached_flags(coord: Coordinate) -> dict | None:
    entry = _CACHE.get(_cache_key(coord))
    if entry is None:
        return None
    ts, payload = entry
    if time.time() - ts > _CACHE_TTL_S:
        _CACHE.pop(_cache_key(coord), None)
        return None
    return payload


def _remember(coord: Coordinate, payload: dict) -> None:
    _CACHE[_cache_key(coord)] = (time.time(), payload)


_TYPE_FROM_TAGS: tuple[tuple[str, str, RestStopType], ...] = (
    # (tag_key, tag_value, resulting stop_type) — first match wins.
    ("highway", "services", RestStopType.SERVICE_AREA),
    ("highway", "rest_area", RestStopType.REST_AREA),
    ("amenity", "fuel", RestStopType.GAS_STATION),
    ("tourism", "caravan_site", RestStopType.CARAVAN_SITE),
    ("amenity", "parking", RestStopType.PARKING),
)


def _stop_type_from_tags(tags: dict) -> RestStopType:
    for key, value, kind in _TYPE_FROM_TAGS:
        if tags.get(key) == value:
            return kind
    return RestStopType.UNKNOWN


def _yes(value: str | None) -> bool:
    return (value or "").lower() in {"yes", "designated", "true", "1"}


def _classify(tags: dict) -> dict[str, bool]:
    """Map OSM tags → the three amenity flags. All default False."""
    amenity = tags.get("amenity")
    kid = (
        _yes(tags.get("playground"))
        or _yes(tags.get("changing_table"))
        or _yes(tags.get("baby_feeding"))
        or amenity == "playground"
    )
    pet = (
        _yes(tags.get("dog_area"))
        or _yes(tags.get("dog_park"))
        or amenity in {"dog_toilet", "dog_park"}
    )
    rv = (
        _yes(tags.get("caravan"))
        or _yes(tags.get("motorhome"))
        or _yes(tags.get("sanitary_dump_station"))
    )
    return {"kid_friendly": kid, "pet_friendly": pet, "rv_friendly": rv}


def _haversine_m(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km
    return _haversine_km(a, b) * 1000.0


async def enrich_rest_stops(
    stops: tuple[RestStop, ...],
) -> tuple[RestStop, ...]:
    """Return `stops` with `kid_friendly` / `pet_friendly` / `rv_friendly`
    filled from OSM. Original ordering preserved.

    Empty input → empty output. Any Overpass error → the original
    stops are returned unchanged (flags stay `False`), never
    raising to the caller. Rest stops are safety-critical and
    should never fail a `/plan` request.
    """
    if not stops:
        return stops

    # Fast path: everything cached.
    cache_hits: dict[int, dict[str, bool]] = {}
    misses: list[tuple[int, RestStop]] = []
    for idx, s in enumerate(stops):
        hit = _cached_flags(s.coordinate)
        if hit is not None:
            cache_hits[idx] = hit
        else:
            misses.append((idx, s))

    fresh_flags: dict[int, dict] = {}
    if misses:
        try:
            fresh_flags = await _fetch_flags_for(misses)
            _log.info(
                "rest-stop enrichment: %d/%d stops enriched (%d with name)",
                sum(1 for v in fresh_flags.values() if any(v.get(k, False) for k in ("kid_friendly", "pet_friendly", "rv_friendly")) or v.get("name")),
                len(misses),
                sum(1 for v in fresh_flags.values() if v.get("name")),
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning(
                "rest-stop enrichment failed (%d stops): %r",
                len(misses), exc,
            )
            fresh_flags = {}
        # Remember misses that came back with an answer (even the
        # all-False / no-name case — a genuine "nothing here" is
        # worth caching so we don't retry every plan).
        for idx, stop in misses:
            _remember(
                stop.coordinate,
                fresh_flags.get(idx, _empty_payload()),
            )

    out: list[RestStop] = []
    for idx, s in enumerate(stops):
        payload = cache_hits.get(idx) or fresh_flags.get(idx) or _empty_payload()
        out.append(
            replace(
                s,
                kid_friendly=payload.get("kid_friendly", False),
                pet_friendly=payload.get("pet_friendly", False),
                rv_friendly=payload.get("rv_friendly", False),
                name=payload.get("name") or s.name,
                stop_type=payload.get("stop_type") or s.stop_type,
            )
        )
    return tuple(out)


def _empty_payload() -> dict:
    return {
        "kid_friendly": False,
        "pet_friendly": False,
        "rv_friendly": False,
        "name": None,
        "stop_type": RestStopType.UNKNOWN,
    }


async def _fetch_flags_for(
    misses: list[tuple[int, RestStop]],
) -> dict[int, dict]:
    """Per-stop Overpass queries fanned out in parallel.

    Earlier version sent a single union query around ALL coords at
    once. Overpass evaluates `around:` per-subquery per-coord, so a
    3-stop plan with 4 subqueries × 3 coords = 12 spatial ops on the
    Iberia bbox. Every public mirror timed out at 15-70 s.

    Splitting into N tiny queries (one per stop) trades a bit of
    request overhead for a much cheaper server-side scan — each hits
    a ~800 m circle around a single coord. Overpass mirrors return
    each in ~1-3 s comfortably. `asyncio.gather` keeps total
    wall-time close to the slowest single query, not the sum.
    """
    import asyncio

    async def _one(idx: int, stop: RestStop) -> tuple[int, dict]:
        return (idx, await _fetch_single_stop_amenities(stop))

    results = await asyncio.gather(
        *(_one(idx, s) for idx, s in misses),
        return_exceptions=True,
    )
    per_stop: dict[int, dict] = {}
    for entry in results:
        if isinstance(entry, tuple):
            idx, payload = entry
            per_stop[idx] = payload
    return per_stop


async def _fetch_single_stop_amenities(stop: RestStop) -> dict:
    """One tiny Overpass query around a single rest-stop coord.
    Returns the aggregated payload the caller expects (flags + name
    + stop_type). Never raises — a mirror failure produces the empty
    payload so the caller can treat the stop as un-enriched.
    """
    around = f"around:{_REST_STOP_RADIUS_M},{stop.coordinate.lat:.5f},{stop.coordinate.lon:.5f}"
    # Union of all OSM node/way types that plausibly carry a
    # kid/pet/rv-relevant tag. `highway=rest_area|services` is the
    # anchor; we also pull `amenity=playground|dog_park|dog_toilet`
    # because those are usually mapped as separate nodes NEXT to
    # a service area, not on the service-area polygon itself.
    # Lean query: nodes only + the highest-value tag families. The
    # earlier version fanned out 15 subqueries × N coords which timed
    # out on Overpass main (68 s server-side). Nodes ONLY halves the
    # scan cost vs including `way` — service_area polygons are almost
    # always also mapped as a labelled node these days, so we lose
    # very little. amenity=fuel is by definition a node.
    query = f"""
[out:json][timeout:15];
(
  node["highway"~"rest_area|services"]({around});
  node["amenity"="fuel"]({around});
  node["tourism"="caravan_site"]({around});
  node["amenity"~"playground|dog_park|dog_toilet"]({around});
);
out center 200;
"""
    client = _new_overpass_client()
    try:
        elements = await _query(client, query)
    finally:
        await client.aclose()
    if not elements:
        return _empty_payload()

    payload: dict = _empty_payload()
    # Ranking so a service area beats a gas station when they're
    # roughly equidistant — a full service area is more useful for a
    # break than a bare fuel pump. Lower index = higher priority.
    _TYPE_PRIORITY = {
        RestStopType.SERVICE_AREA: 0,
        RestStopType.REST_AREA: 1,
        RestStopType.GAS_STATION: 2,
        RestStopType.CARAVAN_SITE: 3,
        RestStopType.PARKING: 4,
        RestStopType.UNKNOWN: 99,
    }
    best_name_score: tuple[int, float] = (99, float("inf"))

    for el in elements:
        coord = _element_coord(el)
        if coord is None:
            continue
        d = _haversine_m(coord, stop.coordinate)
        if d > _REST_STOP_RADIUS_M:
            continue
        tags = el.get("tags") or {}
        flags = _classify(tags)
        for k, v in flags.items():
            if v:
                payload[k] = True
        # Caravan site is implicit rv_friendly.
        if tags.get("tourism") == "caravan_site":
            payload["rv_friendly"] = True
        # Name + type: keep the highest-priority typed amenity, tie
        # break by proximity.
        name = tags.get("name") or tags.get("brand")
        kind = _stop_type_from_tags(tags)
        if name and kind != RestStopType.UNKNOWN:
            score = (_TYPE_PRIORITY[kind], d)
            if score < best_name_score:
                best_name_score = score
                payload["name"] = str(name)
                payload["stop_type"] = kind

    return payload


def _element_coord(el: dict) -> Coordinate | None:
    if el.get("type") == "node":
        lat = el.get("lat")
        lon = el.get("lon")
    else:
        center = el.get("center") or {}
        lat = center.get("lat")
        lon = center.get("lon")
    if lat is None or lon is None:
        return None
    try:
        return Coordinate(lat=float(lat), lon=float(lon))
    except (TypeError, ValueError):
        return None

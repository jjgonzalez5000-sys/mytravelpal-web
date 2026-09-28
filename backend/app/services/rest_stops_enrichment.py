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

from app.domain import Coordinate, RestStop, RestStopType, TripProfile, VehicleType
from app.providers.overpass import (
    _CORRIDOR_METERS,
    _new_overpass_client,
    _query,
)

_log = logging.getLogger(__name__)

# ~8 km radius around each rest-stop coord. The anchor from
# `compute_rest_stops` is a pure km-along-route mark that lands
# wherever the driver has been 2 h — usually near but not exactly
# on a service area. 8 km gives the enrichment room to shift the
# stop onto an actual amenity even when the closest service area
# is one exit away. Max detour cost at 100 km/h: ~5 min each way
# ~= 10 min round trip. A driver who was going to pause 45 min at
# a random highway coord will happily add 10 min to end up at a
# real place with toilets + coffee.
_REST_STOP_RADIUS_M = 8000

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
    profile: TripProfile | None = None,
) -> tuple[RestStop, ...]:
    """Return `stops` with `kid_friendly` / `pet_friendly` / `rv_friendly`
    + `name` + `stop_type` + optionally SHIFTED `coordinate` when a
    better-matching amenity was found nearby.

    When `profile` is given, the enrichment scorer boosts amenities
    that match the traveller's prefs (kid_friendly for `has_kids`,
    pet_friendly for `has_pets`, rv_friendly for RV vehicles) so the
    picked stop reflects who's actually in the car.

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
            fresh_flags = await _fetch_flags_for(misses, profile)
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
        # Only cache payloads that carry SOMETHING — either a name,
        # a stop_type, or at least one amenity flag. Empty payloads
        # are indistinguishable from a silent Overpass failure (every
        # mirror timed out → we got zero elements back), so caching
        # them for 24 h means a single bad Overpass moment locks the
        # coord to "unknown" for a day even after the mirrors recover.
        # Retrying on the next plan costs one small Overpass query
        # per coord — cheap.
        for idx, stop in misses:
            payload = fresh_flags.get(idx)
            if payload is None:
                continue
            has_signal = (
                payload.get("name")
                or payload.get("stop_type") not in (None, RestStopType.UNKNOWN)
                or any(payload.get(k, False) for k in (
                    "kid_friendly", "pet_friendly", "rv_friendly"
                ))
            )
            if has_signal:
                _remember(stop.coordinate, payload)

    out: list[RestStop] = []
    # Previous behaviour DROPPED a stop when Overpass responded but
    # matched no typed amenity nearby ("prefer no stop over stop-in-
    # the-middle-of-the-road", 2026-09-27 tester feedback).
    #
    # That caused a cascading bug on long trips (2026-09-28 tester:
    # Toledo → Turda RO): Overpass frequently returns empty for
    # rural corridor coords, so those rest_stops disappeared from
    # the enriched list — and `_extend_meals_for_day` in
    # `trip_optimizations.py` needs a rest_stop near each meal
    # target to schedule the meal. Result: days 4-6 shipped with
    # zero meals, zero rest stops, zero everything.
    #
    # Fix: NEVER drop rest_stops in the backend. Keep the raw
    # coord + name=None + stop_type=UNKNOWN when Overpass didn't
    # match, so meal scheduling can still anchor on the km-along-
    # route mark. The frontend's `_restStopIsReliable` helper is
    # already filtering unknown / unnamed rest_stops from the
    # DISPLAY layer — that gives the same "no bad stops shown to
    # driver" outcome without starving the multi-day scheduler.
    for idx, s in enumerate(stops):
        payload = cache_hits.get(idx) or fresh_flags.get(idx) or _empty_payload()
        shifted_coord = payload.get("coordinate") or s.coordinate
        candidate = replace(
            s,
            coordinate=shifted_coord,
            kid_friendly=payload.get("kid_friendly", False),
            pet_friendly=payload.get("pet_friendly", False),
            rv_friendly=payload.get("rv_friendly", False),
            name=payload.get("name") or s.name,
            stop_type=payload.get("stop_type") or s.stop_type,
        )
        out.append(candidate)
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
    profile: TripProfile | None,
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
        return (idx, await _fetch_single_stop_amenities(stop, profile))

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


async def _fetch_single_stop_amenities(
    stop: RestStop,
    profile: TripProfile | None,
) -> dict:
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
    # Pref-derived bonuses to bring "matches who's in the car" up in
    # the ranking. Bonus is a negative number so subtracting from
    # priority (lower = better) makes the candidate outrank generic
    # equivalents. A kid-friendly service area for a family
    # (priority 0 - 2 = -2) beats a plain service area (0) even
    # when the plain one is closer by a few hundred meters.
    has_kids = bool(getattr(profile, "has_kids", False)) if profile else False
    has_pets = bool(getattr(profile, "has_pets", False)) if profile else False
    is_rv = (
        profile is not None
        and getattr(getattr(profile, "vehicle", None), "type", None)
        == VehicleType.CAMPER
    )

    def _pref_bonus(kind: RestStopType, tags: dict) -> int:
        bonus = 0
        # Prefer an actual caravan site for RV travellers over a
        # generic gas station even if it's a bit farther.
        if is_rv and kind == RestStopType.CARAVAN_SITE:
            bonus += 3
        # A kid-tagged service area for a family beats a plain one.
        if has_kids and _yes(tags.get("playground")) or tags.get("amenity") == "playground":
            bonus += 2
        if has_pets and (
            _yes(tags.get("dog_area"))
            or tags.get("amenity") in {"dog_park", "dog_toilet"}
        ):
            bonus += 2
        if is_rv and (
            _yes(tags.get("motorhome"))
            or _yes(tags.get("caravan"))
            or _yes(tags.get("sanitary_dump_station"))
        ):
            bonus += 2
        return bonus

    # Best score is a triple (priority_minus_bonus, distance_m,
    # index-in-elements) — lower wins on lexicographic order.
    best_name_score: tuple[int, float] = (99, float("inf"))
    winner_coord: Coordinate | None = None

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
        # break by proximity. Pref bonus lowers effective priority so
        # a "matches my prefs" candidate can outrank a technically
        # higher-priority-but-generic one.
        name = tags.get("name") or tags.get("brand")
        kind = _stop_type_from_tags(tags)
        if name and kind != RestStopType.UNKNOWN:
            effective_priority = _TYPE_PRIORITY[kind] - _pref_bonus(kind, tags)
            score = (effective_priority, d)
            if score < best_name_score:
                best_name_score = score
                payload["name"] = str(name)
                payload["stop_type"] = kind
                winner_coord = coord

    # Ship the winner's coord back so `enrich_rest_stops` can shift
    # the anchor onto the actual amenity (max ~3 km detour). Skip
    # when nothing named matched — keep the original anchor.
    if winner_coord is not None:
        payload["coordinate"] = winner_coord

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

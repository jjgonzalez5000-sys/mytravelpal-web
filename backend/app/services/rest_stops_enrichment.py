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
) -> dict[int, dict[str, bool]]:
    """One Overpass query around every miss coord. Elements returned
    are matched to the nearest miss coord (within radius) and their
    tags merged into a single per-stop flag dict.
    """
    coords = ",".join(
        f"{s.coordinate.lat:.5f},{s.coordinate.lon:.5f}"
        for _, s in misses
    )
    around = f"around:{_REST_STOP_RADIUS_M},{coords}"
    # Union of all OSM node/way types that plausibly carry a
    # kid/pet/rv-relevant tag. `highway=rest_area|services` is the
    # anchor; we also pull `amenity=playground|dog_park|dog_toilet`
    # because those are usually mapped as separate nodes NEXT to
    # a service area, not on the service-area polygon itself.
    query = f"""
[out:json][timeout:20];
(
  node["highway"~"rest_area|services"]({around});
  way["highway"~"rest_area|services"]({around});
  node["amenity"="fuel"]({around});
  way["amenity"="fuel"]({around});
  node["amenity"="parking"]["amenity"!="parking_space"]({around});
  way["amenity"="parking"]["amenity"!="parking_space"]({around});
  node["amenity"~"playground|dog_park|dog_toilet"]({around});
  node["tourism"="caravan_site"]({around});
  way["tourism"="caravan_site"]({around});
  node(around:{_REST_STOP_RADIUS_M},{coords})["playground"="yes"];
  node(around:{_REST_STOP_RADIUS_M},{coords})["changing_table"="yes"];
  node(around:{_REST_STOP_RADIUS_M},{coords})["dog_area"="yes"];
  node(around:{_REST_STOP_RADIUS_M},{coords})["motorhome"="yes"];
  node(around:{_REST_STOP_RADIUS_M},{coords})["caravan"="yes"];
  node(around:{_REST_STOP_RADIUS_M},{coords})["sanitary_dump_station"="yes"];
);
out center 300;
"""
    client = _new_overpass_client()
    try:
        elements = await _query(client, query)
    finally:
        await client.aclose()
    if not elements:
        return {}

    # Per-stop OR-accumulator: any nearby element that matches a
    # kid/pet/rv rule sets that flag to True for the closest miss.
    # Also track the CLOSEST typed amenity (name + stop_type) per
    # miss so the mobile client can show "Área de servicio X" or
    # "Repsol km 213" instead of a bare "km 2796".
    per_stop: dict[int, dict] = {
        idx: {
            "kid_friendly": False,
            "pet_friendly": False,
            "rv_friendly": False,
            "name": None,
            "stop_type": RestStopType.UNKNOWN,
            "_name_dist_m": float("inf"),
        }
        for idx, _ in misses
    }
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

    for el in elements:
        coord = _element_coord(el)
        if coord is None:
            continue
        # Nearest miss within radius wins. Ties are broken by first
        # miss (deterministic under equal distance).
        best_idx: int | None = None
        best_m = float("inf")
        for idx, stop in misses:
            d = _haversine_m(coord, stop.coordinate)
            if d < best_m and d <= _REST_STOP_RADIUS_M:
                best_m = d
                best_idx = idx
        if best_idx is None:
            continue
        tags = el.get("tags") or {}
        flags = _classify(tags)
        for k, v in flags.items():
            if v:
                per_stop[best_idx][k] = True
        # Name + type: prefer higher-priority types even when
        # slightly farther, tie-break by distance. Uses a synthetic
        # score = (priority_index, distance_m).
        name = tags.get("name") or tags.get("brand")
        kind = _stop_type_from_tags(tags)
        if name and kind != RestStopType.UNKNOWN:
            current_kind = per_stop[best_idx]["stop_type"]
            current_dist = per_stop[best_idx]["_name_dist_m"]
            new_score = (_TYPE_PRIORITY[kind], best_m)
            current_score = (
                _TYPE_PRIORITY.get(current_kind, 99), current_dist,
            )
            if new_score < current_score:
                per_stop[best_idx]["name"] = str(name)
                per_stop[best_idx]["stop_type"] = kind
                per_stop[best_idx]["_name_dist_m"] = best_m

    # Add caravan_site → rv_friendly explicitly (caravan_site
    # tourism doesn't come with a boolean; being one IS the flag).
    for el in elements:
        tags = el.get("tags") or {}
        if tags.get("tourism") == "caravan_site":
            coord = _element_coord(el)
            if coord is None:
                continue
            best_idx: int | None = None
            best_m = float("inf")
            for idx, stop in misses:
                d = _haversine_m(coord, stop.coordinate)
                if d < best_m and d <= _REST_STOP_RADIUS_M:
                    best_m = d
                    best_idx = idx
            if best_idx is not None:
                per_stop[best_idx]["rv_friendly"] = True

    # Strip the internal-only distance tracker before returning.
    for payload in per_stop.values():
        payload.pop("_name_dist_m", None)
    return per_stop


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

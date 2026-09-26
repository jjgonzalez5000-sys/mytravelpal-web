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

from app.domain import Coordinate, RestStop
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
_CACHE: dict[tuple[float, float], tuple[float, dict[str, bool]]] = {}


def _cache_key(coord: Coordinate) -> tuple[float, float]:
    return (round(coord.lat, 3), round(coord.lon, 3))


def _cached_flags(coord: Coordinate) -> dict[str, bool] | None:
    entry = _CACHE.get(_cache_key(coord))
    if entry is None:
        return None
    ts, flags = entry
    if time.time() - ts > _CACHE_TTL_S:
        _CACHE.pop(_cache_key(coord), None)
        return None
    return flags


def _remember(coord: Coordinate, flags: dict[str, bool]) -> None:
    _CACHE[_cache_key(coord)] = (time.time(), flags)


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

    fresh_flags: dict[int, dict[str, bool]] = {}
    if misses:
        try:
            fresh_flags = await _fetch_flags_for(misses)
        except Exception as exc:  # noqa: BLE001
            _log.warning(
                "rest-stop enrichment failed (%d stops): %r",
                len(misses), exc,
            )
            fresh_flags = {}
        # Remember misses that came back with an answer (even
        # all-False — a genuine "no amenity tags here" is worth
        # caching so we don't retry every plan).
        for idx, stop in misses:
            _remember(
                stop.coordinate,
                fresh_flags.get(idx, {
                    "kid_friendly": False,
                    "pet_friendly": False,
                    "rv_friendly": False,
                }),
            )

    out: list[RestStop] = []
    for idx, s in enumerate(stops):
        flags = cache_hits.get(idx) or fresh_flags.get(idx) or {}
        out.append(
            replace(
                s,
                kid_friendly=flags.get("kid_friendly", False),
                pet_friendly=flags.get("pet_friendly", False),
                rv_friendly=flags.get("rv_friendly", False),
            )
        )
    return tuple(out)


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
out center 200;
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
    per_stop: dict[int, dict[str, bool]] = {
        idx: {"kid_friendly": False, "pet_friendly": False, "rv_friendly": False}
        for idx, _ in misses
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

"""OSM Overpass provider for intermediate toll gate positions.

Queries the Overpass API for `barrier=toll_booth` nodes within the
bounding box of a toll section.  Results are cached in memory for 7 days
because gate positions change only when new roads open.

The provider is intentionally lightweight — it only cares about positions
and names, not fares (those come from HERE).  The intra_section_skips
service uses the gates to identify intermediate exit/re-entry points
within a single HERE toll section.
"""

from __future__ import annotations

import logging
import math
import time
from dataclasses import dataclass

import httpx

_log = logging.getLogger(__name__)

_OVERPASS_ENDPOINT = "https://overpass-api.de/api/interpreter"
_TIMEOUT_S = 28.0

# Cache: rounded-bbox key → (gate_list, timestamp)
# Bbox rounded to 0.2° (~22 km) to balance hit rate vs. scope.
_GATE_CACHE: dict[tuple[float, float, float, float], tuple[list["TollGate"], float]] = {}
_GATE_CACHE_TTL_S = 7 * 86400  # 7 days


@dataclass(frozen=True, slots=True)
class TollGate:
    lat: float
    lon: float
    name: str      # may be empty when OSM has no name tag
    osm_id: int
    operator: str  # OSM operator tag, e.g. "ASF", "APRR"; empty when absent


class OsmTollGateProvider:
    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def gates_in_section(
        self,
        entry_lat: float,
        entry_lon: float,
        exit_lat: float,
        exit_lon: float,
        *,
        buffer_deg: float = 0.15,
    ) -> list[TollGate]:
        """All toll gates within the bbox of a section, sorted entry→exit.

        `buffer_deg` expands the bbox so gates slightly off the motorway
        corridor are captured (~15 km at European latitudes).
        """
        if not (entry_lat and entry_lon and exit_lat and exit_lon):
            return []

        south = min(entry_lat, exit_lat) - buffer_deg
        north = max(entry_lat, exit_lat) + buffer_deg
        west = min(entry_lon, exit_lon) - buffer_deg
        east = max(entry_lon, exit_lon) + buffer_deg

        # Round bbox to 0.2° grid for cache coherence
        cache_key = (
            _round2(south), _round2(west),
            _round2(north), _round2(east),
        )
        cached = _GATE_CACHE.get(cache_key)
        if cached is not None:
            gates, ts = cached
            if time.time() - ts < _GATE_CACHE_TTL_S:
                # Filter to actual (unrounded) bbox
                return _filter_bbox(gates, south, west, north, east)

        gates = await self._fetch(south, west, north, east)
        _GATE_CACHE[cache_key] = (gates, time.time())
        return _filter_bbox(gates, south, west, north, east)

    async def _fetch(
        self, south: float, west: float, north: float, east: float,
    ) -> list[TollGate]:
        query = (
            f"[out:json][timeout:15];"
            f"("
            f'node["barrier"="toll_booth"]({south:.4f},{west:.4f},{north:.4f},{east:.4f});'
            f'way["barrier"="toll_booth"]({south:.4f},{west:.4f},{north:.4f},{east:.4f});'
            f");"
            f"out center;"
        )
        try:
            r = await self._client.get(
                _OVERPASS_ENDPOINT,
                params={"data": query},
                headers={
                    "User-Agent": "MyTravelPal/1.0 (road-trip planner)",
                    "Accept": "*/*",
                },
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("Overpass request failed: %r", exc)
            return []
        if r.status_code != 200:
            _log.warning("Overpass HTTP %s", r.status_code)
            return []
        try:
            body = r.json()
        except ValueError:
            return []

        gates: list[TollGate] = []
        seen: set[tuple[float, float]] = set()
        for el in body.get("elements") or []:
            # nodes have lat/lon directly; ways have a `center` object
            if el.get("type") == "node":
                lat, lon = float(el["lat"]), float(el["lon"])
            elif el.get("type") == "way" and el.get("center"):
                lat = float(el["center"]["lat"])
                lon = float(el["center"]["lon"])
            else:
                continue
            # Deduplicate gates within ~200 m of each other
            cell = (round(lat, 2), round(lon, 2))
            if cell in seen:
                continue
            seen.add(cell)
            tags = el.get("tags") or {}
            name = tags.get("name") or tags.get("ref") or ""
            operator = tags.get("operator") or tags.get("toll:operator") or ""
            gates.append(TollGate(
                lat=lat, lon=lon, name=name,
                osm_id=int(el.get("id") or 0),
                operator=operator,
            ))
        return gates


def _filter_bbox(
    gates: list[TollGate],
    south: float, west: float, north: float, east: float,
) -> list[TollGate]:
    return [
        g for g in gates
        if south <= g.lat <= north and west <= g.lon <= east
    ]


def _round2(v: float) -> float:
    return round(v / 0.2) * 0.2


def sort_gates_along_axis(
    gates: list[TollGate],
    entry_lat: float,
    entry_lon: float,
    exit_lat: float,
    exit_lon: float,
) -> list[TollGate]:
    """Sort gates so they appear in travel order (entry → exit).

    Projects each gate onto the entry→exit vector and sorts by
    that scalar.  Works for any orientation (N-S, E-W, diagonal).
    """
    dlat = exit_lat - entry_lat
    dlon = exit_lon - entry_lon
    norm = math.sqrt(dlat ** 2 + dlon ** 2) or 1.0

    def proj(g: TollGate) -> float:
        return ((g.lat - entry_lat) * dlat + (g.lon - entry_lon) * dlon) / norm

    return sorted(gates, key=proj)

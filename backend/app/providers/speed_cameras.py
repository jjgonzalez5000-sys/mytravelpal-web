"""Speed camera fetcher from OpenStreetMap via Overpass.

highway=speed_camera covers fixed radars. We also fetch:
- enforcement=speed  (same physical device, different tagging convention)
- highway=traffic_signals + camera=yes  (red-light cameras)

Data is OSM community-maintained — solid coverage in ES/FR/DE/IT/PT/BE/NL.
Cache TTL 24 h: camera positions change rarely; correctness > freshness.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from app.domain import Coordinate, Route
from app.providers.overpass import (
    _around_clause,
    _element_coord,
    _new_overpass_client,
    _query,
    _sample_corridor_points,
)
from app.providers.routing import _haversine_km

_log = logging.getLogger(__name__)

_CACHE_TTL_S = 86_400.0  # 24 h
# cache_key -> (fetched_at_monotonic, cameras)
_CACHE: dict[str, tuple[float, tuple["SpeedCamera", ...]]] = {}

_QUERY_TEMPLATE = """\
[out:json][timeout:15];
(
  node["highway"="speed_camera"]({around});
  node["enforcement"="speed"]({around});
  node["highway"="traffic_signals"]["camera"="yes"]({around});
);
out body;
"""


@dataclass(frozen=True, slots=True)
class SpeedCamera:
    coordinate: Coordinate
    distance_from_origin_km: float
    max_speed_kmh: int | None        # None = not tagged in OSM
    camera_type: str                  # "fixed" | "section_start" | "section_end" | "mobile_zone" | "traffic_light"
    direction: str | None             # "forward" | "backward" | None (both directions)


class SpeedCameraProvider:
    """Fetch speed cameras from OSM along a route corridor."""

    def __init__(self) -> None:
        self._client = _new_overpass_client()

    async def cameras_along(
        self, route: Route, corridor_km: float = 5.0,
    ) -> tuple[SpeedCamera, ...]:
        sample = _sample_corridor_points(route)
        radius_m = int(corridor_km * 1000)
        coords_str = ",".join(f"{p.lat:.5f},{p.lon:.5f}" for p in sample)
        around = f"around:{radius_m},{coords_str}"

        cache_key = around
        now = time.monotonic()
        cached = _CACHE.get(cache_key)
        if cached and (now - cached[0]) < _CACHE_TTL_S:
            _log.debug("speed_cameras: cache hit (%d cameras)", len(cached[1]))
            return cached[1]

        query = _QUERY_TEMPLATE.replace("{around}", around)
        elements = await _query(self._client, query)
        cameras = _parse_cameras(elements, route)
        _CACHE[cache_key] = (now, cameras)
        _log.info("speed_cameras: %d cameras cached for corridor", len(cameras))
        return cameras


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def _parse_cameras(
    elements: list[dict], route: Route,
) -> tuple[SpeedCamera, ...]:
    cameras: list[SpeedCamera] = []
    for el in elements:
        coord = _element_coord(el)
        if coord is None:
            continue
        tags = el.get("tags") or {}
        cameras.append(
            SpeedCamera(
                coordinate=coord,
                distance_from_origin_km=round(
                    _distance_from_origin_km(coord, route), 2
                ),
                max_speed_kmh=_parse_max_speed(tags),
                camera_type=_classify_camera_type(tags),
                direction=_parse_direction(tags),
            )
        )
    cameras.sort(key=lambda c: c.distance_from_origin_km)
    return tuple(cameras)


def _classify_camera_type(tags: dict) -> str:
    hw = tags.get("highway", "")
    camera_type_tag = (tags.get("camera:type") or "").lower()

    if hw == "traffic_signals":
        return "traffic_light"

    if "section" in camera_type_tag or "anpr" in camera_type_tag:
        role = (
            tags.get("section_control:role")
            or tags.get("camera:section:role")
            or ""
        ).lower()
        if "end" in role:
            return "section_end"
        return "section_start"

    if "mobile" in camera_type_tag or tags.get("temporary") == "yes":
        return "mobile_zone"

    return "fixed"


def _parse_max_speed(tags: dict) -> int | None:
    raw = (
        tags.get("maxspeed")
        or tags.get("camera:maxspeed")
        or tags.get("maxspeed:advisory")
    )
    if raw is None:
        return None
    try:
        return int(str(raw).split()[0])
    except (ValueError, IndexError):
        return None


def _parse_direction(tags: dict) -> str | None:
    raw = (tags.get("direction") or tags.get("camera:direction") or "").lower()
    if raw in ("forward", "backward"):
        return raw
    return None  # "both" or unknown → None


def _distance_from_origin_km(point: Coordinate, route: Route) -> float:
    """Cumulative distance along the route geometry to the point nearest to `point`.

    Falls back to a straight-line haversine from origin when no dense
    geometry is available (mock provider / short intra-city trips).
    """
    geom = route.geometry
    if not geom:
        # No dense geometry — use straight-line distance from origin as
        # an approximation of where along the route the camera sits.
        return _haversine_km(route.origin, point)

    # Find the geometry index closest to the camera coord.
    best_idx = min(range(len(geom)), key=lambda i: _haversine_km(geom[i], point))

    # Sum edge lengths from origin up to (not including) that index.
    dist = 0.0
    for i in range(best_idx):
        dist += _haversine_km(geom[i], geom[i + 1])
    return dist

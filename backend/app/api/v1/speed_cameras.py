"""Speed camera endpoint.

GET /v1/trips/radars — return speed cameras along a route corridor.

Query params (all floats):
  origin_lat, origin_lon     required
  dest_lat, dest_lon         required
  polyline                   optional — Google/OSRM encoded polyline.
                             When provided, the corridor follows the
                             real road; when omitted a straight-line
                             corridor between the two endpoints is used
                             (accurate enough for the Overpass query at
                             road-trip scale, but may miss cameras on
                             winding mountain roads).

Auth: standard X-MyTravelPal-Api-Key middleware (applied to all /v1/*
routes). No JWT required — speed-camera locations are public data.

Camera positions are cached 24 h server-side.
"""

from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.domain import Coordinate, Route
from app.providers.speed_cameras import SpeedCameraProvider

router = APIRouter(prefix="/trips", tags=["speed_cameras"])
_log = logging.getLogger(__name__)

_provider = SpeedCameraProvider()


class SpeedCameraOut(BaseModel):
    lat: float
    lon: float
    distance_from_origin_km: float
    max_speed_kmh: int | None = None
    camera_type: str
    direction: str | None = None


class RadarsOut(BaseModel):
    cameras: list[SpeedCameraOut]


@router.get("/radars", response_model=RadarsOut)
async def get_radars(
    origin_lat: float = Query(..., ge=-90.0, le=90.0),
    origin_lon: float = Query(..., ge=-180.0, le=180.0),
    dest_lat: float = Query(..., ge=-90.0, le=90.0),
    dest_lon: float = Query(..., ge=-180.0, le=180.0),
    polyline: str | None = Query(None, description="Google/OSRM encoded polyline"),
) -> RadarsOut:
    origin = Coordinate(lat=origin_lat, lon=origin_lon)
    dest = Coordinate(lat=dest_lat, lon=dest_lon)

    geometry: tuple[Coordinate, ...] = ()
    if polyline:
        geometry = _decode_polyline(polyline)

    # Estimate route distance for Route.free_flow_duration (unused here
    # but required by the dataclass).
    from app.providers.routing import _haversine_km
    if geometry and len(geometry) > 1:
        dist_km = sum(
            _haversine_km(geometry[i], geometry[i + 1])
            for i in range(len(geometry) - 1)
        )
    else:
        dist_km = _haversine_km(origin, dest)

    route = Route(
        origin=origin,
        destination=dest,
        distance_km=dist_km,
        free_flow_duration=timedelta(hours=dist_km / 100.0),
        polyline=polyline or "",
        toll_cost_eur=0.0,
        countries_crossed=(),
        geometry=geometry,
    )

    cameras = await _provider.cameras_along(route)

    return RadarsOut(
        cameras=[
            SpeedCameraOut(
                lat=c.coordinate.lat,
                lon=c.coordinate.lon,
                distance_from_origin_km=c.distance_from_origin_km,
                max_speed_kmh=c.max_speed_kmh,
                camera_type=c.camera_type,
                direction=c.direction,
            )
            for c in cameras
        ],
    )


def _decode_polyline(encoded: str, precision: int = 5) -> tuple[Coordinate, ...]:
    """Decode a Google/OSRM encoded polyline string.

    Returns an empty tuple on any decode error so the caller degrades
    gracefully to the straight-line corridor.
    """
    try:
        coords: list[Coordinate] = []
        index = 0
        lat = 0
        lon = 0
        factor = 10 ** precision

        while index < len(encoded):
            result = 0
            shift = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            dlat = ~(result >> 1) if result & 1 else result >> 1
            lat += dlat

            result = 0
            shift = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20:
                    break
            dlon = ~(result >> 1) if result & 1 else result >> 1
            lon += dlon

            coords.append(Coordinate(lat=lat / factor, lon=lon / factor))

        return tuple(coords)
    except Exception:
        _log.warning(
            "speed_cameras: polyline decode failed (len=%d) — "
            "falling back to straight-line corridor",
            len(encoded),
        )
        return ()

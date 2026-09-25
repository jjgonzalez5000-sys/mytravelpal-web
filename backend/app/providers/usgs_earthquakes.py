"""USGS Earthquake Hazards Program provider.

Free public feed, no key required. Global coverage. We query the
FDSN event API for the last 24 h of events with `minmagnitude=4.5`
inside the route bounding box, then let the downstream distance
filter narrow to events within the requested corridor width.

    https://earthquake.usgs.gov/fdsnws/event/1/query

Fields we care about:
- `mag` — Richter magnitude (float)
- `place` — human string, e.g. "12 km NE of Foo, Italy"
- `time` — epoch ms
- `geometry.coordinates` — [lon, lat, depth_km]

Set `MYTRAVELPAL_QUAKES=off` to disable (e.g. offline tests).
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

import httpx

from app.domain import (
    AdverseEvent,
    AdverseEventSeverity,
    AdverseEventSource,
    AdverseEventType,
    Coordinate,
    Route,
)

_log = logging.getLogger(__name__)


class UsgsEarthquakeProvider:
    """Real earthquake events from USGS FDSN, filtered to route bbox."""

    _URL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
    _MIN_MAG = 4.5
    _LOOKBACK_HOURS = 24
    _TTL = timedelta(hours=12)
    # Buffer around bbox — a M5+ quake can be felt tens of km away
    # even if the epicentre sits outside the route corridor.
    _BUFFER_LAT_DEG = 0.5
    _BUFFER_LON_DEG = 0.7
    _MAX_EVENTS = 40

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=8.0)

    async def events_along(
        self, route: Route, *, now: datetime,
    ) -> tuple[AdverseEvent, ...]:
        bbox = _route_bbox(
            route,
            buffer_lat=self._BUFFER_LAT_DEG,
            buffer_lon=self._BUFFER_LON_DEG,
        )
        if bbox is None:
            return ()
        min_lon, min_lat, max_lon, max_lat = bbox
        starttime = (now - timedelta(hours=self._LOOKBACK_HOURS)).strftime(
            "%Y-%m-%dT%H:%M:%S",
        )
        params = {
            "format": "geojson",
            "starttime": starttime,
            "minmagnitude": str(self._MIN_MAG),
            "minlatitude": f"{min_lat:.4f}",
            "maxlatitude": f"{max_lat:.4f}",
            "minlongitude": f"{min_lon:.4f}",
            "maxlongitude": f"{max_lon:.4f}",
            "limit": str(self._MAX_EVENTS),
            "orderby": "magnitude",
        }
        try:
            response = await self._client.get(self._URL, params=params)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPError as exc:
            _log.warning("USGS quake request failed: %s", exc)
            return ()
        except ValueError as exc:
            _log.warning("USGS quake non-JSON body: %s", exc)
            return ()

        features = body.get("features") or ()
        if not features:
            return ()

        events: list[AdverseEvent] = []
        for feature in features:
            geom = feature.get("geometry") or {}
            if geom.get("type") != "Point":
                continue
            coords = geom.get("coordinates") or []
            if len(coords) < 2:
                continue
            try:
                lon, lat = float(coords[0]), float(coords[1])
            except (TypeError, ValueError):
                continue
            props = feature.get("properties") or {}
            mag = _try_float(props.get("mag"))
            if mag is None or mag < self._MIN_MAG:
                continue
            reported_at = _reported_at(props, now)
            events.append(
                AdverseEvent(
                    id=f"usgs:{feature.get('id') or len(events)}",
                    type=AdverseEventType.EARTHQUAKE,
                    severity=_severity_for_magnitude(mag),
                    source=AdverseEventSource.OFFICIAL,
                    coordinate=Coordinate(lat=lat, lon=lon),
                    description=_description(props, mag),
                    reported_at=reported_at,
                    expires_at=reported_at + self._TTL,
                )
            )
        return tuple(events)


def _severity_for_magnitude(mag: float) -> AdverseEventSeverity:
    if mag >= 6.0:
        return AdverseEventSeverity.CRITICAL
    if mag >= 5.0:
        return AdverseEventSeverity.WARNING
    return AdverseEventSeverity.INFO


def _description(properties: dict, mag: float) -> str:
    place = str(properties.get("place") or "").strip()
    if place:
        return f"M{mag:.1f} earthquake — {place}"
    return f"M{mag:.1f} earthquake reported nearby"


def _reported_at(properties: dict, now: datetime) -> datetime:
    time_ms = properties.get("time")
    if isinstance(time_ms, (int, float)):
        try:
            return datetime.fromtimestamp(time_ms / 1000, tz=timezone.utc)
        except (OverflowError, OSError, ValueError):
            pass
    return now - timedelta(hours=1)


def _route_bbox(
    route: Route,
    *,
    buffer_lat: float,
    buffer_lon: float,
) -> tuple[float, float, float, float] | None:
    points = [route.origin, route.destination, *route.waypoints]
    if route.geometry:
        step = max(1, len(route.geometry) // 64)
        points.extend(route.geometry[::step])
    if not points:
        return None
    min_lat = min(p.lat for p in points) - buffer_lat
    max_lat = max(p.lat for p in points) + buffer_lat
    min_lon = min(p.lon for p in points) - buffer_lon
    max_lon = max(p.lon for p in points) + buffer_lon
    return (min_lon, min_lat, max_lon, max_lat)


def _try_float(value) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

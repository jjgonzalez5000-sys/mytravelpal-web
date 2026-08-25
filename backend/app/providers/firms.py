"""NASA FIRMS active-fire hotspots via the ArcGIS Living Atlas.

Why not EFFIS (Copernicus)? Their public WFS moved layer names in
2025-Q3 and the old `ecmwf.hotspots.viirs.24h` typename now returns a
`ServiceException` with HTTP 200 — silently defeating any client that
raises only on error status codes. `GetCapabilities` on the current
GWIS server also times out (> 45 s) so probing for the new name isn't
reliable at runtime.

FIRMS wraps the same VIIRS satellite data (S-NPP + NOAA-20/-21) as
EFFIS but is served via NASA/Esri's Living Atlas as an ArcGIS Feature
Service:

    https://services9.arcgis.com/RHVPKKiFTONKtxq3/arcgis/rest/services/
        Satellite_VIIRS_Thermal_Hotspots_and_Fire_Activity/
        FeatureServer/0/query

- No API key required.
- Envelope query returns GeoJSON with `frp` (fire radiative power in
  MW), `confidence`, `hours_old`, `acq_date`.
- Refreshed every 3 h, backfilled ~24 h.

The provider is enabled by default now that we have a working service.
Set `MYTRAVELPAL_FIRES=off` to disable (e.g. in CI to avoid the
outbound call).
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


class FirmsFireProvider:
    """Live active-fire hotspots from NASA FIRMS via ArcGIS Living Atlas."""

    _URL = (
        "https://services9.arcgis.com/RHVPKKiFTONKtxq3/arcgis/rest/services/"
        "Satellite_VIIRS_Thermal_Hotspots_and_Fire_Activity/FeatureServer/0/query"
    )
    _MAX_EVENTS = 100
    _TTL = timedelta(hours=12)
    # Buffer around the route bbox — big enough to catch inland fires whose
    # smoke plumes reach the highway. Iberia summer 2022/2023 hotspots
    # regularly sat 40–80 km off the AP-6 corridor.
    _BUFFER_LAT_DEG = 0.6
    _BUFFER_LON_DEG = 0.8

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
        return await self.fetch_bbox(bbox, now=now)

    async def fetch_bbox(
        self,
        bbox: tuple[float, float, float, float],
        *,
        now: datetime | None = None,
    ) -> tuple[AdverseEvent, ...]:
        """Public helper: fetch hotspots for an arbitrary bbox.

        Used by the diagnostics endpoint so operators can verify the
        pipeline without planning a full trip.
        """
        now = now or datetime.now(timezone.utc)
        west, south, east, north = bbox
        params = {
            "where": "1=1",
            "geometry": f"{west},{south},{east},{north}",
            "geometryType": "esriGeometryEnvelope",
            "inSR": "4326",
            "spatialRel": "esriSpatialRelIntersects",
            "outFields": "*",
            "returnGeometry": "true",
            "resultRecordCount": str(self._MAX_EVENTS),
            "f": "geojson",
        }
        try:
            response = await self._client.get(self._URL, params=params)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPError as exc:
            _log.warning("FIRMS request failed for bbox %s: %s", bbox, exc)
            return ()
        except ValueError as exc:
            _log.warning("FIRMS returned non-JSON body for bbox %s: %s", bbox, exc)
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
            # Reliability + relevance gate. FIRMS ships every VIIRS
            # thermal pixel above ~300 K; without filtering, a single
            # /plan surfaces dozens of tiny gas-flare / power-plant
            # hotspots that don't affect a driver at all. Real
            # wildfires (Iberia 2022/2023 fires that motivated this
            # feature) all sat comfortably above these thresholds.
            if not _is_reliable_wildfire(props, now):
                continue
            severity = _severity_for(props)
            fid = (
                props.get("OBJECTID")
                or props.get("objectid")
                or feature.get("id")
                or len(events)
            )
            reported_at = _reported_at(props, now)
            events.append(
                AdverseEvent(
                    id=f"firms:{fid}",
                    type=AdverseEventType.FIRE,
                    severity=severity,
                    source=AdverseEventSource.OFFICIAL,
                    coordinate=Coordinate(lat=lat, lon=lon),
                    description=_description(props),
                    reported_at=reported_at,
                    expires_at=reported_at + self._TTL,
                )
            )
        return tuple(events)


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


# Wildfire filter tuning — thresholds picked so that the Iberia summer
# 2022/2023 mega-fires (Sierra de la Culebra, Losacio, Rhodes) all
# survive while typical false positives (industrial flares, sunlit
# rocks, small farm burns) are dropped.
_MIN_FRP_MW = 5.0            # smaller than this ≈ chimney / flare
_MAX_HOURS_OLD = 24.0        # older than a day is stale for a driver
_ALLOWED_CONFIDENCE = {"nominal", "high", "h", "n", "medium", "m"}
# Empty confidence means the dataset didn't carry it; we treat that as
# "acceptable" so we don't accidentally drop good hotspots from feeds
# that omit the field.


def _is_reliable_wildfire(properties: dict, now: datetime) -> bool:
    confidence = str(properties.get("confidence") or "").strip().lower()
    if confidence and confidence not in _ALLOWED_CONFIDENCE:
        return False
    frp = _try_float(properties.get("frp"))
    if frp is None or frp < _MIN_FRP_MW:
        return False
    hours_old = _try_float(properties.get("hours_old"))
    if hours_old is not None and hours_old > _MAX_HOURS_OLD:
        return False
    return True


def _severity_for(properties: dict) -> AdverseEventSeverity:
    """Blend FIRMS `frp` (fire radiative power, MW) with `confidence`.

    Large FRP → real, spreading fire. Nominal / low confidence hotspots
    with tiny FRP are often industrial heat sources (chimneys, flares)
    and get demoted to INFO to avoid false alarms.
    """
    frp = _try_float(properties.get("frp"))
    confidence = str(properties.get("confidence") or "").lower()

    if frp is None:
        return AdverseEventSeverity.INFO if confidence == "low" else AdverseEventSeverity.WARNING
    if frp >= 100 and confidence != "low":
        return AdverseEventSeverity.CRITICAL
    if frp >= 20 and confidence != "low":
        return AdverseEventSeverity.WARNING
    return AdverseEventSeverity.INFO


def _description(properties: dict) -> str:
    parts = ["Active wildfire hotspot detected"]
    frp = _try_float(properties.get("frp"))
    if frp is not None:
        parts.append(f"~{frp:.0f} MW radiative power")
    conf = properties.get("confidence")
    if conf:
        parts.append(f"confidence: {conf}")
    hours_old = _try_float(properties.get("hours_old"))
    if hours_old is not None:
        parts.append(f"{hours_old:.0f} h old")
    return " · ".join(parts)


def _reported_at(properties: dict, now: datetime) -> datetime:
    hours_old = _try_float(properties.get("hours_old"))
    if hours_old is not None and hours_old >= 0:
        return now - timedelta(hours=hours_old)
    return now - timedelta(hours=2)


def _try_float(value) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

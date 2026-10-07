"""MeteoAlarm — pan-European severe weather warning provider.

MeteoAlarm aggregates official National Meteorological Service warnings
for every EU member state + Norway/Switzerland and publishes them as
CAP (Common Alerting Protocol) Atom feeds, one per country:

  https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-{country}

Each entry carries:
- event type (Thunderstorm, Rain, Snow, Wind, Fog, Ice, Coastal, etc.)
- severity (Minor / Moderate / Severe / Extreme)
- onset / expires timestamps
- CAP polygon covering the affected administrative area

We poll the feeds for every country the planned route crosses, parse
active alerts (status == Actual, onset <= now < expires), compute a
centroid for each polygon, and check whether that centroid lies within
`radius_km` of the planned route. Matching alerts surface in the
result screen's adverse-events banner and in the Companion live feed.

Free, keyless, no rate-limit policy beyond "please don't hammer us"
(we cache for 15 min).

Supported country slugs (subset, covering main EU road-trip routes):
  spain, france, germany, portugal, italy, switzerland,
  austria, netherlands, belgium
"""

from __future__ import annotations

import asyncio
import logging
import math
from datetime import datetime, timezone
from xml.etree import ElementTree as ET

import httpx

from app.domain import (
    AdverseEvent,
    AdverseEventSource,
    AdverseEventSeverity,
    AdverseEventType,
    Coordinate,
    Country,
    Route,
)

_log = logging.getLogger(__name__)

_BASE = "https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-{country}"
_TIMEOUT = 8.0
_CACHE_TTL_S = 900  # 15 min

_COUNTRY_SLUG: dict[Country, str] = {
    Country.ES: "spain",
    Country.FR: "france",
    Country.DE: "germany",
    Country.PT: "portugal",
    Country.IT: "italy",
    Country.CH: "switzerland",
    Country.AT: "austria",
    Country.NL: "netherlands",
    Country.BE: "belgium",
}

_A = "http://www.w3.org/2005/Atom"
_CAP = "urn:oasis:names:tc:emergency:cap:1.2"

# Map CAP event strings → our AdverseEventType
_EVENT_MAP: dict[str, AdverseEventType] = {
    "thunderstorm": AdverseEventType.THUNDERSTORM,
    "rain": AdverseEventType.HEAVY_RAIN,
    "snow/ice": AdverseEventType.SNOW,
    "wind": AdverseEventType.HIGH_WIND,
    "fog": AdverseEventType.DENSE_FOG,
    "high temperature": AdverseEventType.HEATWAVE,
    "low temperature": AdverseEventType.FREEZING_RAIN,
    "forest fire": AdverseEventType.FIRE,
    "coastal event": AdverseEventType.WEATHER,
    "flooding": AdverseEventType.FLOOD,
    "avalanches": AdverseEventType.AVALANCHE,
    "landslide": AdverseEventType.LANDSLIDE,
}

_SEVERITY_MAP: dict[str, AdverseEventSeverity] = {
    "extreme": AdverseEventSeverity.CRITICAL,
    "severe": AdverseEventSeverity.CRITICAL,
    "moderate": AdverseEventSeverity.WARNING,
    "minor": AdverseEventSeverity.WARNING,
}


def _earth_dist_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    p = math.pi / 180
    a = (
        math.sin((lat2 - lat1) * p / 2) ** 2
        + math.cos(lat1 * p) * math.cos(lat2 * p) * math.sin((lon2 - lon1) * p / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _parse_polygon_centroid(polygon_text: str) -> Coordinate | None:
    """Average all polygon vertices to produce a rough centroid."""
    try:
        pts = [
            tuple(float(x) for x in p.split(","))
            for p in polygon_text.strip().split()
            if "," in p
        ]
        if not pts:
            return None
        lat = sum(p[0] for p in pts) / len(pts)
        lon = sum(p[1] for p in pts) / len(pts)
        return Coordinate(lat=lat, lon=lon)
    except Exception:
        return None


def _is_on_route(coord: Coordinate, route: Route, radius_km: float = 150.0) -> bool:
    """Check if coord is within radius_km of any route geometry point.
    Samples every ~20th point for speed (polygons are large admin areas).
    """
    geom = route.geometry
    step = max(1, len(geom) // 50)
    return any(
        _earth_dist_km(coord.lat, coord.lon, p.lat, p.lon) <= radius_km
        for p in geom[::step]
    )


async def _fetch_country(country_slug: str, now: datetime) -> list[dict]:
    url = _BASE.format(country=country_slug)
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            r = await client.get(url)
        if r.status_code != 200:
            return []
        root = ET.fromstring(r.content)
    except Exception as exc:
        _log.debug("MeteoAlarm %s fetch failed: %r", country_slug, exc)
        return []

    alerts = []
    for entry in root.findall(f"{{{_A}}}entry"):
        status = entry.findtext(f"{{{_CAP}}}status") or ""
        if status.lower() != "actual":
            continue
        for info in entry.findall(f"{{{_CAP}}}info"):
            # Filter by language (prefer English, fall back to any)
            lang = info.findtext(f"{{{_CAP}}}language") or ""
            if lang and not lang.lower().startswith("en"):
                continue
            onset_s = info.findtext(f"{{{_CAP}}}onset") or ""
            expires_s = info.findtext(f"{{{_CAP}}}expires") or ""
            try:
                onset = datetime.fromisoformat(onset_s.replace("Z", "+00:00"))
                expires = datetime.fromisoformat(expires_s.replace("Z", "+00:00"))
            except ValueError:
                continue
            if not (onset <= now < expires):
                continue
            event_raw = (info.findtext(f"{{{_CAP}}}event") or "").lower()
            severity_raw = (info.findtext(f"{{{_CAP}}}severity") or "minor").lower()
            description = info.findtext(f"{{{_CAP}}}description") or ""
            headline = info.findtext(f"{{{_CAP}}}headline") or event_raw

            event_type = next(
                (v for k, v in _EVENT_MAP.items() if k in event_raw),
                AdverseEventType.ROAD_CLOSURE,
            )
            severity = _SEVERITY_MAP.get(severity_raw, AdverseEventSeverity.WARNING)

            for area in info.findall(f"{{{_CAP}}}area"):
                polygon_text = area.findtext(f"{{{_CAP}}}polygon") or ""
                centroid = _parse_polygon_centroid(polygon_text)
                if centroid is None:
                    continue
                alerts.append(
                    {
                        "centroid": centroid,
                        "type": event_type,
                        "severity": severity,
                        "description": headline.strip() or description[:120].strip(),
                        "expires": expires,
                    }
                )
    return alerts


class MeteoAlarmProvider:
    """Fetches and caches MeteoAlarm alerts for route-crossing countries."""

    _cache: dict[str, tuple[float, list[dict]]] = {}

    async def events_along(
        self,
        route: Route,
        *,
        now: datetime,
        radius_km: float = 150.0,
    ) -> tuple[AdverseEvent, ...]:
        if not route.countries_crossed:
            return ()

        now_ts = now.timestamp()
        slugs = {
            _COUNTRY_SLUG[c]
            for c in route.countries_crossed
            if c in _COUNTRY_SLUG
        }
        if not slugs:
            return ()

        # Fetch uncached countries in parallel.
        tasks = []
        async def _cached(data: list[dict]) -> list[dict]:
            return data

        for slug in slugs:
            cached_ts, cached_data = self._cache.get(slug, (0.0, []))
            if now_ts - cached_ts < _CACHE_TTL_S:
                tasks.append(_cached(cached_data))
            else:
                tasks.append(_fetch_country(slug, now))

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Update cache and collect all alert dicts.
        all_alerts: list[dict] = []
        for slug, result in zip(slugs, results):
            if isinstance(result, Exception):
                _log.debug("MeteoAlarm %s error: %r", slug, result)
                continue
            self._cache[slug] = (now_ts, result)
            all_alerts.extend(result)

        # Filter to alerts whose centroid is near the route.
        events: list[AdverseEvent] = []
        seen: set[str] = set()
        for a in all_alerts:
            centroid: Coordinate = a["centroid"]
            if not _is_on_route(centroid, route, radius_km):
                continue
            key = f"{a['type'].value}:{centroid.lat:.2f},{centroid.lon:.2f}"
            if key in seen:
                continue
            seen.add(key)
            events.append(
                AdverseEvent(
                    id=key,
                    type=a["type"],
                    severity=a["severity"],
                    source=AdverseEventSource.METEOALARM,
                    coordinate=centroid,
                    description=a["description"],
                    reported_at=now,
                    expires_at=a["expires"],
                    country=None,
                )
            )

        return tuple(events)

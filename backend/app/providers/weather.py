"""Open-Meteo weather-based adverse events provider.

Uses the free https://open-meteo.com/ forecast API (no key required) to
detect adverse weather along a planned route: heavy rain, snow,
thunderstorms, ice, fog. Each detected condition becomes an
`AdverseEvent` with `source=WEATHER` so it flows through the same
composite pipeline as user-submitted and mock events.

Sampling strategy: pick ~5 evenly-spaced waypoints along the route. For
each, request an hourly forecast and pick the timestamp closest to
"now + trip fraction × trip duration" — that way we surface the
weather the driver will actually meet, not the weather at trip start.
"""

from __future__ import annotations

import logging
import uuid
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


# Open-Meteo WMO weather codes we care about, mapped to our types.
# https://open-meteo.com/en/docs (codes 45–99).
_WMO_TO_EVENT: dict[int, tuple[AdverseEventType, AdverseEventSeverity, str]] = {
    # Fog
    45: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Fog"),
    48: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Depositing rime fog"),
    # Heavy rain
    65: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Heavy rain"),
    82: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Violent rain showers"),
    # Snow
    73: (AdverseEventType.SNOW, AdverseEventSeverity.WARNING, "Heavy snowfall"),
    75: (AdverseEventType.SNOW, AdverseEventSeverity.CRITICAL, "Heavy snowfall"),
    77: (AdverseEventType.SNOW, AdverseEventSeverity.WARNING, "Snow grains"),
    85: (AdverseEventType.SNOW, AdverseEventSeverity.WARNING, "Snow showers"),
    86: (AdverseEventType.SNOW, AdverseEventSeverity.CRITICAL, "Heavy snow showers"),
    # Thunderstorms
    95: (AdverseEventType.WEATHER, AdverseEventSeverity.CRITICAL, "Thunderstorm"),
    96: (AdverseEventType.WEATHER, AdverseEventSeverity.CRITICAL, "Thunderstorm with hail"),
    99: (AdverseEventType.WEATHER, AdverseEventSeverity.CRITICAL, "Severe thunderstorm with hail"),
    # Freezing conditions
    56: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Light freezing drizzle"),
    57: (AdverseEventType.WEATHER, AdverseEventSeverity.CRITICAL, "Freezing drizzle"),
    66: (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING, "Light freezing rain"),
    67: (AdverseEventType.WEATHER, AdverseEventSeverity.CRITICAL, "Freezing rain"),
}

_SAMPLE_POINTS = 5


class OpenMeteoWeatherProvider:
    """`AdverseEventsProvider` implementation backed by Open-Meteo."""

    _URL = "https://api.open-meteo.com/v1/forecast"

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=6.0)

    async def events_along(self, route: Route, *, now: datetime) -> tuple[AdverseEvent, ...]:
        if route.free_flow_duration.total_seconds() <= 0:
            return ()
        samples = _sample_points(route, _SAMPLE_POINTS)
        if not samples:
            return ()
        total_seconds = route.free_flow_duration.total_seconds()

        events: list[AdverseEvent] = []
        for i, coord in enumerate(samples):
            # Time this driver would be at this sample point.
            fraction = (i + 1) / (len(samples) + 1)
            target = now + timedelta(seconds=total_seconds * fraction)
            wmo = await self._fetch_weather_code(coord, target)
            if wmo is None or wmo not in _WMO_TO_EVENT:
                continue
            etype, severity, label = _WMO_TO_EVENT[wmo]
            events.append(
                AdverseEvent(
                    id=f"weather:{uuid.uuid4().hex[:12]}",
                    type=etype, severity=severity,
                    source=AdverseEventSource.WEATHER,
                    coordinate=coord,
                    description=f"{label} forecast near km {int(fraction * route.distance_km)}",
                    reported_at=now,
                    expires_at=target + timedelta(hours=2),
                )
            )
        return tuple(events)

    async def _fetch_weather_code(
        self, coord: Coordinate, at: datetime,
    ) -> int | None:
        params = {
            "latitude": f"{coord.lat:.4f}",
            "longitude": f"{coord.lon:.4f}",
            "hourly": "weathercode",
            "timezone": "UTC",
            "forecast_days": "3",
        }
        try:
            response = await self._client.get(self._URL, params=params)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPError as exc:
            _log.warning("Open-Meteo request failed: %s", exc)
            return None

        hourly = body.get("hourly") or {}
        times = hourly.get("time") or []
        codes = hourly.get("weathercode") or []
        if not times or not codes:
            return None
        target_utc = at.astimezone(timezone.utc) if at.tzinfo else at
        idx = _closest_hour_index(times, target_utc)
        if idx is None or idx >= len(codes):
            return None
        try:
            return int(codes[idx])
        except (TypeError, ValueError):
            return None


def _sample_points(route: Route, n: int) -> tuple[Coordinate, ...]:
    """Pick `n` roughly-evenly-spaced coordinates along the route."""
    if route.geometry:
        step = max(1, len(route.geometry) // (n + 1))
        return tuple(
            route.geometry[step * i]
            for i in range(1, n + 1)
            if step * i < len(route.geometry)
        )
    if route.waypoints:
        step = max(1, len(route.waypoints) // n)
        return tuple(
            route.waypoints[step * i]
            for i in range(n)
            if step * i < len(route.waypoints)
        )
    return ()


def _closest_hour_index(times: list[str], target: datetime) -> int | None:
    """`times` is a list of ISO-8601 UTC hourly stamps (`2026-08-24T10:00`)."""
    best_idx: int | None = None
    best_delta: timedelta | None = None
    for i, s in enumerate(times):
        try:
            t = datetime.fromisoformat(s)
        except ValueError:
            continue
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        delta = target - t if target > t else t - target
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best_idx = i
    return best_idx

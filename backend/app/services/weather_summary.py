"""Route weather summary: forecast conditions at sampled points.

Reuses the Open-Meteo API (free, no key) to produce a human-readable
weather strip for the trip: "sunny in Switzerland, cloudy in Austria,
rain in Hungary". Each segment carries the WMO code, a label, an icon
hint, and the km range it covers.

This is NOT a severe-weather alert (that's `weather.py` →
`AdverseEvent`). This is the friendly "pack a rain jacket for km
200-400" forecast that no road-trip app currently surfaces.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx

from app.domain import Coordinate, Route

_URL = "https://api.open-meteo.com/v1/forecast"
_SAMPLE_POINTS = 5


@dataclass(frozen=True, slots=True)
class WeatherSegment:
    from_km: float
    to_km: float
    label: str
    icon: str
    temperature_c: float | None
    coordinate: Coordinate


_WMO_LABELS: dict[int, tuple[str, str]] = {
    0: ("Clear sky", "sunny"),
    1: ("Mainly clear", "sunny"),
    2: ("Partly cloudy", "partly_cloudy"),
    3: ("Overcast", "cloudy"),
    45: ("Fog", "fog"),
    48: ("Rime fog", "fog"),
    51: ("Light drizzle", "drizzle"),
    53: ("Drizzle", "drizzle"),
    55: ("Dense drizzle", "drizzle"),
    61: ("Light rain", "rain"),
    63: ("Rain", "rain"),
    65: ("Heavy rain", "heavy_rain"),
    71: ("Light snow", "snow"),
    73: ("Snow", "snow"),
    75: ("Heavy snow", "heavy_snow"),
    80: ("Light showers", "rain"),
    81: ("Showers", "rain"),
    82: ("Violent showers", "heavy_rain"),
    85: ("Snow showers", "snow"),
    86: ("Heavy snow showers", "heavy_snow"),
    95: ("Thunderstorm", "thunderstorm"),
    96: ("Thunderstorm + hail", "thunderstorm"),
    99: ("Severe thunderstorm", "thunderstorm"),
}


async def weather_along_route(
    route: Route,
    departure_at: datetime,
    *,
    client: httpx.AsyncClient | None = None,
) -> tuple[WeatherSegment, ...]:
    if route.distance_km <= 0:
        return ()
    samples = _sample_points(route, _SAMPLE_POINTS)
    if not samples:
        return ()

    http = client or httpx.AsyncClient(timeout=6.0)
    total_s = route.free_flow_duration.total_seconds()
    segments: list[WeatherSegment] = []

    for i, coord in enumerate(samples):
        fraction = (i + 1) / (len(samples) + 1)
        target = departure_at + timedelta(seconds=total_s * fraction)
        from_km = round((i / len(samples)) * route.distance_km, 0)
        to_km = round(((i + 1) / len(samples)) * route.distance_km, 0)

        wmo, temp = await _fetch(http, coord, target)
        label, icon = _WMO_LABELS.get(wmo or 0, ("Unknown", "unknown"))
        segments.append(
            WeatherSegment(
                from_km=from_km,
                to_km=to_km,
                label=label,
                icon=icon,
                temperature_c=temp,
                coordinate=coord,
            )
        )

    return tuple(segments)


async def _fetch(
    client: httpx.AsyncClient,
    coord: Coordinate,
    at: datetime,
) -> tuple[int | None, float | None]:
    params = {
        "latitude": f"{coord.lat:.4f}",
        "longitude": f"{coord.lon:.4f}",
        "hourly": "weathercode,temperature_2m",
        "timezone": "UTC",
        "forecast_days": "3",
    }
    try:
        response = await client.get(_URL, params=params)
        response.raise_for_status()
        body = response.json()
    except Exception:
        return None, None

    hourly = body.get("hourly") or {}
    times = hourly.get("time") or []
    codes = hourly.get("weathercode") or []
    temps = hourly.get("temperature_2m") or []
    if not times:
        return None, None

    target_utc = at.astimezone(timezone.utc) if at.tzinfo else at
    idx = _closest_idx(times, target_utc)
    if idx is None:
        return None, None

    wmo = int(codes[idx]) if idx < len(codes) else None
    temp = float(temps[idx]) if idx < len(temps) else None
    return wmo, temp


def _closest_idx(times: list[str], target: datetime) -> int | None:
    best: int | None = None
    best_d: timedelta | None = None
    for i, s in enumerate(times):
        try:
            t = datetime.fromisoformat(s)
        except ValueError:
            continue
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        d = abs(target - t)
        if best_d is None or d < best_d:
            best_d = d
            best = i
    return best


def _sample_points(route: Route, n: int) -> tuple[Coordinate, ...]:
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

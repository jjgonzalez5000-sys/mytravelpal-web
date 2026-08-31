"""Weather endpoint for the plan-screen picker widget.

Small wrapper around Open-Meteo's public API: given a point,
returns current conditions + a 7-day daily forecast. The client
renders a mini chip (icon + temp) beside origin/destination
fields and, on tap, a sheet with the week ahead.

Public and free (no API key). Cached in-process 15 min per
0.05° grid cell so repeated planner opens for the same city
don't hammer Open-Meteo.
"""

from __future__ import annotations

import time
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

router = APIRouter(prefix="/weather", tags=["weather"])

_URL = "https://api.open-meteo.com/v1/forecast"
_TIMEOUT_S = 6.0
_CACHE_TTL_S = 900.0  # 15 min

# `(cell_key)` → (fetched_at_monotonic, response_dict)
_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}


def _icon_for_wmo(code: int) -> str:
    """Map WMO weather code to the stable icon slug the mobile
    client already knows (see `WeatherSegment.iconData` in Dart).
    Keep in sync with `services/weather_summary._WMO_LABELS`.
    """
    if code in (0, 1):
        return "sunny"
    if code == 2:
        return "partly_cloudy"
    if code == 3:
        return "cloudy"
    if code in (45, 48):
        return "fog"
    if code in (51, 53, 55, 56, 57):
        return "drizzle"
    if code in (61, 63, 80, 81):
        return "rain"
    if code in (65, 82, 66, 67):
        return "heavy_rain"
    if code in (71, 73, 77, 85):
        return "snow"
    if code in (75, 86):
        return "heavy_snow"
    if code in (95, 96, 99):
        return "thunderstorm"
    return "sunny"


class DailyForecast(BaseModel):
    date: str  # ISO date YYYY-MM-DD
    icon: str
    temp_max_c: float | None = None
    temp_min_c: float | None = None
    precipitation_mm: float | None = None


class WeatherPointResponse(BaseModel):
    lat: float
    lon: float
    # Current
    current_temp_c: float | None = None
    current_icon: str | None = None
    # 7-day forecast
    daily: list[DailyForecast] = []


@router.get("/point", response_model=WeatherPointResponse)
async def weather_point(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
) -> WeatherPointResponse:
    """Current + 7-day forecast for a point. Cached 15 min per
    0.05° cell (~5 km) so a full plan-screen fill (origin +
    destination + a couple of picker retries) collapses to
    ~1-2 upstream calls.
    """
    # Cell key rounded to 0.05° (~5 km) — city-scale enough.
    key = f"{round(lat, 2)}:{round(lon, 2)}"
    now = time.monotonic()
    cached = _CACHE.get(key)
    if cached and now - cached[0] < _CACHE_TTL_S:
        return WeatherPointResponse(**cached[1])

    params = {
        "latitude": f"{lat:.4f}",
        "longitude": f"{lon:.4f}",
        "current": "temperature_2m,weathercode",
        "daily": "weathercode,temperature_2m_max,"
                 "temperature_2m_min,precipitation_sum",
        "timezone": "auto",
        "forecast_days": "7",
    }
    async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
        try:
            response = await client.get(_URL, params=params)
            response.raise_for_status()
            body = response.json()
        except Exception as exc:
            raise HTTPException(
                status_code=502,
                detail={
                    "error": "weather_unavailable",
                    "message": str(exc),
                },
            ) from exc

    current = body.get("current") or {}
    current_wmo = current.get("weathercode")
    current_temp = current.get("temperature_2m")
    daily = body.get("daily") or {}
    times = daily.get("time") or []
    codes = daily.get("weathercode") or []
    tmax = daily.get("temperature_2m_max") or []
    tmin = daily.get("temperature_2m_min") or []
    precip = daily.get("precipitation_sum") or []

    forecast: list[DailyForecast] = []
    for i, iso in enumerate(times):
        forecast.append(
            DailyForecast(
                date=str(iso),
                icon=_icon_for_wmo(int(codes[i]))
                if i < len(codes) and codes[i] is not None
                else "sunny",
                temp_max_c=(
                    float(tmax[i]) if i < len(tmax) and tmax[i] is not None
                    else None
                ),
                temp_min_c=(
                    float(tmin[i]) if i < len(tmin) and tmin[i] is not None
                    else None
                ),
                precipitation_mm=(
                    float(precip[i]) if i < len(precip)
                    and precip[i] is not None else None
                ),
            )
        )

    result = WeatherPointResponse(
        lat=lat,
        lon=lon,
        current_temp_c=float(current_temp) if current_temp is not None
        else None,
        current_icon=_icon_for_wmo(int(current_wmo))
        if current_wmo is not None else None,
        daily=forecast,
    )
    _CACHE[key] = (now, result.model_dump())
    return result

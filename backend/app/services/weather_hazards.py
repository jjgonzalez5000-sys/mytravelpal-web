"""Weather-hazards check for Companion mode.

Given a handful of sample coords along the driver's next ~200 km,
returns a list of typed weather hazards (heavy rain, hail, thunder,
high wind, dense fog, freezing rain, snow) expected to hit within
the next ~3 h.

Two data sources are combined:

1. Open-Meteo forecast (hourly `weather_code`, `precipitation`,
   `snowfall`, `wind_speed_10m`, `visibility`). Free, no key, works
   worldwide. This drives *type* classification.
2. RainViewer live radar (`rain_radar.py`). Confirms that a
   precipitation forecast is really landing right now — filters
   out Open-Meteo hourly-slot noise. Europe + North America only.

The output is deliberately conservative: hazards fire only when
the Open-Meteo signal AND (for precipitation types in the RainViewer
footprint) a live radar echo agree. Coords outside RainViewer
coverage fall through with `radar_confirmed = False` — the caller
still gets the forecast-only alert.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx

from app.services.rain_radar import RainPoint, check_coords as check_radar

_log = logging.getLogger(__name__)

_URL = "https://api.open-meteo.com/v1/forecast"

# Forecast horizon: driver alert is meaningful ~10-60 min ahead of
# impact; we look up to 3 h to catch slow-approaching storms.
_HORIZON_HOURS = 3

# WMO weather-code thresholds. Values from
# https://open-meteo.com/en/docs (codes 45-99).
_CODE_HEAVY_RAIN = {65, 82}          # heavy rain / violent showers
_CODE_MODERATE_RAIN = {63, 81, 55}   # rain, showers, dense drizzle
_CODE_SNOW = {71, 73, 75, 85, 86}    # any snow / snow showers
_CODE_THUNDERSTORM = {95, 96, 99}    # 96 + 99 also imply hail
_CODE_HAIL_HINT = {96, 99}
_CODE_FREEZING_RAIN = {66, 67}       # WMO 66/67 = freezing rain
_CODE_DENSE_FOG = {45, 48}

# Physical thresholds. Same defaults the Beaufort scale + AEMET
# advisories use in Spain — good baseline for Europe-wide.
_WIND_HIGH_KMH = 60.0
_WIND_CRITICAL_KMH = 90.0
_VIS_DENSE_FOG_M = 500.0
_VIS_CRITICAL_FOG_M = 200.0
_PRECIP_MM_HEAVY = 4.0   # per hour
_SNOWFALL_CM_ANY = 0.2   # per hour
_TEMP_C_FREEZING = 2.0
_RADAR_DBZ_HEAVY = 35.0


@dataclass(frozen=True)
class WeatherHazard:
    """One typed hazard at one sample coord."""

    type: str            # backend AdverseEventType value (snake_case)
    severity: str        # "info" | "warning" | "critical"
    lat: float
    lon: float
    eta_km_ahead: float | None
    description: str
    radar_confirmed: bool


async def check(
    coords: list[tuple[float, float]],
    *,
    departure_at: datetime | None = None,
    km_ahead: list[float] | None = None,
    client: httpx.AsyncClient | None = None,
) -> list[WeatherHazard]:
    """Check hazards for each sample coord.

    `km_ahead[i]` optionally labels how far in front of the driver
    each coord sits (for the UI's "in N km" hint). `departure_at`
    anchors the "next 3 h" window; defaults to now.
    """
    if not coords:
        return []
    now = (departure_at or datetime.now(tz=timezone.utc)).astimezone(timezone.utc)
    horizon = now + timedelta(hours=_HORIZON_HOURS)

    http = client or httpx.AsyncClient(timeout=6.0)
    close = client is None
    try:
        # RainViewer sample once for all coords — cheap tile fetches,
        # keeps the request budget tight (2 tiles per coord).
        radar_by_ix: dict[int, RainPoint] = {}
        try:
            radar_points = await check_radar(coords, client=http)
            for i, rp in enumerate(radar_points):
                radar_by_ix[i] = rp
        except Exception as e:  # radar is best-effort
            _log.warning("weather_hazards: radar check failed: %s", e)

        hazards: list[WeatherHazard] = []
        for i, (lat, lon) in enumerate(coords):
            om = await _fetch_openmeteo(http, lat, lon)
            if om is None:
                continue
            radar = radar_by_ix.get(i)
            km = km_ahead[i] if km_ahead and i < len(km_ahead) else None
            hazards.extend(_classify(lat, lon, km, om, radar, now, horizon))
        return _dedup(hazards)
    finally:
        if close:
            await http.aclose()


@dataclass(frozen=True)
class _OMSlot:
    time: datetime
    code: int | None
    precipitation_mm: float | None
    snowfall_cm: float | None
    wind_kmh: float | None
    visibility_m: float | None
    temperature_c: float | None


async def _fetch_openmeteo(
    client: httpx.AsyncClient, lat: float, lon: float
) -> list[_OMSlot] | None:
    """Hourly forecast slots for the next 3 h at (lat, lon)."""
    params = {
        "latitude": f"{lat:.4f}",
        "longitude": f"{lon:.4f}",
        "hourly": (
            "weather_code,precipitation,snowfall,"
            "wind_speed_10m,visibility,temperature_2m"
        ),
        "wind_speed_unit": "kmh",
        "timezone": "UTC",
        "forecast_days": "1",
    }
    try:
        resp = await client.get(_URL, params=params, timeout=5.0)
        resp.raise_for_status()
        body = resp.json()
    except Exception as e:  # pragma: no cover - transport
        _log.debug("Open-Meteo hazards fetch failed: %s", e)
        return None

    hourly = body.get("hourly") or {}
    times = hourly.get("time") or []
    codes = hourly.get("weather_code") or []
    prec = hourly.get("precipitation") or []
    snow = hourly.get("snowfall") or []
    wind = hourly.get("wind_speed_10m") or []
    vis = hourly.get("visibility") or []
    temp = hourly.get("temperature_2m") or []
    slots: list[_OMSlot] = []
    for i, iso in enumerate(times):
        try:
            t = datetime.fromisoformat(iso)
        except ValueError:
            continue
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        slots.append(
            _OMSlot(
                time=t,
                code=_safe_int(codes, i),
                precipitation_mm=_safe_float(prec, i),
                snowfall_cm=_safe_float(snow, i),
                wind_kmh=_safe_float(wind, i),
                visibility_m=_safe_float(vis, i),
                temperature_c=_safe_float(temp, i),
            )
        )
    return slots


def _safe_int(xs: list, i: int) -> int | None:
    try:
        return int(xs[i])
    except (IndexError, ValueError, TypeError):
        return None


def _safe_float(xs: list, i: int) -> float | None:
    try:
        return float(xs[i])
    except (IndexError, ValueError, TypeError):
        return None


def _classify(
    lat: float,
    lon: float,
    km_ahead: float | None,
    slots: list[_OMSlot],
    radar: RainPoint | None,
    now: datetime,
    horizon: datetime,
) -> list[WeatherHazard]:
    """Emit one hazard per detected type at this coord.

    Only slots inside the [now, horizon] window count. Wind + fog
    are checked slot-by-slot; precipitation types roll up across
    the window so a short-lived shower in one slot still fires.
    """
    out: list[WeatherHazard] = []
    window = [s for s in slots if now - timedelta(minutes=30) <= s.time <= horizon]
    if not window:
        return out

    radar_dbz = max(
        (radar.dbz_now or 0.0) if radar else 0.0,
        (radar.dbz_forecast_60m or 0.0) if radar else 0.0,
    )
    radar_confirmed_precip = radar is not None and radar_dbz >= _RADAR_DBZ_HEAVY

    # Thunderstorm (highest priority — includes potential hail).
    if any(s.code in _CODE_THUNDERSTORM for s in window):
        sev = "critical" if radar_dbz >= 50.0 else "warning"
        out.append(
            WeatherHazard(
                type="thunderstorm",
                severity=sev,
                lat=lat,
                lon=lon,
                eta_km_ahead=km_ahead,
                description="Thunderstorm forecast within 3 h",
                radar_confirmed=radar_confirmed_precip,
            )
        )
        if any(s.code in _CODE_HAIL_HINT for s in window):
            out.append(
                WeatherHazard(
                    type="hail",
                    severity="warning",
                    lat=lat,
                    lon=lon,
                    eta_km_ahead=km_ahead,
                    description="Hail possible with the incoming storm",
                    radar_confirmed=radar_confirmed_precip,
                )
            )

    # Freezing rain — code 66/67, or rain + near-freezing temps.
    freezing = any(s.code in _CODE_FREEZING_RAIN for s in window) or (
        any(
            (s.precipitation_mm or 0) > 0
            and (s.temperature_c is not None and s.temperature_c <= _TEMP_C_FREEZING)
            for s in window
        )
    )
    if freezing:
        out.append(
            WeatherHazard(
                type="freezing_rain",
                severity="warning",
                lat=lat,
                lon=lon,
                eta_km_ahead=km_ahead,
                description="Freezing rain — risk of black ice",
                radar_confirmed=radar_confirmed_precip,
            )
        )

    # Snow — Open-Meteo snowfall or WMO code, whichever fires first.
    snowing = any(
        (s.snowfall_cm or 0.0) >= _SNOWFALL_CM_ANY or s.code in _CODE_SNOW
        for s in window
    )
    if snowing:
        max_snow = max((s.snowfall_cm or 0.0) for s in window)
        sev = "critical" if max_snow >= 2.0 else "warning"
        out.append(
            WeatherHazard(
                type="snow",
                severity=sev,
                lat=lat,
                lon=lon,
                eta_km_ahead=km_ahead,
                description=f"Snow forecast — up to {max_snow:.1f} cm/h",
                radar_confirmed=radar_confirmed_precip,
            )
        )

    # Heavy rain — WMO heavy code, big hourly precip, OR radar
    # confirmation alone (radar caught something Open-Meteo did not).
    heavy_rain_om = any(
        s.code in _CODE_HEAVY_RAIN
        or (s.precipitation_mm or 0.0) >= _PRECIP_MM_HEAVY
        for s in window
    )
    if heavy_rain_om or radar_confirmed_precip:
        if not (freezing or snowing):
            sev = "critical" if radar_dbz >= 50.0 else "warning"
            out.append(
                WeatherHazard(
                    type="heavy_rain",
                    severity=sev,
                    lat=lat,
                    lon=lon,
                    eta_km_ahead=km_ahead,
                    description=(
                        "Heavy rain within reach"
                        + (" (radar-confirmed)" if radar_confirmed_precip else "")
                    ),
                    radar_confirmed=radar_confirmed_precip,
                )
            )

    # High wind.
    peak_wind = max((s.wind_kmh or 0.0) for s in window)
    if peak_wind >= _WIND_HIGH_KMH:
        sev = "critical" if peak_wind >= _WIND_CRITICAL_KMH else "warning"
        out.append(
            WeatherHazard(
                type="high_wind",
                severity=sev,
                lat=lat,
                lon=lon,
                eta_km_ahead=km_ahead,
                description=f"High wind gusts up to {peak_wind:.0f} km/h",
                radar_confirmed=False,
            )
        )

    # Dense fog.
    worst_vis = min(
        (s.visibility_m for s in window if s.visibility_m is not None),
        default=None,
    )
    fog_codes = any(s.code in _CODE_DENSE_FOG for s in window)
    if fog_codes or (worst_vis is not None and worst_vis < _VIS_DENSE_FOG_M):
        vis_val = worst_vis if worst_vis is not None else _VIS_DENSE_FOG_M
        sev = (
            "critical" if vis_val < _VIS_CRITICAL_FOG_M else "warning"
        )
        out.append(
            WeatherHazard(
                type="dense_fog",
                severity=sev,
                lat=lat,
                lon=lon,
                eta_km_ahead=km_ahead,
                description=f"Dense fog — visibility {vis_val:.0f} m",
                radar_confirmed=False,
            )
        )
    return out


def _dedup(hazards: list[WeatherHazard]) -> list[WeatherHazard]:
    """Keep the closest (min eta_km_ahead) instance per type.

    The client only surfaces the nearest occurrence anyway; sending
    dupes wastes bandwidth and complicates the UI.
    """
    best: dict[str, WeatherHazard] = {}
    for h in hazards:
        cur = best.get(h.type)
        if cur is None:
            best[h.type] = h
            continue
        cur_km = cur.eta_km_ahead if cur.eta_km_ahead is not None else 1e9
        new_km = h.eta_km_ahead if h.eta_km_ahead is not None else 1e9
        if new_km < cur_km:
            best[h.type] = h
    # Preserve original ordering for UI stability.
    seen = set()
    out: list[WeatherHazard] = []
    for h in hazards:
        if h.type in seen:
            continue
        out.append(best[h.type])
        seen.add(h.type)
    return out

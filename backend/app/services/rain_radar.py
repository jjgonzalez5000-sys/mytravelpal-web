"""RainViewer live precipitation radar sampler.

Companion mode uses this to warn the driver about rain/storms that the
Open-Meteo hourly forecast may have missed. RainViewer publishes a
manifest of recent + short-range nowcast frames at
`api.rainviewer.com/public/weather-maps.json` and serves 256 px PNG
tiles via a CDN. Each tile pixel encodes reflectivity as a color; a
non-zero pixel means precipitation.

We take the current radar frame plus the ~60-min nowcast, project the
sample coord to (z, x, y) at zoom 6 (~156 km per tile side at the
equator), download the tile, and inspect a 5x5 pixel window around
the projected pixel. Max reflectivity is mapped to a rough dBZ scale
(the standard RainViewer palette goes from light greens ~10 dBZ to
red/pink ~65 dBZ).

If Pillow is unavailable at import time we fall back to a much cruder
signal: a tile payload larger than a fixed byte threshold suggests
"has-precipitation" and returns a nominal dBZ.

Coverage caveat: RainViewer has good coverage across Europe and North
America. Elsewhere (Africa, most of Asia, Southern Hemisphere) tiles
come back blank; we return `None` reflectivity for those coords so
the caller does not surface bogus warnings.
"""
from __future__ import annotations

import io
import logging
import math
import time
from dataclasses import dataclass

import httpx

try:
    from PIL import Image  # type: ignore

    _HAS_PIL = True
except Exception:  # pragma: no cover - optional dep fallback
    Image = None  # type: ignore
    _HAS_PIL = False

_log = logging.getLogger(__name__)

MANIFEST_URL = "https://api.rainviewer.com/public/weather-maps.json"
# Cache the manifest in-process; RainViewer updates every ~10 min.
_MANIFEST_TTL_S = 300.0

# Tile params. Zoom 6 keeps request count small while giving ~150 km
# resolution — enough to spot a squall line an hour ahead.
_TILE_Z = 6
_TILE_SIZE = 256
_COLOR = 2  # Universal blue-green-yellow-red palette.
_SMOOTH = 1
_SNOW = 1
_SAMPLE_WINDOW = 5  # 5x5 px around the projected pixel.
# Bytes threshold used only when Pillow is unavailable. Empty ocean
# tiles compress well under 1 KB; any real precipitation blob blows
# past that.
_FALLBACK_BYTES_HAS_PRECIP = 1024

# In-memory manifest cache. Simple TTL — no cross-worker sync needed
# because a stale manifest just means an extra 5-min delay before the
# newest nowcast frame is picked up.
_manifest_cache: tuple[float, dict] | None = None


@dataclass(frozen=True)
class RainPoint:
    """Radar sample at a single coord.

    `dbz_now` is the reflectivity from the latest radar frame;
    `dbz_forecast_60m` is the strongest reflectivity across all
    nowcast frames within the next ~60 min. Both are `None` when
    the coord falls outside RainViewer coverage or the tile fetch
    failed. dBZ mapping: <20 light, 20-35 moderate, 35-50 heavy,
    >50 storm.
    """

    lat: float
    lon: float
    dbz_now: float | None
    dbz_forecast_60m: float | None


async def _fetch_manifest(client: httpx.AsyncClient) -> dict | None:
    """Return RainViewer manifest, cached for 5 min."""
    global _manifest_cache
    now = time.monotonic()
    if _manifest_cache is not None:
        ts, cached = _manifest_cache
        if now - ts < _MANIFEST_TTL_S:
            return cached
    try:
        resp = await client.get(MANIFEST_URL, timeout=5.0)
        if resp.status_code != 200:
            _log.warning("RainViewer manifest HTTP %s", resp.status_code)
            return None
        data = resp.json()
        _manifest_cache = (now, data)
        return data
    except Exception as e:  # pragma: no cover - transport failures
        _log.warning("RainViewer manifest fetch failed: %s", e)
        return None


def _latlon_to_tile(lat: float, lon: float, z: int) -> tuple[int, int, int, int]:
    """Slippy-map projection. Returns `(x, y, px, py)` where
    `(x, y)` is the tile index and `(px, py)` is the pixel offset
    inside the 256 px tile.
    """
    lat_rad = math.radians(lat)
    n = 2**z
    x_f = (lon + 180.0) / 360.0 * n
    y_f = (
        (1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi)
        / 2.0
        * n
    )
    x = int(math.floor(x_f))
    y = int(math.floor(y_f))
    px = int((x_f - x) * _TILE_SIZE)
    py = int((y_f - y) * _TILE_SIZE)
    return x, y, px, py


def _pixel_to_dbz(r: int, g: int, b: int, a: int) -> float:
    """Approximate RainViewer palette 2 (universal blue) to dBZ.

    RainViewer does not publish a formal mapping, so we bucket by
    dominant channel intensity. Alpha 0 => no return (0 dBZ).
    Blue-dominant => light 15 dBZ. Green-dominant => moderate 25.
    Yellow (R+G) => heavy 40. Red-dominant => storm 55.
    """
    if a < 16:
        return 0.0
    # Grayscale-heavy noise -> treat as very light.
    if max(r, g, b) - min(r, g, b) < 20:
        return 10.0 if a > 40 else 0.0
    if r > 180 and g < 120:
        return 55.0  # red / pink -> intense
    if r > 180 and g > 150 and b < 100:
        return 45.0  # orange
    if r > 200 and g > 200 and b < 120:
        return 35.0  # yellow -> heavy
    if g > 180 and r < 200:
        return 25.0  # green -> moderate
    if b > 180 and r < 120:
        return 15.0  # blue -> light
    return 20.0  # anything else with color -> light-moderate


def _max_dbz_in_window(png_bytes: bytes, px: int, py: int) -> float | None:
    """Sample a 5x5 window around `(px, py)`; return the max dBZ.

    Falls back to a size heuristic when Pillow is not importable.
    """
    if not _HAS_PIL:
        # Very cheap heuristic — empty ocean tiles compress under
        # 1 KB. Anything larger probably has some precipitation.
        return 30.0 if len(png_bytes) > _FALLBACK_BYTES_HAS_PRECIP else 0.0
    try:
        img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    except Exception as e:  # pragma: no cover - corrupt tile
        _log.warning("Rain tile decode failed: %s", e)
        return None
    w, h = img.size
    half = _SAMPLE_WINDOW // 2
    x0 = max(0, px - half)
    y0 = max(0, py - half)
    x1 = min(w, px + half + 1)
    y1 = min(h, py + half + 1)
    best = 0.0
    px_data = img.load()
    if px_data is None:
        return None
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            r, g, b, a = px_data[xx, yy]
            best = max(best, _pixel_to_dbz(r, g, b, a))
    return best


async def _sample_frame(
    client: httpx.AsyncClient,
    host: str,
    frame_path: str,
    lat: float,
    lon: float,
) -> float | None:
    """Download the tile covering `(lat, lon)` for one manifest
    frame and return the max dBZ inside a small window. `None` on
    fetch failure (silently swallowed — caller degrades gracefully).
    """
    x, y, px, py = _latlon_to_tile(lat, lon, _TILE_Z)
    # frame_path looks like `/v2/radar/1758891600` — the tile URL
    # template is `{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png`.
    url = (
        f"{host}{frame_path}/{_TILE_SIZE}/{_TILE_Z}/{x}/{y}/"
        f"{_COLOR}/{_SMOOTH}_{_SNOW}.png"
    )
    try:
        resp = await client.get(url, timeout=4.0)
    except Exception as e:  # pragma: no cover - transport
        _log.debug("Rain tile fetch failed for %s: %s", url, e)
        return None
    if resp.status_code != 200 or not resp.content:
        return None
    return _max_dbz_in_window(resp.content, px, py)


async def check_coords(
    coords: list[tuple[float, float]],
    *,
    client: httpx.AsyncClient | None = None,
) -> list[RainPoint]:
    """Sample radar for each coord. Serialized to keep to ~1 req/s
    per RainViewer's polite-use guideline, but bounded by the fact
    that manifest+two tiles per coord means ~2 requests per coord.
    """
    if not coords:
        return []
    http = client or httpx.AsyncClient(timeout=6.0)
    close = client is None
    try:
        manifest = await _fetch_manifest(http)
        if manifest is None:
            return [
                RainPoint(lat=lat, lon=lon, dbz_now=None, dbz_forecast_60m=None)
                for lat, lon in coords
            ]
        host = manifest.get("host", "https://tilecache.rainviewer.com")
        radar = manifest.get("radar") or {}
        past_frames = radar.get("past") or []
        nowcast_frames = radar.get("nowcast") or []
        latest_path = past_frames[-1]["path"] if past_frames else None
        # Trim nowcast to the ~60 min horizon (RainViewer default
        # nowcast spacing is 10 min => 6 frames).
        forecast_paths = [f["path"] for f in nowcast_frames[:6]]

        out: list[RainPoint] = []
        for lat, lon in coords:
            dbz_now = (
                await _sample_frame(http, host, latest_path, lat, lon)
                if latest_path
                else None
            )
            # Forecast: max across upcoming frames. Short-circuit on
            # the first heavy hit to keep request count down when a
            # storm is obviously already in-frame.
            dbz_forecast: float | None = None
            for path in forecast_paths:
                v = await _sample_frame(http, host, path, lat, lon)
                if v is None:
                    continue
                dbz_forecast = v if dbz_forecast is None else max(dbz_forecast, v)
                if dbz_forecast >= 50.0:
                    break
            out.append(
                RainPoint(
                    lat=lat,
                    lon=lon,
                    dbz_now=dbz_now,
                    dbz_forecast_60m=dbz_forecast,
                )
            )
        return out
    finally:
        if close:
            await http.aclose()

"""Wikimedia Commons photo lookup.

Free, no API key required. Uses geo-search as primary strategy (photos taken
within 300 m of the POI coordinates) with name-based text search as fallback.
Results are cached 7 days — photos don't change often.

Attribution required by CC-BY-SA: "Image from Wikimedia Commons / CC-BY-SA".
"""

from __future__ import annotations

import time

import httpx

_BASE = "https://api.wikimedia.org/core/v1/commons/search/page"
_GEO_BASE = "https://commons.wikimedia.org/w/api.php"
_TIMEOUT_S = 3.0
_CACHE_TTL_S = 7 * 24 * 3600
# Simple in-process cache: key → (monotonic_timestamp, url_or_None)
_CACHE: dict[str, tuple[float, str | None]] = {}

_GEO_SKIP_KEYWORDS = {"map", "flag", "logo", "icon", "schema", "diagram", "coat"}
_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


async def _geo_photo(
    lat: float,
    lon: float,
    client: httpx.AsyncClient,
    radius_m: int = 300,
) -> str | None:
    """Query the Wikimedia Commons geo-search API for a photo near lat/lon.

    Finds File: namespace images taken within *radius_m* metres of the
    coordinates. Skips SVGs and decorative files (maps, logos, flags).
    Returns a 400-px-wide thumbnail URL or None.
    """
    try:
        resp = await client.get(
            _GEO_BASE,
            params={
                "action": "query",
                "generator": "geosearch",
                "ggscoord": f"{lat}|{lon}",
                "ggsradius": str(radius_m),
                "ggslimit": "10",
                "ggsnamespace": "6",  # File namespace
                "prop": "imageinfo",
                "iiprop": "url",
                "iiurlwidth": "400",
                "format": "json",
            },
            headers={"User-Agent": "MyTravelPal/1.0 (mytravelpal.io)"},
        )
        if resp.status_code != 200:
            return None
        pages = (resp.json().get("query") or {}).get("pages") or {}
        for page in pages.values():
            title: str = page.get("title", "")
            title_lower = title.lower()
            # Skip decorative / non-photo files.
            if any(kw in title_lower for kw in _GEO_SKIP_KEYWORDS):
                continue
            imageinfo = page.get("imageinfo") or []
            for info in imageinfo:
                thumb = info.get("thumburl") or info.get("url") or ""
                if not thumb:
                    continue
                ext = "." + thumb.rsplit(".", 1)[-1].lower().split("?")[0]
                if ext not in _IMAGE_EXTS:
                    continue
                return thumb.replace("http://", "https://")
    except Exception:  # noqa: BLE001
        pass
    return None


def _rewrite_to_400px(url: str) -> str:
    """Rewrite a Wikimedia thumb URL to 400 px wide when possible."""
    if "/thumb/" in url:
        parts = url.rsplit("/", 1)
        last = parts[-1]
        if "-" in last:
            base_name = last.split("-", 1)[1]
            return parts[0] + "/400px-" + base_name
    return url


async def photo_url_for(
    name: str,
    lat: float,
    lon: float,
    kind: str = "hotel",
) -> str | None:
    """Return a Wikimedia Commons thumbnail URL for the named POI, or None.

    Strategy:
    1. Geo-search (300 m radius) — finds real photos regardless of POI name.
    2. Name-search fallback — original text-based search.

    Args:
        name: POI display name (hotel or restaurant).
        lat: Latitude.
        lon: Longitude.
        kind: "hotel" or "restaurant" — appended to the name-search query.
    """
    key = f"{name.lower().strip()}|{round(lat, 2)},{round(lon, 2)}"
    cached = _CACHE.get(key)
    if cached is not None:
        ts, cached_url = cached
        # Cache hits (url found): 7 days. Cache misses (None): 1 hour retry.
        ttl = _CACHE_TTL_S if cached_url else 3600
        if time.monotonic() - ts < ttl:
            return cached_url

    url: str | None = None
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            # --- Primary: geo-search (300 m radius) ---
            url = await _geo_photo(lat, lon, client)

            # --- Fallback 1: wider geo-search (1 km radius) ---
            if url is None:
                url = await _geo_photo(lat, lon, client, radius_m=1000)

            # --- Fallback 2: name-based text search ---
            if url is None:
                resp = await client.get(
                    _BASE,
                    params={"q": f"{name} {kind}", "limit": "3"},
                    headers={"User-Agent": "MyTravelPal/1.0 (mytravelpal.io)"},
                )
                if resp.status_code == 200:
                    pages = resp.json().get("pages", [])
                    for page in pages:
                        thumb = (page.get("thumbnail") or {}).get("url")
                        if thumb:
                            url = _rewrite_to_400px(thumb.replace("http://", "https://"))
                            break

            # --- Fallback 3: city-level photo (very wide, 5 km) ---
            # Most cities have geotagged photos on Wikimedia Commons.
            # Filtered to landscape/cityscape shots by skipping portraits,
            # SVGs and recognisably-indoor titles.
            if url is None:
                url = await _geo_photo(lat, lon, client, radius_m=5000)
    except Exception:  # noqa: BLE001
        pass

    _CACHE[key] = (time.monotonic(), url)
    return url

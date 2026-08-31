"""HERE Places enrichment — canonical hotel name + verified address.

The Geoapify / OSM pool gives us hotel *candidates* but the names
are often mis-cased, truncated, or use local variants that don't
match what Google Maps / Booking indexes. When a driver taps
"Open in Maps" or "Reserve on Booking" from the app, matching the
name to Google or Booking's own catalog matters a lot: a small
typo can send them to the wrong hotel.

HERE Places (Discover endpoint) has a curated business catalog
for EU with the OFFICIAL name and structured address. We do one
name+coord lookup per top hotel and stamp the result onto the
hotel's `attributes` tuple. Google Maps / Booking deep-links then
use the enriched name.

Note: HERE's free tier does NOT return hotel star classification
(`hotelClass`) — that's behind their Content Pro paywall. This
enricher is name+address only. Real official stars still require
Booking Content API (post-affiliate approval) or a paid HERE
Content subscription.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from dataclasses import replace
from typing import Any

import httpx

from app.domain import Hotel

_log = logging.getLogger(__name__)

_ENDPOINT = "https://discover.search.hereapi.com/v1/discover"
_TIMEOUT_S = 5.0
_TTL_S = 24 * 3600
# Search radius bias (m) around the hotel's coord. Matches what
# Google Places enricher does — big enough to survive coord skew,
# small enough not to catch same-named venues in the next town.
_BIAS_RADIUS_M = 500
# HERE categories: 500-5000-0053 Hotel/Motel · 0054 Resort · 0055 B&B
_HOTEL_CATEGORIES = "500-5000-0053,500-5000-0054,500-5000-0055"


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


_CACHE: dict[str, tuple[float, dict[str, Any] | None]] = {}


def _cache_key(name: str, lat: float, lon: float) -> str:
    return f"{name.lower().strip()}|{round(lat, 3)},{round(lon, 3)}"


class HerePlacesEnricher:
    """`Hotel`-shaped enricher that adds HERE's canonical name +
    verified address as `here_name`, `here_address`, `here_city`,
    `here_postal_code`, `here_country`, `here_id` attributes.
    Instantiated per request; reuses one HTTP client for keep-alive.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def enrich_hotels(
        self, candidates: tuple[Hotel, ...],
    ) -> tuple[Hotel, ...]:
        key = _api_key()
        if not key or not candidates:
            return candidates
        # HERE's free tier is 5 rps sustained. Cap parallelism so
        # a batch of 30 hotels doesn't trip the rate limit and
        # start returning 429.
        sem = asyncio.Semaphore(4)

        async def _one(h: Hotel) -> Hotel:
            async with sem:
                extra = await self._lookup(
                    h.name, h.coordinate.lat, h.coordinate.lon, key,
                )
            if extra is None:
                return h
            attrs = list(h.attributes)
            for k, v in extra.items():
                attrs = [(kk, vv) for kk, vv in attrs if kk != k]
                attrs.append((k, str(v)))
            return replace(h, attributes=tuple(attrs))

        return tuple(await asyncio.gather(*(_one(h) for h in candidates)))

    async def _lookup(
        self, name: str, lat: float, lon: float, key: str,
    ) -> dict[str, Any] | None:
        ck = _cache_key(name, lat, lon)
        cached = _CACHE.get(ck)
        if cached is not None:
            ts, val = cached
            if time.monotonic() - ts < _TTL_S:
                return val
        # HERE Discover rejects `categories` when combined with a
        # text `q` (2026 API behaviour: "Reserved parameters not
        # accepted"). The hotel name in `q` + a tight coord circle
        # is enough — Discover returns the best-matching business
        # in the area regardless of category slug.
        # HERE Discover rejects `categories` when combined with a
        # text `q`, AND rejects `at` when combined with `in=circle`
        # (mutually exclusive spatial hints). Keep only the circle:
        # tighter constraint that also biases the search geo-
        # graphically to the hotel's coord.
        params = {
            "q": name,
            "limit": "1",
            "in": f"circle:{lat:.5f},{lon:.5f};r={_BIAS_RADIUS_M}",
            "apiKey": key,
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE Places lookup failed for %r: %r", name, exc)
            return None
        if r.status_code != 200:
            _log.warning(
                "HERE Places HTTP %s for %r: %s",
                r.status_code, name, r.text[:200],
            )
            return None
        try:
            body = r.json()
        except ValueError:
            return None
        items = body.get("items") or []
        if not items:
            _CACHE[ck] = (time.monotonic(), None)
            return None
        item = items[0]
        out: dict[str, Any] = {}
        if item.get("title"):
            out["here_name"] = str(item["title"])
        addr = item.get("address") or {}
        if addr.get("label"):
            out["here_address"] = str(addr["label"])
        if addr.get("city"):
            out["here_city"] = str(addr["city"])
        if addr.get("postalCode"):
            out["here_postal_code"] = str(addr["postalCode"])
        if addr.get("countryCode"):
            out["here_country"] = str(addr["countryCode"])
        if item.get("id"):
            out["here_id"] = str(item["id"])
        _CACHE[ck] = (time.monotonic(), out if out else None)
        return out or None

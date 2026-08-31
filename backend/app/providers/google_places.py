"""Google Places API (New) enrichment for restaurants and hotels.

The OSM / Geoapify pool gives us the establishment (name, coord,
cuisine, opening hours). What it lacks — and what drivers want
before they detour — is a real-world **rating** and a **review
count**. Google Places has both, gated behind a per-request paid
API.

Design choices:
- **Enrichment, not replacement.** We keep the Geoapify pool as
  the source of truth for what exists and where. This provider
  looks up each candidate by name + coord and stamps the rating /
  review count / Google URL onto the `attributes` tuple.
- **Text Search Essentials** SKU ($5 / 1000). Cheapest field mask
  that still returns `rating` + `userRatingCount`. Enterprise
  fields (reviews text, photos) are 4x costlier and not needed
  for beta.
- **Cap per plan.** We only enrich the N candidates the mobile UI
  will actually SURFACE, not the raw pool — otherwise a trip with
  200 corridor restaurants would burn 200 requests for the sake of
  showing 6.
- **24 h TTL cache** on (name, rounded lat, rounded lon). A plan
  re-run for the same route hits cached ratings instead of billing
  Google again.
- **Fail silent.** If the key is missing or the API errors, we
  return the restaurants unchanged — the UI still renders, just
  without a Google rating chip.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from dataclasses import replace
from typing import Any

import httpx

from app.domain import Hotel, Restaurant

_log = logging.getLogger(__name__)

_ENDPOINT = "https://places.googleapis.com/v1/places:searchText"
_TIMEOUT_S = 5.0
_TTL_S = 24 * 3600
# Bias radius (m) around a restaurant coord when doing a text
# search — big enough to survive a 100 m OSM/Google coord skew,
# small enough to avoid grabbing a same-named venue three towns
# over.
_BIAS_RADIUS_M = 400
# Field mask keeps us on the "Essentials" SKU. Adding reviews /
# photos would jump into "Enterprise" ($20/1000) — deferred.
_FIELD_MASK = (
    "places.id,places.displayName,places.rating,"
    "places.userRatingCount,places.priceLevel,"
    "places.googleMapsUri,places.location"
)


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_GOOGLE_PLACES_KEY") or None


# Process-wide cache: rating lookups are essentially static day-to-
# day, and callers within one process share the wins.
_CACHE: dict[str, tuple[float, dict[str, Any] | None]] = {}


def _cache_key(name: str, lat: float, lon: float) -> str:
    return f"{name.lower().strip()}|{round(lat, 3)},{round(lon, 3)}"


class GooglePlacesEnricher:
    """Adds Google rating attributes to a batch of restaurants.

    Instantiate once per request (reuses the HTTP client for
    keep-alive) and call `enrich(candidates)` with the shortlist
    the mobile UI will surface. Returns a NEW tuple of
    restaurants with `attributes` extended; never mutates in
    place.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def enrich_restaurants(
        self, candidates: tuple[Restaurant, ...],
    ) -> tuple[Restaurant, ...]:
        key = _api_key()
        if not key or not candidates:
            return candidates
        # Kick off every lookup in parallel but with a small
        # concurrency ceiling — Google enforces per-second RPS
        # limits and we don't want 429s.
        sem = asyncio.Semaphore(6)

        async def _one(r: Restaurant) -> Restaurant:
            async with sem:
                extra = await self._lookup(
                    r.name, r.coordinate.lat, r.coordinate.lon, key,
                )
            if extra is None:
                return r
            attrs = list(r.attributes)
            for k, v in extra.items():
                # Overwrite policy: Google rating wins over any
                # older `rating` in the tuple (Geoapify sometimes
                # carries a stale one).
                attrs = [(kk, vv) for kk, vv in attrs if kk != k]
                attrs.append((k, str(v)))
            return replace(r, attributes=tuple(attrs))

        return tuple(await asyncio.gather(*(_one(r) for r in candidates)))

    async def enrich_hotels(
        self, candidates: tuple[Hotel, ...],
    ) -> tuple[Hotel, ...]:
        """Same enrichment for hotels — adds rating, review count
        and (crucially) `google_maps_url` so the mobile "Open in
        Maps" button lands on the exact Google Place page instead
        of a name search that sometimes matched a same-named
        hotel across the continent."""
        key = _api_key()
        if not key or not candidates:
            return candidates
        sem = asyncio.Semaphore(6)

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
        cached = _CACHE.get(_cache_key(name, lat, lon))
        if cached is not None:
            ts, val = cached
            if time.monotonic() - ts < _TTL_S:
                return val
        payload = {
            "textQuery": name,
            "locationBias": {
                "circle": {
                    "center": {"latitude": lat, "longitude": lon},
                    "radius": _BIAS_RADIUS_M,
                },
            },
            "maxResultCount": 1,
        }
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": key,
            "X-Goog-FieldMask": _FIELD_MASK,
        }
        try:
            r = await self._client.post(
                _ENDPOINT, json=payload, headers=headers,
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("Google Places lookup failed for %r: %r", name, exc)
            return None
        if r.status_code != 200:
            _log.warning(
                "Google Places HTTP %s for %r: %s",
                r.status_code, name, r.text[:200],
            )
            return None
        try:
            body = r.json()
        except ValueError:
            return None
        places = body.get("places") or []
        if not places:
            _CACHE[_cache_key(name, lat, lon)] = (time.monotonic(), None)
            return None
        p = places[0]
        out: dict[str, Any] = {}
        if isinstance(p.get("rating"), (int, float)):
            out["rating"] = round(float(p["rating"]), 1)
        if isinstance(p.get("userRatingCount"), int):
            out["rating_count"] = p["userRatingCount"]
        if p.get("priceLevel"):
            # Google returns strings like "PRICE_LEVEL_MODERATE" —
            # keep raw so the mobile side can map to €/€€/€€€.
            out["google_price_level"] = str(p["priceLevel"])
        if p.get("googleMapsUri"):
            out["google_maps_url"] = str(p["googleMapsUri"])
        _CACHE[_cache_key(name, lat, lon)] = (
            time.monotonic(), out if out else None,
        )
        return out or None

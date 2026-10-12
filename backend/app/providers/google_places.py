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
import difflib
import logging
import math
import os
import re
import time
import unicodedata
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
_BIAS_RADIUS_M = 250
# A Google result is accepted only when it is this close to our own
# coordinate AND its name resembles ours; otherwise we stamp nothing.
_MAX_MATCH_M = 150.0
_MIN_NAME_SIM = 0.6
_NEG_TTL_S = 3600
# Field mask keeps us on the "Essentials" SKU. Adding reviews /
# photos would jump into "Enterprise" ($20/1000) — deferred.
_FIELD_MASK = (
    "places.id,places.displayName,places.rating,"
    "places.userRatingCount,places.priceLevel,"
    "places.googleMapsUri,places.location,places.formattedAddress"
)


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_GOOGLE_PLACES_KEY") or None


# Process-wide cache: rating lookups are essentially static day-to-
# day, and callers within one process share the wins.
_CACHE: dict[str, tuple[float, dict[str, Any] | None]] = {}


def _cache_key(name: str, lat: float, lon: float) -> str:
    return f"v2|{name.lower().strip()}|{round(lat, 3)},{round(lon, 3)}"


def cache_lookup(name: str, lat: float, lon: float) -> tuple[bool, dict[str, Any] | None]:
    """(fresh entry found, cached value); negative results are cached too."""
    cached = _CACHE.get(_cache_key(name, lat, lon))
    if cached is None:
        return False, None
    ts, val = cached
    ttl = _TTL_S if val is not None else _NEG_TTL_S
    if time.monotonic() - ts < ttl:
        return True, val
    return False, None


def _norm(text: str) -> str:
    folded = unicodedata.normalize("NFKD", text or "")
    folded = "".join(c for c in folded if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", " ", folded.lower()).strip()


def _name_similarity(a: str, b: str) -> float:
    na, nb = _norm(a), _norm(b)
    if not na or not nb:
        return 0.0
    ratio = difflib.SequenceMatcher(None, na, nb).ratio()
    ta, tb = set(na.split()), set(nb.split())
    small = min(ta, tb, key=len)
    contained = len(ta & tb) / len(small) if small else 0.0
    # Containment alone would match "Hotel" to anything.
    if len(small) < 2:
        contained = 0.0
    return max(ratio, contained)


def _distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 6371000.0 * 2 * math.asin(min(1.0, math.sqrt(h)))


def _pick_best(
    places: list[dict[str, Any]],
    name: str,
    lat: float,
    lon: float,
    max_m: float = _MAX_MATCH_M,
) -> dict[str, Any] | None:
    """Best Google result for our POI, or None when none is trustworthy."""
    best: dict[str, Any] | None = None
    best_score = -1e9
    for p in places:
        loc = p.get("location") or {}
        plat, plon = loc.get("latitude"), loc.get("longitude")
        if not isinstance(plat, (int, float)) or not isinstance(plon, (int, float)):
            continue
        disp = p.get("displayName")
        gname = disp.get("text") if isinstance(disp, dict) else disp
        sim = _name_similarity(name, str(gname or ""))
        dist = _distance_m(lat, lon, float(plat), float(plon))
        if sim < _MIN_NAME_SIM or dist > max_m:
            continue
        score = sim - dist / 300.0
        if score > best_score:
            best, best_score = p, score
    return best


def address_hint(attrs: dict[str, str]) -> str | None:
    """Best address string available in a POI's attributes."""
    for k in ("google_address", "here_address", "address_line1"):
        v = (attrs.get(k) or "").strip()
        if v:
            return v
    street = " ".join(
        x for x in (attrs.get("addr:street"), attrs.get("addr:housenumber")) if x
    )
    city = attrs.get("addr:city") or ""
    return ", ".join(x for x in (street, city) if x) or None


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
                    address_hint(dict(r.attributes)),
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
                    address_hint(dict(h.attributes)),
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
        self,
        name: str,
        lat: float,
        lon: float,
        key: str,
        address: str | None = None,
    ) -> dict[str, Any] | None:
        ck = _cache_key(name, lat, lon)
        found, val = cache_lookup(name, lat, lon)
        if found:
            return val
        payload = {
            "textQuery": f"{name}, {address}" if address else name,
            "locationBias": {
                "circle": {
                    "center": {"latitude": lat, "longitude": lon},
                    "radius": _BIAS_RADIUS_M,
                },
            },
            "maxResultCount": 5,
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
        p = _pick_best(body.get("places") or [], name, lat, lon)
        if p is None:
            _CACHE[ck] = (time.monotonic(), None)
            return None
        out: dict[str, Any] = {}
        if p.get("id"):
            out["google_place_id"] = str(p["id"])
        disp = p.get("displayName")
        gname = disp.get("text") if isinstance(disp, dict) else disp
        if gname:
            out["google_name"] = str(gname)
        if p.get("formattedAddress"):
            out["google_address"] = str(p["formattedAddress"])
        if isinstance(p.get("rating"), (int, float)):
            out["rating"] = round(float(p["rating"]), 1)
        if isinstance(p.get("userRatingCount"), int):
            out["rating_count"] = p["userRatingCount"]
        if p.get("priceLevel"):
            # Raw "PRICE_LEVEL_MODERATE"; mobile maps it to EUR signs.
            out["google_price_level"] = str(p["priceLevel"])
        if p.get("googleMapsUri"):
            out["google_maps_url"] = str(p["googleMapsUri"])
        _CACHE[ck] = (time.monotonic(), out if out else None)
        return out or None

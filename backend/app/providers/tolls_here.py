"""HERE Routing v8 toll pricing.

The Routing v8 API (`router.hereapi.com/v8/routes`) accepts a route
between origin and destination (plus waypoints) and, when we ask for
`return=tolls,summary`, returns per-section toll fares including
country, currency and amount.

Compared to TollGuru:
- TollGuru returns booth-level fares (name + lat/lon per gate).
  HERE aggregates by section (usually per-country or per-operator).
- HERE covers the same EU countries with published toll data.
- HERE bundles into our existing 250 k / month free tier so the
  marginal cost for beta is €0.

We ship a `TollProvider`-shaped adapter so `trips.py` can pick us
up as a drop-in when `TollGuruProvider` is unavailable. Booth
coordinates are synthesised at the midpoint of each toll section
so the mobile map can still render a pin — real booth positions
would require an additional API call we don't want to make.
"""

from __future__ import annotations

import logging
import os
import time
from typing import Any

import httpx

from app.domain import Coordinate, Route
from app.providers.tollguru import TollBooth, TollQuote

_log = logging.getLogger(__name__)

_ENDPOINT = "https://router.hereapi.com/v8/routes"
_TIMEOUT_S = 8.0

# In-memory cache for segment fares: (lat1_r3, lon1_r3, lat2_r3, lon2_r3) → (fare_eur, ts)
# Key coords rounded to 3 decimal places (~100 m precision) to maximise cache hits.
_SEGMENT_CACHE: dict[tuple[float, float, float, float], tuple[float, float]] = {}
_SEGMENT_CACHE_TTL_S = 30 * 86400  # 30 days — EU toll prices change 1-2×/year

# Full-route quote cache keyed on (origin_lat_r1, origin_lon_r1, dest_lat_r1, dest_lon_r1).
# Coords rounded to 1 decimal (~11 km grid) so nearby origin/destination pairs share a
# cache entry — a driver leaving from slightly different addresses on the same route pays
# the same tolls. European toll prices change at most once or twice a year (January
# vignette cycles, motorway price reviews). 30 days is very conservative.
#
# Cache entry: (TollQuote, timestamp, hit_count)
# Every _VALIDATION_EVERY hits on the same cache key we fire a background
# re-fetch to detect price drift. If the new total differs by >15% we log
# a warning and update the entry; otherwise we silently reset the counter.
_QUOTE_CACHE: dict[
    tuple[float, float, float, float],
    tuple["TollQuote", float, int],       # (quote, ts, hit_count)
] = {}
_QUOTE_CACHE_TTL_S = 30 * 86400  # 30 days
_VALIDATION_EVERY = 8            # re-validate every 8th cache hit


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


class HereTollsProvider:
    """`TollProvider`-shaped wrapper around HERE Routing v8 tolls.

    Instantiated in the providers factory; returns `None` from
    `quote()` when the key is missing or HERE rejects the route
    so the caller falls through to the mock heuristic.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def quote(
        self, route: Route, *, vehicle_class: str = "2AxlesAuto",
    ) -> TollQuote | None:
        key = _api_key()
        if not key:
            return None
        if not route.geometry:
            return None

        # Check route-level cache before hitting HERE.
        # Round to 1 decimal (~11 km grid) so nearby addresses share a cache entry —
        # toll costs for routes from the same city area are identical.
        qk: tuple[float, float, float, float] = (
            round(route.geometry[0].lat, 1), round(route.geometry[0].lon, 1),
            round(route.geometry[-1].lat, 1), round(route.geometry[-1].lon, 1),
        )
        cached_q = _QUOTE_CACHE.get(qk)
        if cached_q is not None:
            cached_quote, ts, hit_count = cached_q
            if time.time() - ts < _QUOTE_CACHE_TTL_S:
                new_hits = hit_count + 1
                _QUOTE_CACHE[qk] = (cached_quote, ts, new_hits)
                _log.debug("HERE tolls: cache hit #%d for %s→%s",
                           new_hits, qk[:2], qk[2:])
                # Periodic background re-validation so stale prices don't
                # silently persist for 30 days after a vignette price change.
                if new_hits % _VALIDATION_EVERY == 0:
                    import asyncio
                    asyncio.create_task(
                        self._validate_cache(qk, cached_quote, route,
                                             vehicle_class, key),
                    )
                return cached_quote

        # HERE wants origin + destination + optional via points.
        # We forward the first + last geometry points as endpoints
        # and drop every other geometry vertex in between as a
        # `via` so HERE reconstructs the exact same path (otherwise
        # HERE re-routes with its own preferences and the tolls
        # bill a different corridor than the one the user sees).
        # HERE caps via points at 20; downsample if we have more.
        params: dict[str, Any] = {
            "transportMode": "car",
            "origin": f"{route.geometry[0].lat:.5f},{route.geometry[0].lon:.5f}",
            "destination": (
                f"{route.geometry[-1].lat:.5f},{route.geometry[-1].lon:.5f}"
            ),
            "return": "tolls,summary,polyline",
            "currency": "EUR",
            "apiKey": key,
        }
        vias = _downsample_vias(route)
        # HERE takes multiple `via` params — httpx serialises a
        # list into repeated query params.
        if vias:
            params["via"] = [f"{c.lat:.5f},{c.lon:.5f}" for c in vias]
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE tolls request failed: %r", exc)
            return None
        if r.status_code != 200:
            _log.warning(
                "HERE tolls HTTP %s: %s", r.status_code, r.text[:200],
            )
            return None
        try:
            body = r.json()
        except ValueError:
            return None
        routes = body.get("routes") or []
        if not routes:
            return None
        total_eur = 0.0
        booths: list[TollBooth] = []
        for section in routes[0].get("sections") or []:
            tolls = section.get("tolls") or []
            if not tolls:
                continue
            for toll in tolls:
                # HERE returns MULTIPLE `fares` per toll section —
                # one per payment method (cash, tag, video). Pick
                # the MIN EUR fare (tag/video price) and emit one
                # booth per section.
                eur_fares = [
                    float((f.get("price") or {}).get("value"))
                    for f in (toll.get("fares") or [])
                    if str(((f.get("price") or {}).get("currency") or ""))
                        .upper() == "EUR"
                    and isinstance(
                        (f.get("price") or {}).get("value"), (int, float),
                    )
                ]
                if not eur_fares:
                    continue
                val = min(eur_fares)
                total_eur += val

                # tollCollectionLocations gives the real gate positions
                # (entry + exit for système fermé, single barrier for
                # système ouvert). Use these for accurate map pins and
                # human-readable names instead of the section midpoint.
                locs = toll.get("tollCollectionLocations") or []
                operator = str(
                    toll.get("tollSystem") or toll.get("name") or "Toll",
                )
                if len(locs) >= 2:
                    entry_name = str(locs[0].get("name") or "").title()
                    exit_name = str(locs[-1].get("name") or "").title()
                    booth_name = f"{entry_name} → {exit_name}"
                    entry_loc = locs[0].get("location") or {}
                    exit_loc = locs[-1].get("location") or {}
                    booth_lat = float(entry_loc.get("lat") or 0)
                    booth_lon = float(entry_loc.get("lng") or 0)
                    booth_exit_lat = float(exit_loc.get("lat") or 0)
                    booth_exit_lon = float(exit_loc.get("lng") or 0)
                elif len(locs) == 1:
                    booth_name = str(locs[0].get("name") or operator).title()
                    loc = locs[0].get("location") or {}
                    booth_lat = float(loc.get("lat") or 0)
                    booth_lon = float(loc.get("lng") or 0)
                    booth_exit_lat = booth_exit_lon = 0.0
                else:
                    # Fallback: midpoint of section departure/arrival
                    booth_name = operator
                    dep = section.get("departure", {}).get("place", {}).get(
                        "location", {},
                    )
                    arr = section.get("arrival", {}).get("place", {}).get(
                        "location", {},
                    )
                    try:
                        booth_lat = (float(dep["lat"]) + float(arr["lat"])) / 2
                        booth_lon = (float(dep["lng"]) + float(arr["lng"])) / 2
                    except (TypeError, ValueError, KeyError):
                        booth_lat = booth_lon = 0.0
                    booth_exit_lat = booth_exit_lon = 0.0

                booths.append(TollBooth(
                    name=booth_name,
                    cost_eur=round(val, 2),
                    lat=booth_lat,
                    lon=booth_lon,
                    exit_lat=booth_exit_lat,
                    exit_lon=booth_exit_lon,
                    operator=operator,
                    is_vignette=_is_vignette_toll(toll, operator),
                ))
        result_quote = TollQuote(total_eur=round(total_eur, 2), tolls=tuple(booths))
        _QUOTE_CACHE[qk] = (result_quote, time.time(), 0)
        return result_quote


    async def _validate_cache(
        self,
        qk: tuple[float, float, float, float],
        cached: "TollQuote",
        route: "Route",
        vehicle_class: str,
        api_key: str,
    ) -> None:
        """Background re-fetch to detect toll price drift.

        Fires every _VALIDATION_EVERY cache hits. If the live total
        differs from cached by >15%, updates the cache entry and logs a
        warning so ops can investigate. Silent on network errors.
        """
        try:
            fresh = await self._fetch_quote(route, vehicle_class=vehicle_class,
                                            api_key=api_key)
            if fresh is None:
                return
            if cached.total_eur <= 0:
                return
            drift = abs(fresh.total_eur - cached.total_eur) / cached.total_eur
            if drift > 0.15:
                _log.warning(
                    "HERE tolls: cached total %.2f EUR differs from live %.2f EUR "
                    "(%.0f%%) — updating cache for %s→%s",
                    cached.total_eur, fresh.total_eur, drift * 100, qk[:2], qk[2:],
                )
                _QUOTE_CACHE[qk] = (fresh, time.time(), 0)
            else:
                # Price still valid — reset counter, keep existing timestamp
                existing_ts = _QUOTE_CACHE[qk][1] if qk in _QUOTE_CACHE else time.time()
                _QUOTE_CACHE[qk] = (cached, existing_ts, 0)
        except Exception as exc:  # noqa: BLE001
            _log.debug("HERE tolls: background validation failed: %r", exc)

    async def _fetch_quote(
        self, route: "Route", *, vehicle_class: str, api_key: str,
    ) -> "TollQuote | None":
        """Live fetch bypassing the in-memory cache. Used by background
        validation only — main path goes through quote()."""
        if not route.geometry:
            return None
        params: dict[str, Any] = {
            "transportMode": "car",
            "origin": f"{route.geometry[0].lat:.5f},{route.geometry[0].lon:.5f}",
            "destination": (
                f"{route.geometry[-1].lat:.5f},{route.geometry[-1].lon:.5f}"
            ),
            "return": "tolls,summary,polyline",
            "currency": "EUR",
            "apiKey": api_key,
        }
        vias = _downsample_vias(route)
        if vias:
            params["via"] = [f"{c.lat:.5f},{c.lon:.5f}" for c in vias]
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE tolls background fetch failed: %r", exc)
            return None
        if r.status_code != 200:
            return None
        try:
            body = r.json()
        except ValueError:
            return None
        routes = body.get("routes") or []
        if not routes:
            return None
        total_eur = 0.0
        booths: list[TollBooth] = []
        for section in routes[0].get("sections") or []:
            tolls = section.get("tolls") or []
            if not tolls:
                continue
            for toll in tolls:
                eur_fares = [
                    float((f.get("price") or {}).get("value"))
                    for f in (toll.get("fares") or [])
                    if str(((f.get("price") or {}).get("currency") or ""))
                        .upper() == "EUR"
                    and isinstance(
                        (f.get("price") or {}).get("value"), (int, float),
                    )
                ]
                if not eur_fares:
                    continue
                val = min(eur_fares)
                total_eur += val
                locs = toll.get("tollCollectionLocations") or []
                operator = str(
                    toll.get("tollSystem") or toll.get("name") or "Toll",
                )
                if len(locs) >= 2:
                    entry_name = str(locs[0].get("name") or "").title()
                    exit_name = str(locs[-1].get("name") or "").title()
                    booth_name = f"{entry_name} → {exit_name}"
                    entry_loc = locs[0].get("location") or {}
                    exit_loc = locs[-1].get("location") or {}
                    booth_lat = float(entry_loc.get("lat") or 0)
                    booth_lon = float(entry_loc.get("lng") or 0)
                    booth_exit_lat = float(exit_loc.get("lat") or 0)
                    booth_exit_lon = float(exit_loc.get("lng") or 0)
                elif len(locs) == 1:
                    booth_name = str(locs[0].get("name") or operator).title()
                    loc = locs[0].get("location") or {}
                    booth_lat = float(loc.get("lat") or 0)
                    booth_lon = float(loc.get("lng") or 0)
                    booth_exit_lat = booth_exit_lon = 0.0
                else:
                    booth_name = operator
                    dep = section.get("departure", {}).get("place", {}).get(
                        "location", {},
                    )
                    arr = section.get("arrival", {}).get("place", {}).get(
                        "location", {},
                    )
                    try:
                        booth_lat = (float(dep["lat"]) + float(arr["lat"])) / 2
                        booth_lon = (float(dep["lng"]) + float(arr["lng"])) / 2
                    except (TypeError, ValueError, KeyError):
                        booth_lat = booth_lon = 0.0
                    booth_exit_lat = booth_exit_lon = 0.0
                booths.append(TollBooth(
                    name=booth_name,
                    cost_eur=round(val, 2),
                    lat=booth_lat,
                    lon=booth_lon,
                    exit_lat=booth_exit_lat,
                    exit_lon=booth_exit_lon,
                    operator=operator,
                    is_vignette=_is_vignette_toll(toll, operator),
                ))
        return TollQuote(total_eur=round(total_eur, 2), tolls=tuple(booths))

    async def quote_segment(
        self,
        origin: Coordinate,
        dest: Coordinate,
        *,
        vehicle_class: str = "2AxlesAuto",
    ) -> float | None:
        """Fare in EUR for a single origin→dest segment, cached 24 h.

        Used by the intra-section bypass service to price sub-sections
        without repeating identical HERE requests across plan calls.
        """
        key = (
            round(origin.lat, 3), round(origin.lon, 3),
            round(dest.lat, 3), round(dest.lon, 3),
        )
        cached = _SEGMENT_CACHE.get(key)
        if cached is not None:
            val, ts = cached
            if time.time() - ts < _SEGMENT_CACHE_TTL_S:
                return val

        key_api = _api_key()
        if not key_api:
            return None
        params: dict[str, Any] = {
            "transportMode": "car",
            "origin": f"{origin.lat:.5f},{origin.lon:.5f}",
            "destination": f"{dest.lat:.5f},{dest.lon:.5f}",
            "return": "tolls,summary",
            "currency": "EUR",
            "apiKey": key_api,
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE segment quote failed: %r", exc)
            return None
        if r.status_code != 200:
            _log.warning("HERE segment HTTP %s", r.status_code)
            return None
        try:
            body = r.json()
        except ValueError:
            return None
        routes = body.get("routes") or []
        if not routes:
            return None
        total = 0.0
        for section in routes[0].get("sections") or []:
            for toll in section.get("tolls") or []:
                eur_fares = [
                    float((f.get("price") or {}).get("value"))
                    for f in (toll.get("fares") or [])
                    if str(((f.get("price") or {}).get("currency") or ""))
                        .upper() == "EUR"
                    and isinstance(
                        (f.get("price") or {}).get("value"), (int, float),
                    )
                ]
                if eur_fares:
                    total += min(eur_fares)
        fare = round(total, 2)
        _SEGMENT_CACHE[key] = (fare, time.time())
        return fare


def _is_vignette_toll(toll: dict[str, Any], operator: str) -> bool:
    """Detect country-wide vignette / e-vignette / distance-based
    e-toll entries in a HERE toll section. These CANNOT be skipped
    by taking a parallel road — every motorway in the country
    requires the sticker / registration — so the partial-toll-skips
    service must exclude them.

    Detection is best-effort by string match against `tollSystem` /
    `operator` names since HERE's schema has no explicit `is_vignette`
    field. Kept in a small allowlist rather than a broad regex so we
    don't misclassify a real booth (e.g. FR/IT/ES gated motorways).
    """
    # HERE may expose an explicit type on some fares — check first.
    for fare in (toll.get("fares") or []):
        if str(fare.get("type") or "").lower() == "vignette":
            return True
    # Fallback: match well-known vignette-based systems by name.
    haystack = f"{operator} {toll.get('name') or ''}".lower()
    _KNOWN_VIGNETTE_KEYWORDS = (
        "vignette",           # AT, CH, HU (e-Vignette), CZ, SK, SI
        "rovinieta",          # RO
        "elektronická znám",  # CZ / SK (elektronická známka)
        "matrica",            # HU
        "toll sticker",       # generic EN label some HERE responses use
        "e-vinieta",          # BG
        "vinjeta",            # SI
    )
    return any(k in haystack for k in _KNOWN_VIGNETTE_KEYWORDS)


def _downsample_vias(route: Route) -> list:
    """Reduce the interior geometry to at most 20 via points so
    HERE Routing accepts the request and rebuilds a corridor close
    to our OSRM answer. Interior = geometry minus endpoints.
    """
    inner = list(route.geometry[1:-1])
    if len(inner) <= 20:
        return inner
    step = len(inner) / 20
    picks = [inner[int(i * step)] for i in range(20)]
    return picks

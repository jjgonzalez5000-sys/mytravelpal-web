"""HERE Fuel Prices provider — pan-European real prices via HERE.

Rationale: `GovFuelProvider` covers ES/FR/IT via free national feeds.
Everything else (DE, PT, BE, NL, AT, CH, PL, GR, Balkans, Nordics)
falls to the `NominatimFuelProvider` today, which returns
`price_available=False` — stations show but with no price to compare.

HERE Fuel Prices covers 30+ European countries commercially, is
freemium (250 k requests/month across the platform), and gives real
€/L per station keyed by station id + brand. We call it for every
route corridor sample point covering countries the gov feeds do NOT
handle, so we don't burn quota on ES/FR/IT where we already have
open data.

Key acquisition: register at platform.here.com; the REST API key
lives in Fly secrets as `MYTRAVELPAL_HERE_API_KEY`. When the
environment variable is missing this provider returns `()` — safe
for local dev without credentials.
"""

from __future__ import annotations

import asyncio
import logging
import os
from typing import Any

import httpx

from app.domain import Coordinate, Country, Route
from app.services.country_detection import detect_country
from app.providers.fuel import FuelPrice

_log = logging.getLogger(__name__)

# HERE Places v7 endpoint. `browse` supports category + at + radius +
# limit; the `fuelStation` category (600-1200-0000) returns pumps
# with an `extended.fuelStation.prices` array carrying per-fuel-type
# per-litre EUR.
_ENDPOINT = "https://browse.search.hereapi.com/v1/browse"
_CATEGORY_FUEL = "700-7600-0116"  # Petrol / Diesel / Gas station
_MAX_RESULTS_PER_SAMPLE = 20
# Distance between corridor samples. Every 100 km covers most
# highways adequately without exhausting request quota on long
# trips (Zurich → Toledo ≈ 20 samples → 20 HERE requests).
_SAMPLE_STEP_KM = 100.0
# Hard cap on samples per call. A CH → RO trip is ~1600 km, which
# at 100 km spacing wants 16 samples; run in parallel that's fine,
# but a runaway route (great-circle fallback drawing 3000+ km)
# would otherwise stack 30+ concurrent HERE calls. Cap at 20 so the
# fan-out stays within HERE's fair-use rate and the wait_for
# budget below.
_MAX_SAMPLES = 20
# Radius per sample. 15 km catches highway-adjacent stations
# comfortably without pulling city-centre pumps that would never
# see a highway driver.
_SAMPLE_RADIUS_M = 15_000
_TIMEOUT_S = 6.0
# Wall-clock cap for the whole `prices_along` call. Individual
# samples run concurrently, so a slow HERE endpoint can no longer
# multiply out to `n_samples × _TIMEOUT_S` and starve the enrichment
# gather. On timeout we return whatever partial data has arrived.
_ALONG_BUDGET_S = 20.0

# Countries where the gov feeds already carry live prices. We skip
# HERE calls for these so the free-tier budget goes to the
# uncovered majority.
_SKIP_COUNTRIES: frozenset[Country] = frozenset(
    {Country.ES, Country.FR, Country.IT},
)


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


class HereFuelProvider:
    """FuelProvider backed by HERE Fuel Prices.

    Fills the gap for countries without a public government feed.
    Returns an empty tuple when no API key is configured.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        key = _api_key()
        if not key:
            return ()
        if not route.geometry or route.distance_km <= 0:
            return ()
        # Diesel / gasoline default — HERE returns both when
        # available. EV fleet still routes through Geoapify EV.
        if (fuel_type or "").lower() == "electric":
            return ()
        sample_points = _corridor_samples(route)
        # Fire every sample concurrently — the old sequential loop
        # multiplied out to `n × _TIMEOUT_S` on long routes (17 samples
        # × 6 s = 102 s worst case) and was the single biggest reason a
        # CH → RO /plan blew past the client's 120 s timeout.
        skip_mask: list[Country | None] = []
        browse_coros: list = []
        for coord, _distance_km in sample_points:
            country = detect_country(coord)
            skip_mask.append(country)
            if country is None or country in _SKIP_COUNTRIES:
                # Placeholder coroutine that resolves to [] so the
                # gather stays aligned with `sample_points` — cheaper
                # than filtering the list twice.
                async def _skip() -> list[dict[str, Any]]:
                    return []
                browse_coros.append(_skip())
            else:
                browse_coros.append(self._browse(coord, key))
        try:
            gathered = await asyncio.wait_for(
                asyncio.gather(*browse_coros, return_exceptions=True),
                timeout=_ALONG_BUDGET_S,
            )
        except asyncio.TimeoutError:
            _log.warning(
                "HERE fuel prices_along exceeded %.0fs budget "
                "for %d samples; returning empty",
                _ALONG_BUDGET_S, len(sample_points),
            )
            return ()
        seen_ids: set[str] = set()
        out: list[FuelPrice] = []
        for (coord, distance_km), country, result in zip(
            sample_points, skip_mask, gathered,
        ):
            if country is None or country in _SKIP_COUNTRIES:
                continue
            if isinstance(result, BaseException):
                _log.warning("HERE fuel browse errored: %r", result)
                continue
            items = result
            for item in items:
                sid = str(item.get("id") or item.get("resultType") or "")
                if not sid or sid in seen_ids:
                    continue
                seen_ids.add(sid)
                price = _extract_price(item)
                if price is None:
                    continue
                pos = item.get("position") or {}
                lat = pos.get("lat")
                lon = pos.get("lng")
                if lat is None or lon is None:
                    continue
                out.append(FuelPrice(
                    station_name=str(item.get("title") or "Fuel station"),
                    country=country,
                    price_eur_per_l=round(float(price), 3),
                    distance_from_origin_km=round(distance_km, 1),
                    coordinate=Coordinate(lat=float(lat), lon=float(lon)),
                    attributes=_attributes(item),
                ))
        out.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(out)

    async def _browse(
        self, at: Coordinate, key: str,
    ) -> list[dict[str, Any]]:
        params = {
            "at": f"{at.lat:.5f},{at.lon:.5f}",
            "categories": _CATEGORY_FUEL,
            "in": f"circle:{at.lat:.5f},{at.lon:.5f};r={_SAMPLE_RADIUS_M}",
            "limit": _MAX_RESULTS_PER_SAMPLE,
            "apiKey": key,
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE fuel browse failed: %r", exc)
            return []
        if r.status_code != 200:
            _log.warning(
                "HERE fuel browse HTTP %s: %s",
                r.status_code, r.text[:200],
            )
            return []
        try:
            payload = r.json()
        except ValueError:
            return []
        items = payload.get("items")
        return items if isinstance(items, list) else []


def _corridor_samples(route: Route) -> list[tuple[Coordinate, float]]:
    """Return `(coord, cumulative_km)` samples every ~100 km along
    the route geometry. Includes start and end so short trips still
    receive at least one probe.
    """
    if not route.geometry:
        return []
    total_km = route.distance_km
    if total_km <= 0:
        return [(route.geometry[0], 0.0)]
    samples: list[tuple[Coordinate, float]] = []
    # Adaptive spacing: aim for one sample per _SAMPLE_STEP_KM, but
    # hard-cap at _MAX_SAMPLES so a runaway route (or great-circle
    # fallback) can't blow up the fan-out. Long trips end up sampling
    # every ~total_km / _MAX_SAMPLES km instead of every 100 km.
    n_samples = max(1, min(_MAX_SAMPLES, int(total_km / _SAMPLE_STEP_KM)))
    step = 1.0 / max(1, n_samples)
    for i in range(n_samples + 1):
        fraction = min(1.0, i * step)
        idx = int(fraction * (len(route.geometry) - 1))
        samples.append((route.geometry[idx], fraction * total_km))
    return samples


def _extract_price(item: dict[str, Any]) -> float | None:
    """Dig a per-litre EUR price out of the HERE Browse response.

    HERE's fuel-station schema exposes an `extended.fuelStation.prices`
    array with entries like `{"type": "diesel", "price": 1.789,
    "currency": "EUR", "unit": "l"}`. Prefer diesel (Europe's
    dominant road fuel) → SP95 → SP98 → any.
    """
    ext = item.get("extended") or {}
    fs = ext.get("fuelStation") or {}
    prices = fs.get("prices") or []
    if not isinstance(prices, list):
        return None
    preferred = ("diesel", "petrol_95", "petrol_98", "e10", "sp95", "sp98")
    for want in preferred:
        for p in prices:
            if not isinstance(p, dict):
                continue
            if str(p.get("type", "")).lower() == want and \
                    str(p.get("currency", "")).upper() == "EUR":
                val = p.get("price")
                if isinstance(val, (int, float)):
                    return float(val)
    # Fallback: first EUR entry regardless of type.
    for p in prices:
        if not isinstance(p, dict):
            continue
        if str(p.get("currency", "")).upper() == "EUR":
            val = p.get("price")
            if isinstance(val, (int, float)):
                return float(val)
    return None


def _attributes(item: dict[str, Any]) -> tuple[tuple[str, str], ...]:
    """Curate a small set of user-visible tags for the mobile
    detail sheet — brand and opening hours are the two the driver
    actually looks at when choosing a station.
    """
    ext = item.get("extended") or {}
    fs = ext.get("fuelStation") or {}
    brand = fs.get("brandName") or item.get("chains", [{}])[0].get(
        "name",
    ) if isinstance(item.get("chains"), list) else None
    hours = fs.get("openingHours") or item.get("openingHours")
    attrs: list[tuple[str, str]] = []
    if brand:
        attrs.append(("brand", str(brand)))
    if isinstance(hours, str):
        attrs.append(("opening_hours", hours))
    elif isinstance(hours, list) and hours:
        first = hours[0]
        if isinstance(first, dict) and first.get("text"):
            attrs.append(("opening_hours", str(first["text"])))
    return tuple(attrs)

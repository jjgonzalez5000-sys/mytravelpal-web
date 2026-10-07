"""Austrian fuel prices from e-control.at (Spritpreisrechner).

The Austrian energy regulator e-control.at publishes real-time pump
prices for every Austrian station via a public REST API — no key, no
registration.

Endpoint: GET /sprit/1.0/search/gas-stations/by-address
  ?latitude={lat}&longitude={lon}&fuelType={DIE|SUP|GAS}
  &includeClosed=false

Returns stations sorted by distance from the query coordinate. Each
station has a `prices` array with per-fuel-type amounts in EUR/L.

Design notes:
- Unlike the Spain/France/Italy datasets there is no national bulk
  download, so we use corridor sampling (same as HereFuelProvider):
  one API call per sample point every ~80 km along the AT portion of
  the route.
- Stations are de-duplicated by station ID across samples.
- Results are filtered to the route corridor (< _MAX_OFF_CORRIDOR_KM
  from any route geometry vertex) before being returned.
- Concurrency: all sample fetches are gathered concurrently with a
  wall-clock budget cap (_ALONG_BUDGET_S) to avoid starving the event
  loop on multi-sample routes (Vienna → Innsbruck is ~6 samples).
"""

from __future__ import annotations

import asyncio
import logging
import math
from typing import Any

import httpx

from app.domain import Coordinate, Country, Route
from app.providers.fuel import FuelPrice
from app.services.country_detection import detect_country

_log = logging.getLogger(__name__)

_ENDPOINT = (
    "https://api.e-control.at/sprit/1.0/search/gas-stations/by-address"
)

# Corridor sample spacing. Austria's longest axis is ~600 km (W-E),
# so 80 km spacing gives at most 8 samples — within the concurrent
# budget. Smaller than HERE's 100 km step because AT is denser and
# the API is lightweight (no paid quota).
_SAMPLE_STEP_KM = 80.0
_MAX_SAMPLES = 15
_ALONG_BUDGET_S = 15.0
_TIMEOUT_S = 6.0

# Filter: stations further than this from the corridor are ignored —
# nobody detours 10 km for petrol.
_MAX_OFF_CORRIDOR_KM = 8.0

# e-control fuelType codes.
_FUEL_TYPE_MAP: dict[str, str] = {
    "diesel": "DIE",
    "petrol": "SUP",
    "sp95": "SUP",
    "sp98": "SUP",
    "lpg": "GAS",
}
_DEFAULT_FUEL_CODE = "DIE"

# Internal canonical key for the display label (mirrors fuel_gov.py).
_CODE_TO_KEY: dict[str, str] = {
    "DIE": "diesel",
    "SUP": "sp95",
    "GAS": "lpg",
}

_USER_AGENT = "MyTravelPal/1.0 (+https://mytravelpal.app)"


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    R = 6371.0
    lat1, lon1 = math.radians(a.lat), math.radians(a.lon)
    lat2, lon2 = math.radians(b.lat), math.radians(b.lon)
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    return 2 * R * math.asin(math.sqrt(h))


def _corridor_samples(route: Route) -> list[tuple[Coordinate, float]]:
    """Return (coord, cumulative_km) corridor samples for AT segments.

    Mirrors the logic in fuel_here.py: samples every _SAMPLE_STEP_KM
    along the route geometry, capped at _MAX_SAMPLES to limit fan-out.
    """
    if not route.geometry:
        waypoints = [route.origin, *(route.waypoints or ()), route.destination]
        if len(waypoints) < 2:
            return []
        samples: list[tuple[Coordinate, float]] = [(waypoints[0], 0.0)]
        cum = 0.0
        for prev, cur in zip(waypoints, waypoints[1:]):
            cum += _haversine_km(prev, cur)
            samples.append((cur, cum))
        return samples

    total_km = route.distance_km
    if total_km <= 0:
        return [(route.geometry[0], 0.0)]

    n = max(1, min(_MAX_SAMPLES, int(total_km / _SAMPLE_STEP_KM)))
    step = 1.0 / max(1, n)
    samples = []
    for i in range(n + 1):
        fraction = min(1.0, i * step)
        idx = int(fraction * (len(route.geometry) - 1))
        samples.append((route.geometry[idx], fraction * total_km))
    return samples


def _route_reference_points(route: Route) -> tuple[Coordinate, ...]:
    """Down-sampled route geometry for corridor distance checks."""
    dense = route.geometry or (route.origin, *route.waypoints, route.destination)
    if len(dense) <= 30:
        return tuple(dense)
    step = max(1, len(dense) // 150)
    sampled = list(dense[::step])
    if sampled[0] is not dense[0]:
        sampled.insert(0, dense[0])
    if sampled[-1] is not dense[-1]:
        sampled.append(dense[-1])
    return tuple(sampled)


def _distance_to_corridor(
    point: Coordinate, reference: tuple[Coordinate, ...],
) -> float:
    return min(_haversine_km(point, p) for p in reference)


class EControlAustriaFuelProvider:
    """FuelProvider for Austria backed by e-control.at Spritpreisrechner.

    Returns real pump prices (price_available=True) for every Austrian
    station in the route corridor. No API key required.

    Used by HybridFuelProvider as the AT-specific real-price source,
    slotted between the gov-feed layer (ES/FR/IT) and the Nominatim
    fallback.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(
            timeout=_TIMEOUT_S,
            headers={"User-Agent": _USER_AGENT, "Accept": "application/json"},
            follow_redirects=True,
        )

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        if (fuel_type or "").lower() == "electric":
            return ()

        crossed = set(route.countries_crossed or ())
        if Country.AT not in crossed:
            return ()

        fuel_code = _FUEL_TYPE_MAP.get(
            (fuel_type or "diesel").lower(), _DEFAULT_FUEL_CODE,
        )
        reference = _route_reference_points(route)
        sample_points = _corridor_samples(route)

        # Filter samples to AT-only coordinates to avoid burning calls
        # on the Spanish / French / Italian legs of a pan-European route.
        at_samples: list[tuple[Coordinate, float]] = []
        for coord, dist_km in sample_points:
            country = detect_country(coord)
            if country is Country.AT:
                at_samples.append((coord, dist_km))

        if not at_samples:
            _log.debug("EControlAT: no AT-country sample points on route")
            return ()

        fetch_coros = [
            self._fetch(coord, fuel_code) for coord, _ in at_samples
        ]
        try:
            gathered = await asyncio.wait_for(
                asyncio.gather(*fetch_coros, return_exceptions=True),
                timeout=_ALONG_BUDGET_S,
            )
        except asyncio.TimeoutError:
            _log.warning(
                "EControlAT: exceeded %.0fs budget for %d samples; "
                "returning empty",
                _ALONG_BUDGET_S, len(at_samples),
            )
            return ()

        seen_ids: set[int] = set()
        out: list[FuelPrice] = []
        for (coord, sample_dist_km), result in zip(at_samples, gathered):
            if isinstance(result, BaseException):
                _log.warning("EControlAT fetch errored: %r", result)
                continue
            stations: list[dict[str, Any]] = result
            for st in stations:
                sid = st.get("id")
                if not isinstance(sid, int) or sid in seen_ids:
                    continue
                loc = st.get("location") or {}
                lat = loc.get("latitude")
                lon = loc.get("longitude")
                if lat is None or lon is None:
                    continue
                try:
                    coord_st = Coordinate(lat=float(lat), lon=float(lon))
                except ValueError:
                    continue

                # Corridor filter — drop stations further than the
                # threshold from the actual route polyline.
                off_km = _distance_to_corridor(coord_st, reference)
                if off_km > _MAX_OFF_CORRIDOR_KM:
                    continue

                price_eur = _pick_price(st.get("prices") or [], fuel_code)
                price_ok = price_eur is not None
                if price_eur is None:
                    continue  # skip stations with no price data at all

                seen_ids.add(sid)
                name = str(st.get("name") or "Tankstelle")
                fuel_key = _CODE_TO_KEY.get(fuel_code, "diesel")
                attrs: list[tuple[str, str]] = [("primary_fuel", fuel_key)]
                # Expose all available prices in attributes so the
                # mobile detail sheet can show the full breakdown.
                for p in st.get("prices") or []:
                    k = _CODE_TO_KEY.get(str(p.get("fuelType") or ""), "")
                    v = p.get("amount")
                    if k and isinstance(v, (int, float)) and v > 0:
                        attrs.append((k, f"{v:.3f}"))

                out.append(FuelPrice(
                    station_name=name,
                    country=Country.AT,
                    price_eur_per_l=round(float(price_eur), 3),
                    distance_from_origin_km=round(
                        _haversine_km(route.origin, coord_st), 1,
                    ),
                    coordinate=coord_st,
                    attributes=tuple(attrs),
                    price_available=True,
                ))

        _log.info(
            "EControlAT: %d AT stations in corridor "
            "(%d samples, %d unique)",
            len(out), len(at_samples), len(seen_ids),
        )
        out.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(out)

    async def _fetch(
        self, at: Coordinate, fuel_code: str,
    ) -> list[dict[str, Any]]:
        params = {
            "latitude": f"{at.lat:.5f}",
            "longitude": f"{at.lon:.5f}",
            "fuelType": fuel_code,
            "includeClosed": "false",
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("EControlAT request failed: %r", exc)
            return []
        if r.status_code != 200:
            _log.warning(
                "EControlAT HTTP %s: %s", r.status_code, r.text[:200],
            )
            return []
        try:
            data = r.json()
        except ValueError:
            return []
        return data if isinstance(data, list) else []


def _pick_price(
    prices: list[dict[str, Any]], preferred_code: str,
) -> float | None:
    """Return the EUR/L price for the preferred fuel code, or any
    available price when the preferred type is not stocked.
    """
    fallback: float | None = None
    for p in prices:
        code = str(p.get("fuelType") or "")
        amount = p.get("amount")
        if not isinstance(amount, (int, float)) or amount <= 0:
            continue
        if code == preferred_code:
            return float(amount)
        if fallback is None:
            fallback = float(amount)
    return fallback

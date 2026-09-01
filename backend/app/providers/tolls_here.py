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
from typing import Any

import httpx

from app.domain import Route
from app.providers.tollguru import TollBooth, TollQuote

_log = logging.getLogger(__name__)

_ENDPOINT = "https://router.hereapi.com/v8/routes"
_TIMEOUT_S = 8.0


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
            # Approximate the booth position at the midpoint of
            # the section's polyline endpoints — HERE returns
            # section-level fares, not booth-level.
            dep = section.get("departure", {}).get("place", {}).get(
                "location", {},
            )
            arr = section.get("arrival", {}).get("place", {}).get(
                "location", {},
            )
            mid_lat: float | None = None
            mid_lon: float | None = None
            if dep and arr:
                try:
                    mid_lat = (float(dep["lat"]) + float(arr["lat"])) / 2
                    mid_lon = (float(dep["lng"]) + float(arr["lng"])) / 2
                except (TypeError, ValueError, KeyError):
                    mid_lat = mid_lon = None
            for toll in tolls:
                # HERE returns MULTIPLE `fares` per toll section —
                # one per payment method (cash, tag, video). Emitting
                # a TollBooth per fare produced the duplicate rows
                # testers saw. Pick the MIN EUR fare (usually the
                # tag / video price the driver would actually pay
                # with a modern electronic system) and emit one
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
                booths.append(TollBooth(
                    name=str(
                        toll.get("tollSystem") or toll.get("name")
                        or "Toll section",
                    ),
                    cost_eur=round(val, 2),
                    lat=mid_lat if mid_lat is not None else 0.0,
                    lon=mid_lon if mid_lon is not None else 0.0,
                ))
        return TollQuote(total_eur=round(total_eur, 2), tolls=tuple(booths))


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

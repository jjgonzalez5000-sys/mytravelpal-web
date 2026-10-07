"""TollGuru toll-cost provider.

TollGuru (https://tollguru.com/developers) is a commercial API that
returns booth-level toll fares for a route encoded as a polyline. It
knows individual toll gates, per-vehicle-class fares, subscription
discounts, and time-of-day pricing where applicable — everything our
current mock approximates.

Integration outline:
1. Encode the route geometry as a polyline (Google encoded polyline).
2. POST it to `https://apis.tollguru.com/toll/v2/complete-polyline-from-mapping-service`
   with `x-api-key`.
3. Parse `costs.tag`, `costs.cash`, `tolls[]` from the response.

This module ships the wire code and env-var gating; without
`TOLLGURU_API_KEY` the composite falls back to the mock toll pricing
we've been using (per-km + vignette from `data.countries`).

Design note: TollGuru returns a *replacement* for whole-route toll
pricing plus per-toll data that will power the `partial_toll_skips`
service with real numbers instead of the current heuristic.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Protocol

import httpx

from app.domain import Route

_log = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class TollQuote:
    total_eur: float
    tolls: tuple["TollBooth", ...]


@dataclass(frozen=True, slots=True)
class TollBooth:
    name: str
    cost_eur: float
    lat: float        # entry gate position
    lon: float
    exit_lat: float = 0.0   # exit gate position (section-level providers)
    exit_lon: float = 0.0
    operator: str = ""      # toll operator name (e.g. "ASF", "APRR") for gate filtering
    # True when this "toll" is actually a country-wide vignette /
    # e-toll sticker (AT, CH, RO, HU, SK, CZ, SI, BG). These are
    # NOT skippable via a parallel road — every motorway in the
    # country requires the sticker. The partial-toll-skips service
    # filters them out; the total cost still applies, tagged as
    # mandatory in the trip cost breakdown.
    is_vignette: bool = False


class TollProvider(Protocol):
    async def quote(self, route: Route, *, vehicle_class: str = "2AxlesAuto") -> TollQuote | None:
        """Return a booth-level toll quote or None when the provider
        can't answer (missing key, network error, unsupported route).
        """
        ...


# In-process cache: (origin_grid, dest_grid, vehicle_class) → (timestamp, TollQuote|None)
# Toll prices change at most a few times per year — 48h TTL is conservative and safe.
# Grid resolution ~2 km so two nearby origins share the same cache entry.
_TOLL_CACHE: dict[tuple, tuple[float, "TollQuote | None"]] = {}
_TOLL_CACHE_TTL_S = 48 * 3600
_TOLL_CACHE_GRID = 100  # round lat/lon to 2 decimal places ≈ 1.1 km


def _route_cache_key(route: Route, vehicle_class: str) -> tuple:
    return (
        round(route.origin.lat, 2),
        round(route.origin.lon, 2),
        round(route.destination.lat, 2),
        round(route.destination.lon, 2),
        vehicle_class,
    )


class TollGuruProvider:
    """Real toll pricing via TollGuru's `complete-polyline-from-mapping-service`.

    Results are cached 48 h by (origin, destination, vehicle_class) so the
    same Madrid→Barcelona route only calls TollGuru once per two days, not
    once per plan request. This cuts transaction usage by 10-100× in practice.
    """

    _URL = (
        "https://apis.tollguru.com/toll/v2/"
        "complete-polyline-from-mapping-service"
    )

    def __init__(
        self,
        api_key: str | None = None,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._api_key = api_key or os.environ.get("TOLLGURU_API_KEY")
        self._client = http_client or httpx.AsyncClient(timeout=8.0)

    async def quote(
        self, route: Route, *, vehicle_class: str = "2AxlesAuto",
    ) -> TollQuote | None:
        if not self._api_key or not route.geometry:
            return None

        # Cache check — avoids redundant API calls for the same corridor.
        import time
        cache_key = _route_cache_key(route, vehicle_class)
        cached = _TOLL_CACHE.get(cache_key)
        if cached is not None:
            ts, result = cached
            if time.monotonic() - ts < _TOLL_CACHE_TTL_S:
                _log.debug("TollGuru cache HIT for %s", cache_key)
                return result

        polyline = _encode_polyline(
            [(p.lat, p.lon) for p in route.geometry],
        )
        try:
            response = await self._client.post(
                self._URL,
                headers={
                    "x-api-key": self._api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "source": "here",
                    "polyline": polyline,
                    "vehicleType": vehicle_class,
                },
            )
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPError as exc:
            _log.warning("TollGuru request failed: %s", exc)
            _TOLL_CACHE[cache_key] = (time.monotonic(), None)
            return None
        except ValueError:
            return None

        route_data = (body.get("routes") or [None])[0]
        if not route_data:
            return None
        costs = route_data.get("costs") or {}
        total = float(costs.get("tag") or costs.get("cash") or 0.0)
        tolls_out: list[TollBooth] = []
        for toll in route_data.get("tolls") or []:
            try:
                tolls_out.append(
                    TollBooth(
                        name=str(toll.get("name") or "Toll booth"),
                        cost_eur=float(toll.get("tagCost") or toll.get("cashCost") or 0.0),
                        lat=float(toll.get("lat") or 0.0),
                        lon=float(toll.get("lng") or 0.0),
                    )
                )
            except (TypeError, ValueError):
                continue
        result = TollQuote(total_eur=round(total, 2), tolls=tuple(tolls_out))
        _TOLL_CACHE[cache_key] = (time.monotonic(), result)
        return result


def _encode_polyline(points: list[tuple[float, float]]) -> str:
    """Google encoded-polyline algorithm.

    Compact ASCII encoding of a list of (lat, lon). Bundled here to
    avoid pulling in a whole geometry library for one function.
    """
    result: list[str] = []
    prev_lat = 0
    prev_lon = 0
    for lat, lon in points:
        lat_i = round(lat * 1e5)
        lon_i = round(lon * 1e5)
        result.append(_encode(lat_i - prev_lat))
        result.append(_encode(lon_i - prev_lon))
        prev_lat = lat_i
        prev_lon = lon_i
    return "".join(result)


def _encode(value: int) -> str:
    value = ~(value << 1) if value < 0 else value << 1
    chunks: list[str] = []
    while value >= 0x20:
        chunks.append(chr((0x20 | (value & 0x1f)) + 63))
        value >>= 5
    chunks.append(chr(value + 63))
    return "".join(chunks)

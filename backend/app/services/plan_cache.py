"""Response cache for the `POST /v1/trips/plan` endpoint.

Wraps repeated / near-identical trip plans behind a 10-minute TTL so
we don't re-fan-out to OSRM, Geoapify, Open-Meteo, TollGuru, and the
adverse-events providers when the same driver replays the same query
(or hits refresh from a slightly different departure minute).

Storage precedence:

1. **Redis** when `settings.redis_url` is set — shared across every
   Fly machine in the region, survives suspend/resume.
2. **In-process `TTLCache`** as a silent fallback — used when
   `REDIS_URL` is unset, when the Redis client fails to init, or
   when a live Redis op raises (we downgrade the whole cache to
   memory for the process life, no per-op retry noise in logs).

Cache key derivation lives in :py:meth:`PlanCache.key_for` and is
tuned to maximise hit-rate without cross-invalidating plans that
differ in a meaningful way (see docstring for the exact whitelist
and the hour-bucketing rule on ``desired_departure_at``).
"""

from __future__ import annotations

import hashlib
import json
import logging
from enum import Enum
from typing import TYPE_CHECKING, Any

from cachetools import TTLCache

from app.config import settings

if TYPE_CHECKING:  # avoid circular import with app.api.v1.trips
    from app.api.v1.trips import TripPlanRequest, TripPlanResponse

_log = logging.getLogger(__name__)

# 10-minute TTL — traffic + weather change slowly enough that a
# short-lived reuse window is safe. Bumping this without adding a
# provider-driven bust would risk showing stale toll / adverse-event
# data.
_TTL_SECONDS = 600
# Enrich payloads carry hotel prices + fuel + weather, all of which
# turn over faster than the core route. Use a shorter 5-minute TTL
# so a driver hitting refresh 6 min after their first plan sees the
# updated numbers.
_ENRICH_TTL_SECONDS = 300
_MEMORY_MAX = 200
# Bump to throw away every cached plan at once (a Redis cache survives
# deploys): old entries simply stop matching. 2026-10-10: toll estimate fix.
_CACHE_VERSION = "2026-10-10a"


class PlanCacheSlot(str, Enum):
    """Namespaces the three plan-response variants share the cache with.

    ``CORE`` is the fast route + days shape returned by
    ``POST /v1/trips/plan/core``. ``ENRICH`` is the slow POI/weather
    shape returned by ``POST /v1/trips/plan/enrich``. ``FULL`` is the
    merged legacy response returned by ``POST /v1/trips/plan``.

    Appending the slot value to the canonical JSON before hashing keeps
    the three variants from colliding when a client fires them for the
    same trip in quick succession.
    """

    CORE = "core"
    ENRICH = "enrich"
    FULL = "full"


def _round_coord(value: float) -> float:
    """Round to 4 decimals (~11 m at the equator).

    Users tapping the map hit the same POI within centimetres of
    precision; 4 decimals is generous enough that repeated taps on
    the same landmark collide on the cache key without ever making
    two distinct addresses collide.
    """

    return round(float(value), 4)


def _bucket_departure_to_hour(iso_or_dt: Any) -> str:
    """Bucket a datetime to ``YYYY-MM-DD HH:00``.

    Traffic and weather don't change materially within an hour, so
    08:15 and 08:45 should hit the same cache slot. Accepts either
    a ``datetime`` or an ISO string (the pydantic dump form).
    """

    from datetime import datetime  # local import: hot path is rare

    if isinstance(iso_or_dt, datetime):
        dt = iso_or_dt
    else:
        # `datetime.fromisoformat` handles both naive and tz-aware.
        dt = datetime.fromisoformat(str(iso_or_dt))
    return dt.strftime("%Y-%m-%d %H:00")


def _waypoint_key(w: dict[str, Any]) -> tuple[float, float, int, str]:
    return (
        _round_coord(w.get("lat", 0.0)),
        _round_coord(w.get("lon", 0.0)),
        int(w.get("dwell_nights", 0) or 0),
        str(w.get("label") or ""),
    )


class PlanCache:
    """Thin wrapper over Redis + in-process TTL fallback.

    The class is intentionally forgiving: any Redis-side exception
    demotes the cache to memory for the rest of the process life,
    so a flaky broker never turns a plan into a 500.
    """

    def __init__(self, redis_url: str | None) -> None:
        self._redis_url = redis_url
        self._redis: Any | None = None
        self._redis_broken = False
        # Two TTL caches so the in-memory fallback can honour the
        # shorter enrich TTL. Keys are namespaced by slot (see
        # ``key_for``), so entries never collide across the two.
        self._memory: TTLCache[str, str] = TTLCache(
            maxsize=_MEMORY_MAX, ttl=_TTL_SECONDS
        )
        self._memory_enrich: TTLCache[str, str] = TTLCache(
            maxsize=_MEMORY_MAX, ttl=_ENRICH_TTL_SECONDS
        )
        if redis_url:
            try:
                import redis.asyncio as aioredis  # type: ignore[import-not-found]

                self._redis = aioredis.from_url(
                    redis_url,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=1.5,
                )
                _log.info("plan_cache: Redis wired at %s", _mask_url(redis_url))
            except Exception as exc:  # noqa: BLE001
                _log.warning(
                    "plan_cache: Redis init failed (%r) — falling back to in-memory",
                    exc,
                )
                self._redis = None
                self._redis_broken = True
        else:
            _log.info(
                "plan_cache: REDIS_URL not set — using in-memory TTLCache "
                "(maxsize=%d, ttl=%ds)",
                _MEMORY_MAX,
                _TTL_SECONDS,
            )

    # ---- key derivation ------------------------------------------------

    def key_for(
        self,
        payload: TripPlanRequest,
        slot: PlanCacheSlot = PlanCacheSlot.FULL,
    ) -> str:
        """SHA-256 over a stable JSON of the whole request.

        We hash the full ``model_dump`` — everything that reaches the
        provider fan-out affects the response, so leaving any field
        out risks a stale hit. Only three groups get normalised for
        broader collision:

        * ``origin`` / ``destination`` — coords rounded to 4 decimals
          (~11 m at the equator) so hand-tap jitter still collides.
        * ``waypoints`` — sorted by (lat, lon, dwell_nights, label);
          also 4-decimal-rounded.
        * ``desired_departure_at`` — bucketed to the hour, so 08:15
          and 08:45 share a cache slot (traffic/weather don't move
          materially within an hour).

        Everything else (filter toggles, trip_profile blob, garage
        vehicle id, feature flags) is passed through as-is.

        The ``slot`` argument namespaces the digest — ``/plan``,
        ``/plan/core`` and ``/plan/enrich`` therefore have distinct
        keys even for the same underlying request, so hitting one
        never returns a payload shape the caller wasn't expecting.
        """

        data = payload.model_dump(mode="json")

        origin = data.get("origin") or {}
        data["origin"] = {
            "lat": _round_coord(origin.get("lat", 0.0)),
            "lon": _round_coord(origin.get("lon", 0.0)),
        }
        destination = data.get("destination") or {}
        data["destination"] = {
            "lat": _round_coord(destination.get("lat", 0.0)),
            "lon": _round_coord(destination.get("lon", 0.0)),
        }
        waypoints_sorted = sorted(
            _waypoint_key(w) for w in (data.get("waypoints") or [])
        )
        data["waypoints"] = [
            {
                "lat": lat,
                "lon": lon,
                "dwell_nights": dwell,
                "label": label,
            }
            for (lat, lon, dwell, label) in waypoints_sorted
        ]
        data["desired_departure_at"] = _bucket_departure_to_hour(
            data.get("desired_departure_at")
        )

        canonical = json.dumps(data, sort_keys=True, separators=(",", ":"))
        # Slot suffix keeps the three variants in distinct namespaces
        # without polluting the payload dict itself.
        canonical = f"{canonical}|slot={slot.value}|v={_CACHE_VERSION}"
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    # ---- storage ops --------------------------------------------------

    async def get(self, key: str) -> TripPlanResponse | None:
        raw = await self._raw_get(key)
        if raw is None:
            return None
        # Late import: TripPlanResponse lives inside the endpoint
        # module, which imports this file. Deferring the import until
        # first use breaks the cycle without needing to relocate the
        # response schema.
        from app.api.v1.trips import TripPlanResponse

        try:
            return TripPlanResponse.model_validate_json(raw)
        except Exception as exc:  # noqa: BLE001
            _log.warning(
                "plan_cache: dropping malformed cached payload (%r)", exc
            )
            return None

    async def set(
        self,
        key: str,
        response: TripPlanResponse,
        ttl_seconds: int | None = None,
    ) -> None:
        """Persist ``response`` under ``key`` with an optional TTL.

        Callers pass ``ttl_seconds=_ENRICH_TTL_SECONDS`` for the
        enrich slot (POI + weather turn over faster than core route).
        Omitting the argument uses the 10-minute default that also
        covers ``/plan`` (FULL) and ``/plan/core``. Both Redis and the
        in-memory fallback honour the value.
        """

        data = response.model_dump_json()
        await self._raw_set(key, data, ttl_seconds)

    async def _raw_get(self, key: str) -> str | None:
        if self._redis is not None and not self._redis_broken:
            try:
                got = await self._redis.get(key)
                if got is not None:
                    return got
            except Exception as exc:  # noqa: BLE001
                _log.warning(
                    "plan_cache: Redis GET failed (%r) — demoting to memory",
                    exc,
                )
                self._redis_broken = True
        # Check the enrich TTLCache first — its keys are slot-namespaced
        # so a match here always refers to an enrich payload.
        hit = self._memory_enrich.get(key)
        if hit is not None:
            return hit
        return self._memory.get(key)

    async def _raw_set(
        self,
        key: str,
        data: str,
        ttl_seconds: int | None = None,
    ) -> None:
        effective_ttl = (
            ttl_seconds if ttl_seconds is not None else _TTL_SECONDS
        )
        if self._redis is not None and not self._redis_broken:
            try:
                await self._redis.set(key, data, ex=effective_ttl)
                return
            except Exception as exc:  # noqa: BLE001
                _log.warning(
                    "plan_cache: Redis SET failed (%r) — demoting to memory",
                    exc,
                )
                self._redis_broken = True
        # Route to the enrich TTL cache when the caller asked for a
        # short-lived entry (or any TTL shorter than the default).
        if effective_ttl <= _ENRICH_TTL_SECONDS:
            self._memory_enrich[key] = data
        else:
            self._memory[key] = data


def _mask_url(url: str) -> str:
    """Hide credentials before logging."""

    try:
        from urllib.parse import urlparse

        parsed = urlparse(url)
        if parsed.password:
            netloc = f"{parsed.username or ''}:***@{parsed.hostname or ''}"
            if parsed.port:
                netloc = f"{netloc}:{parsed.port}"
            return parsed._replace(netloc=netloc).geturl()
    except Exception:  # noqa: BLE001
        pass
    return url


_singleton: PlanCache | None = None


def get_plan_cache() -> PlanCache:
    """Process-wide singleton so the in-memory fallback survives across
    requests. Tests can bypass this by constructing ``PlanCache`` directly.
    """

    global _singleton
    if _singleton is None:
        _singleton = PlanCache(redis_url=settings.redis_url)
    return _singleton


def reset_plan_cache_for_tests() -> None:
    """Test hook: wipe the singleton so a fresh cache is built.

    Not used in production code paths.
    """

    global _singleton
    _singleton = None

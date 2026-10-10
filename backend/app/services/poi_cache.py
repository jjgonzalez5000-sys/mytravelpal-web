"""Shared cache and usage accounting for Geoapify Places calls.

Hotels, restaurants and sights near a road change slowly, but every plan used
to re-ask Geoapify for them, and the free plan is 3,000 credits a day (one
request = one credit). This module sits under ``geoapify_poi._search`` and:

* snaps each query outwards to a coarse grid, so two routes that differ by a
  few hundred metres ask for the same area and share one answer;
* keeps answers in memory (L1) and in Postgres (L2, survives deploys), for a
  week, trimmed to the few fields the app reads;
* coalesces identical in-flight queries into one request;
* never stores a failed call (timeout, 429, bad JSON), only real answers;
* counts the real calls per day, logs the spend to ``usage_events`` and raises
  an alert at 70 %, 90 % and 100 % of the daily allowance.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import math
import os
import random
import time
from collections import OrderedDict, defaultdict
from datetime import datetime, timezone
from typing import Any, Awaitable, Callable, Coroutine

_log = logging.getLogger(__name__)

# --- tunables -------------------------------------------------------------

TTL_S = 7 * 24 * 3600
# A real empty answer is worth remembering, but not for as long.
EMPTY_TTL_S = 24 * 3600
L1_MAX_ENTRIES = 500

# Outward snapping. A bigger area than asked is harmless: every caller filters
# the features by distance to its own route afterwards.
RECT_SNAP_DEG = 0.1          # about 11 km north-south
CIRCLE_SNAP_DEG = 0.02       # about 2 km
CIRCLE_MARGIN_M = 1500       # covers moving the centre by up to half a cell
CIRCLE_RADIUS_STEP_M = 500

DAILY_LIMIT = int(os.environ.get("MYTRAVELPAL_GEOAPIFY_DAILY_LIMIT", "3000"))
ALERT_FRACTIONS = (0.7, 0.9, 1.0)

# --- snapping -------------------------------------------------------------


def snap_filter(filter_: str) -> str:
    """Round a Geoapify ``rect:`` / ``circle:`` filter outwards to the grid.

    Unknown or malformed filters are returned untouched."""
    kind, _, rest = filter_.partition(":")
    try:
        nums = [float(x) for x in rest.split(",")]
    except ValueError:
        return filter_
    if kind == "rect" and len(nums) == 4:
        west, south, east, north = nums
        g = RECT_SNAP_DEG
        vals = (
            math.floor(west / g + 1e-9) * g,
            math.floor(south / g + 1e-9) * g,
            math.ceil(east / g - 1e-9) * g,
            math.ceil(north / g - 1e-9) * g,
        )
        return "rect:" + ",".join(f"{v:.3f}" for v in vals)
    if kind == "circle" and len(nums) == 3:
        lon, lat, radius_m = nums
        g = CIRCLE_SNAP_DEG
        step = CIRCLE_RADIUS_STEP_M
        radius = math.ceil((radius_m + CIRCLE_MARGIN_M) / step) * step
        return f"circle:{round(lon / g) * g:.3f},{round(lat / g) * g:.3f},{int(radius)}"
    return filter_


# --- trimming -------------------------------------------------------------

_SCALAR = (str, int, float, bool)


def trim_feature(feature: dict[str, Any]) -> dict[str, Any]:
    """Keep what the app reads from a Geoapify feature, drop the rest
    (polygons, opening-hours trees, source metadata)."""
    props = feature.get("properties")
    props = props if isinstance(props, dict) else {}
    out_props: dict[str, Any] = {
        k: v for k, v in props.items() if isinstance(v, _SCALAR)
    }
    cats = props.get("categories")
    if isinstance(cats, list):
        out_props["categories"] = [c for c in cats if isinstance(c, str)]
    ds = props.get("datasource")
    raw = ds.get("raw") if isinstance(ds, dict) else None
    if isinstance(raw, dict):
        out_props["datasource"] = {
            "raw": {k: v for k, v in raw.items() if isinstance(v, _SCALAR)},
        }
    if props.get("wiki_and_media"):
        out_props["wiki_and_media"] = True
    out: dict[str, Any] = {
        "type": feature.get("type", "Feature"),
        "properties": out_props,
    }
    geom = feature.get("geometry")
    if isinstance(geom, dict) and geom.get("type") == "Point":
        out["geometry"] = {
            "type": "Point", "coordinates": geom.get("coordinates"),
        }
    return out


# --- stats and alerts -----------------------------------------------------

_stats: dict[str, int] = defaultdict(int)
_calls_by_day: dict[str, int] = defaultdict(int)
_alerted: set[tuple[str, float]] = set()
_background: set[asyncio.Task] = set()


def _today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def stats() -> dict[str, Any]:
    """Counters for the diagnostics endpoint."""
    hits = _stats["hit_l1"] + _stats["hit_l2"]
    lookups = hits + _stats["miss"] + _stats["coalesced"]
    today = _calls_by_day.get(_today(), 0)
    return {
        "calls_today": today,
        "daily_limit": DAILY_LIMIT,
        "used_fraction": round(today / DAILY_LIMIT, 3) if DAILY_LIMIT else None,
        "cache_hits_memory": _stats["hit_l1"],
        "cache_hits_database": _stats["hit_l2"],
        "cache_misses": _stats["miss"],
        "coalesced_requests": _stats["coalesced"],
        "failed_calls_not_cached": _stats["failed"],
        "hit_rate": round(hits / lookups, 3) if lookups else None,
        "memory_entries": len(_l1),
    }


def _alert(message: str) -> None:
    _log.error(message)
    try:
        import sentry_sdk

        sentry_sdk.capture_message(message, level="warning")
    except Exception:  # noqa: BLE001 - alerting must never break a request
        pass


def record_call(*, status: int | None, categories: str) -> None:
    """Count one real HTTP call to Geoapify (hit or not, it costs a credit)."""
    day = _today()
    _calls_by_day[day] += 1
    used = _calls_by_day[day]
    for frac in ALERT_FRACTIONS:
        if DAILY_LIMIT and used >= DAILY_LIMIT * frac and (day, frac) not in _alerted:
            _alerted.add((day, frac))
            _alert(
                f"Geoapify: {used}/{DAILY_LIMIT} credits used today "
                f"({int(frac * 100)}% of the daily allowance)",
            )
    if status == 429 and (day, -1.0) not in _alerted:
        _alerted.add((day, -1.0))
        _alert("Geoapify answered 429: the daily quota is exhausted; hotels, "
               "restaurants and suggestions will come back empty until it resets")
    _spawn(_log_usage(status, categories))


async def _log_usage(status: int | None, categories: str) -> None:
    try:
        from app.services.usage_tracking import COST_GEOAPIFY_CALL_EUR, log_event

        await log_event(
            user_id=None, provider="geoapify", endpoint="places",
            cost_eur=COST_GEOAPIFY_CALL_EUR,
            meta={"categories": categories, "status": status},
        )
    except Exception:  # noqa: BLE001
        pass


def _spawn(coro: Coroutine[Any, Any, None]) -> None:
    """Run `coro` in the background; with no running loop, drop it quietly."""
    try:
        task: asyncio.Task[None] = asyncio.get_running_loop().create_task(coro)
    except RuntimeError:
        coro.close()
        return
    _background.add(task)
    task.add_done_callback(_background.discard)


# --- the cache ------------------------------------------------------------

# key -> (expires_at monotonic-free epoch seconds, features)
_l1: "OrderedDict[str, tuple[float, list[dict[str, Any]]]]" = OrderedDict()
_inflight: dict[str, "asyncio.Future[list[dict[str, Any]]]"] = {}


def clear() -> None:
    """Forget everything in memory (tests, and a manual flush)."""
    _l1.clear()
    _inflight.clear()
    _stats.clear()
    _calls_by_day.clear()
    _alerted.clear()


# Bump to ignore every stored answer (e.g. when what is kept per place changes).
_KEY_VERSION = "v2"
# A database round trip must never hold a request for long: the cache is an
# optimisation, a slow or stuck query is treated as a miss.
_DB_TIMEOUT_S = 2.0


class _OwnerAborted(Exception):
    """The request that was fetching a query died (cancelled, crashed): the
    ones waiting on it must fetch for themselves, not inherit its failure."""


def make_key(
    categories: str, snapped_filter: str, limit: int, conditions: str | None,
) -> str:
    raw = f"{_KEY_VERSION}|{categories}|{snapped_filter}|{limit}|{conditions or ''}"
    return hashlib.sha1(raw.encode()).hexdigest()


def _l1_get(key: str) -> list[dict[str, Any]] | None:
    hit = _l1.get(key)
    if hit is None:
        return None
    expires, features = hit
    if expires <= time.time():
        _l1.pop(key, None)
        return None
    _l1.move_to_end(key)
    return features


def _l1_put(key: str, features: list[dict[str, Any]], ttl_s: float) -> None:
    _l1[key] = (time.time() + ttl_s, features)
    _l1.move_to_end(key)
    while len(_l1) > L1_MAX_ENTRIES:
        _l1.popitem(last=False)


async def _db_get(key: str) -> tuple[list[dict[str, Any]], float] | None:
    """(features, seconds left) from Postgres, or None."""
    try:
        from sqlalchemy import text

        from app.db import get_session, is_available

        if not is_available():
            return None

        async def _read():
            async with get_session() as session:
                return (await session.execute(
                    text(
                        "SELECT payload, "
                        "EXTRACT(EPOCH FROM (expires_at - NOW())) "
                        "FROM poi_cache WHERE key = :k AND expires_at > NOW()"
                    ),
                    {"k": key},
                )).first()

        row = await asyncio.wait_for(_read(), timeout=_DB_TIMEOUT_S)
        if row is None:
            return None
        payload = row[0]
        # Stored as a JSON *string* inside the JSONB column (see _db_put), so
        # the key order of every feature survives the round trip.
        if isinstance(payload, str):
            payload = json.loads(payload)
        if not isinstance(payload, list):
            return None
        return payload, float(row[1])
    except Exception as exc:  # noqa: BLE001 - the cache is an optimisation
        _log.warning("poi_cache read failed: %r", exc)
        return None


async def _db_put(key: str, features: list[dict[str, Any]], ttl_s: float) -> None:
    try:
        from sqlalchemy import text

        from app.db import get_session, is_available

        if not is_available():
            return

        async def _write():
            async with get_session() as session:
                await session.execute(
                    text(
                        "INSERT INTO poi_cache (key, payload, expires_at) "
                        "VALUES (:k, CAST(:p AS JSONB), "
                        "NOW() + make_interval(secs => :ttl)) "
                        "ON CONFLICT (key) DO UPDATE SET "
                        "payload = EXCLUDED.payload, fetched_at = NOW(), "
                        "expires_at = EXCLUDED.expires_at"
                    ),
                    # JSONB sorts object keys, which would change which of a
                    # place's tags come first; a JSON string keeps the order.
                    {"k": key, "p": json.dumps(json.dumps(features)),
                     "ttl": float(ttl_s)},
                )
                if random.random() < 0.01:
                    await session.execute(
                        text("DELETE FROM poi_cache WHERE expires_at < NOW()"),
                    )
                await session.commit()

        await asyncio.wait_for(_write(), timeout=_DB_TIMEOUT_S)
    except Exception as exc:  # noqa: BLE001
        _log.warning("poi_cache write failed: %r", exc)


FetchResult = tuple[list[dict[str, Any]], bool]


async def get_or_fetch(
    categories: str,
    snapped_filter: str,
    limit: int,
    conditions: str | None,
    fetch: Callable[[], Awaitable[FetchResult]],
) -> list[dict[str, Any]]:
    """Cached features for a query, calling ``fetch`` only on a miss.

    ``fetch`` returns ``(features, ok)``; only ``ok`` answers are stored."""
    key = make_key(categories, snapped_filter, limit, conditions)

    cached = _l1_get(key)
    if cached is not None:
        _stats["hit_l1"] += 1
        return cached

    # Register before the first await below, so concurrent identical queries
    # (including the database lookup, which suspends) join this one.
    pending = _inflight.get(key)
    if pending is not None:
        _stats["coalesced"] += 1
        try:
            return await asyncio.shield(pending)
        except _OwnerAborted:
            # The request that was fetching died (a timeout upstream
            # cancelled it): do the work ourselves instead of inheriting it.
            return await get_or_fetch(
                categories, snapped_filter, limit, conditions, fetch,
            )

    loop = asyncio.get_running_loop()
    future: "asyncio.Future[list[dict[str, Any]]]" = loop.create_future()
    _inflight[key] = future
    try:
        from_db = await _db_get(key)
        if from_db is not None:
            features, left = from_db
            _l1_put(key, features, left)
            _stats["hit_l2"] += 1
            if not future.done():
                future.set_result(features)
            return features

        _stats["miss"] += 1
        raw, ok = await fetch()
        features = [trim_feature(f) for f in raw]
        if ok:
            ttl = TTL_S if features else EMPTY_TTL_S
            _l1_put(key, features, ttl)
            # Off the request path: the answer is already in memory.
            _spawn(_db_put(key, features, ttl))
        else:
            _stats["failed"] += 1
        if not future.done():
            future.set_result(features)
        return features
    except BaseException:
        if not future.done():
            # Whoever is waiting must retry on its own, whatever killed us
            # (a cancellation included), so they get a marker, not our error.
            future.set_exception(_OwnerAborted())
            # Nobody may be waiting: avoid "exception was never retrieved".
            future.exception()
        raise
    finally:
        _inflight.pop(key, None)

"""Postgres (L2) store for AI stop-suggestion answers, one row per route
corridor. The in-memory layer (L1) lives in ``api.v1.suggest``.

It is an optimisation: a slow, missing or broken database is a miss."""

from __future__ import annotations

import asyncio
import json
import logging
import random
from typing import Any

_log = logging.getLogger(__name__)

_DB_TIMEOUT_S = 2.0


async def db_get(key: str) -> tuple[dict[str, Any], float] | None:
    """(payload, seconds left) or None."""
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
                        "FROM suggest_cache WHERE key = :k AND expires_at > NOW()"
                    ),
                    {"k": key},
                )).first()

        row = await asyncio.wait_for(_read(), timeout=_DB_TIMEOUT_S)
        if row is None:
            return None
        payload = row[0]
        if isinstance(payload, str):
            payload = json.loads(payload)
        if not isinstance(payload, dict):
            return None
        return payload, float(row[1])
    except Exception as exc:  # noqa: BLE001
        _log.warning("suggest_cache read failed: %r", exc)
        return None


async def db_put(key: str, payload: dict[str, Any], ttl_s: float) -> None:
    try:
        from sqlalchemy import text

        from app.db import get_session, is_available

        if not is_available():
            return

        async def _write():
            async with get_session() as session:
                await session.execute(
                    text(
                        "INSERT INTO suggest_cache (key, payload, expires_at) "
                        "VALUES (:k, CAST(:p AS JSONB), "
                        "NOW() + make_interval(secs => :ttl)) "
                        "ON CONFLICT (key) DO UPDATE SET "
                        "payload = EXCLUDED.payload, fetched_at = NOW(), "
                        "expires_at = EXCLUDED.expires_at"
                    ),
                    {"k": key, "p": json.dumps(payload), "ttl": float(ttl_s)},
                )
                if random.random() < 0.01:
                    await session.execute(
                        text("DELETE FROM suggest_cache WHERE expires_at < NOW()"),
                    )
                await session.commit()

        await asyncio.wait_for(_write(), timeout=_DB_TIMEOUT_S)
    except Exception as exc:  # noqa: BLE001
        _log.warning("suggest_cache write failed: %r", exc)

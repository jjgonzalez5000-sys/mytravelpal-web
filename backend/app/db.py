"""Database connection and session management.

Uses asyncpg via SQLAlchemy async for Fly Postgres. Falls back to
in-memory dicts when DATABASE_URL is not set (local dev, tests).
"""

from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager
from typing import AsyncGenerator

_log = logging.getLogger(__name__)

_DATABASE_URL = os.environ.get("DATABASE_URL")

_engine = None
_sessionmaker = None


async def init_db() -> None:
    """Create tables if they don't exist. Called once at app startup."""
    global _engine, _sessionmaker
    if not _DATABASE_URL:
        _log.info("DATABASE_URL not set — using in-memory stores")
        return
    url = _DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
    # Strip the query string — asyncpg reads TLS / timeout via
    # `connect_args`, not URL params. Fly's default URL comes with
    # `?sslmode=disable` (libpq-style) which asyncpg treats as a
    # DSN kwarg it doesn't understand and rejects with a cryptic
    # `ConnectionResetError()`. Handle TLS explicitly below.
    if "?" in url:
        url = url.split("?")[0]
    from sqlalchemy import text
    from sqlalchemy.ext.asyncio import (
        AsyncSession,
        async_sessionmaker,
        create_async_engine,
    )
    # Fly's postgres-flex accepts unencrypted intra-VPC traffic on
    # the `.flycast` hostname, BUT asyncpg's default is to attempt
    # TLS and fall back — that fallback races against the server
    # closing the connection and we get `ConnectionResetError()`.
    # `ssl=False` skips negotiation entirely for the internal
    # flycast path. Public hostnames would need `ssl='require'`.
    # Pool sizing: 20 base + 10 overflow gives ~30 concurrent conns
    # of headroom, well above the ~5-15 we'd hit with 1000 active
    # users on a `shared-cpu-2x` (2 uvicorn workers × 15 req in-
    # flight max per plan). Fly Postgres flex `shared` tier caps at
    # ~100 conns default, so we stay comfortably under. Bump both
    # together if we ever exceed the 30-conn envelope.
    _engine = create_async_engine(
        url, echo=False,
        pool_size=20,
        max_overflow=10,
        pool_pre_ping=True,
        pool_recycle=1800,  # recycle every 30 min to avoid stale idle
        connect_args={"timeout": 10, "ssl": False},
    )
    _sessionmaker = async_sessionmaker(_engine, class_=AsyncSession)
    # Retry with short backoff: on Fly, the app machine and the
    # Postgres flycast target often race at boot — the first
    # connect drops with `ConnectionResetError()` before Postgres
    # finishes advertising the service. Three quick tries clears
    # the race in practice.
    import asyncio
    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            async with _engine.begin() as conn:
                for stmt in _CREATE_STATEMENTS:
                    await conn.execute(text(stmt))
            _log.info("Database initialised at %s", url.split("@")[-1])
            return
        except Exception as exc:
            last_exc = exc
            _log.warning(
                "Database init attempt %d failed: %r", attempt + 1, exc,
            )
            await asyncio.sleep(1.5 * (attempt + 1))
    _log.error("Database init failed after 3 attempts: %r", last_exc)
    _engine = None
    _sessionmaker = None


def is_available() -> bool:
    return _engine is not None


@asynccontextmanager
async def get_session() -> AsyncGenerator:
    if _sessionmaker is None:
        raise RuntimeError("Database not initialised")
    async with _sessionmaker() as session:
        yield session


_CREATE_STATEMENTS = [
    """
    CREATE TABLE IF NOT EXISTS user_profiles (
        user_id TEXT PRIMARY KEY,
        profile JSONB NOT NULL DEFAULT '{}',
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS saved_trips (
        id SERIAL PRIMARY KEY,
        user_id TEXT NOT NULL,
        trip JSONB NOT NULL,
        saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_saved_trips_user
        ON saved_trips (user_id)
    """,
]

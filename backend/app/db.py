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


_reconnect_task = None
_RECONNECT_EVERY_S = 15.0


async def _connect_once(url: str) -> None:
    """Build the engine, create the tables, and publish it; raise on failure."""
    global _engine, _sessionmaker
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
    # Pool sizing: the Postgres VM has 256 MB and every backend costs
    # ~10 MB, so 2 machines x 30 connections starved it of memory and it
    # stopped answering (2026-10-10). 4 + 4 per machine is plenty for one
    # uvicorn worker; raise it together with the Postgres VM size.
    engine = create_async_engine(
        url, echo=False,
        pool_size=4,
        max_overflow=4,
        pool_pre_ping=True,
        pool_recycle=1800,  # recycle every 30 min to avoid stale idle
        connect_args={"timeout": 10, "ssl": False},
    )
    try:
        async with engine.begin() as conn:
            for stmt in _CREATE_STATEMENTS:
                await conn.execute(text(stmt))
    except BaseException:
        await engine.dispose()
        raise
    _engine = engine
    _sessionmaker = async_sessionmaker(engine, class_=AsyncSession)


async def _reconnect_loop(url: str) -> None:
    """Keep trying until the database answers.

    A machine that boots while Postgres is down used to stay on the
    in-memory stores for its whole life, silently dropping profiles,
    saved trips and the shared place cache until someone restarted it."""
    import asyncio
    while _engine is None:
        await asyncio.sleep(_RECONNECT_EVERY_S)
        try:
            await _connect_once(url)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Database reconnect failed: %r", exc)
            continue
        _log.info("Database reconnected at %s", url.split("@")[-1])


async def init_db() -> None:
    """Create tables if they don't exist. Called once at app startup."""
    global _reconnect_task
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
    # Retry with short backoff: on Fly, the app machine and the
    # Postgres flycast target often race at boot — the first
    # connect drops with `ConnectionResetError()` before Postgres
    # finishes advertising the service. Three quick tries clears
    # the race in practice.
    import asyncio
    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            await _connect_once(url)
            _log.info("Database initialised at %s", url.split("@")[-1])
            return
        except Exception as exc:
            last_exc = exc
            _log.warning(
                "Database init attempt %d failed: %r", attempt + 1, exc,
            )
            await asyncio.sleep(1.5 * (attempt + 1))
    _log.error(
        "Database init failed after 3 attempts: %r; will keep retrying "
        "in the background", last_exc,
    )
    _reconnect_task = asyncio.get_running_loop().create_task(
        _reconnect_loop(url),
    )


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
    # Free-form user feedback / suggestions. `user_id` nullable to
    # accept anonymous submissions (e.g. when someone hasn't signed
    # in yet). `reply_email` optional — set when the user opts in
    # to "I want a reply" so we can respond outside Play messaging.
    """
    CREATE TABLE IF NOT EXISTS feedback (
        id SERIAL PRIMARY KEY,
        user_id TEXT,
        app_version TEXT NOT NULL,
        locale TEXT NOT NULL,
        platform TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'suggestion',
        body_text TEXT NOT NULL,
        reply_email TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_feedback_created_at
        ON feedback (created_at DESC)
    """,
    # Identity table — one row per authenticated user. Stores the
    # OAuth email + display_name so the admin dashboard can show
    # "who is who". `email` will be encrypted/anonymised per
    # `project-data-privacy-tiers` Tier 2 before public launch;
    # for now stored plain because closed-beta needs it to correlate
    # dogfood feedback with real testers.
    """
    CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        display_name TEXT,
        provider TEXT NOT NULL DEFAULT 'google',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        last_login_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_users_last_login
        ON users (last_login_at DESC)
    """,
    # Usage-event log — one row per costly external call (LLM inspire,
    # HERE Places / Routing, Geoapify Places, TollGuru, etc.). Feeds
    # the admin dashboard's cost panels. `cost_eur` in EUR so the
    # panel sums are directly interpretable; caller passes a
    # per-provider estimate (~$1.5 per 1M input tokens for the LLM,
    # etc.). Nullable user_id = anonymous / not-yet-auth'd calls.
    """
    CREATE TABLE IF NOT EXISTS usage_events (
        id BIGSERIAL PRIMARY KEY,
        user_id TEXT,
        provider TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        tokens_in INTEGER,
        tokens_out INTEGER,
        cost_eur NUMERIC(10, 6) NOT NULL DEFAULT 0,
        meta JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_usage_events_created_at
        ON usage_events (created_at DESC)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_usage_events_provider
        ON usage_events (provider, created_at DESC)
    """,
    # Fixed monthly costs (Fly hosting, Postgres, domain, API
    # subscriptions, etc.). Populated by hand via psql when a new
    # cost line kicks in / stops. The admin dashboard sums the
    # ACTIVE ones for "coste fijo mensual" and integrates them
    # over time for "coste acumulado".
    """
    CREATE TABLE IF NOT EXISTS fixed_costs (
        id SERIAL PRIMARY KEY,
        label TEXT NOT NULL,
        monthly_eur NUMERIC(10, 2) NOT NULL,
        started_at DATE NOT NULL,
        ended_at DATE,
        notes TEXT
    )
    """,
    # Trip sharing — a driver posts their plan snapshot and gets a
    # short slug they can share via WhatsApp / link. Passengers open
    # the link to view the same plan (read-only). Expires after 30
    # days to keep the table small. `user_id` nullable so future
    # anonymous sharing is possible without a schema change.
    """
    CREATE TABLE IF NOT EXISTS trip_shares (
        slug TEXT PRIMARY KEY,
        user_id TEXT,
        plan_json JSONB NOT NULL,
        request_json JSONB NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 days'
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_trip_shares_expires_at
        ON trip_shares (expires_at)
    """,
    # Shared cache of Geoapify Places answers (see services/poi_cache.py).
    # Keyed by a hash of the snapped query; `expires_at` is per row because
    # a genuinely empty answer is kept for less time than a populated one.
    """
    CREATE TABLE IF NOT EXISTS poi_cache (
        key TEXT PRIMARY KEY,
        payload JSONB NOT NULL,
        fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        expires_at TIMESTAMPTZ NOT NULL
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_poi_cache_expires_at
        ON poi_cache (expires_at)
    """,
    # Companion sessions — driver creates a session and shares a
    # 6-char join code. Passengers poll every 5s to get the
    # driver's live position + ETA. Driver pushes every 10s.
    # Max latency ~15s — acceptable for road-trip context. Polling
    # is simpler than WebSockets and works fine with Fly HA
    # (the driver always PUTs to the same machine because the
    # mobile app sends the full session_id on every push).
    """
    CREATE TABLE IF NOT EXISTS companion_sessions (
        session_id TEXT PRIMARY KEY,
        join_code TEXT NOT NULL UNIQUE,
        driver_user_id TEXT NOT NULL,
        state_json JSONB DEFAULT '{}',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '12 hours',
        last_ping TIMESTAMPTZ DEFAULT NOW()
    )
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_companion_sessions_join_code
        ON companion_sessions (join_code)
    """,
    """
    CREATE INDEX IF NOT EXISTS idx_companion_sessions_expires_at
        ON companion_sessions (expires_at)
    """,
]

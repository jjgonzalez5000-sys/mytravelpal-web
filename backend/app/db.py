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
    # asyncpg needs postgresql+asyncpg:// not postgres://
    url = _DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
    from sqlalchemy.ext.asyncio import (
        AsyncSession,
        async_sessionmaker,
        create_async_engine,
    )
    _engine = create_async_engine(url, echo=False, pool_size=5)
    _sessionmaker = async_sessionmaker(_engine, class_=AsyncSession)
    async with _engine.begin() as conn:
        await conn.execute(_text(_CREATE_TABLES))
    _log.info("Database initialised")


def is_available() -> bool:
    return _engine is not None


@asynccontextmanager
async def get_session() -> AsyncGenerator:
    if _sessionmaker is None:
        raise RuntimeError("Database not initialised")
    async with _sessionmaker() as session:
        yield session


def _text(sql: str):
    from sqlalchemy import text
    return text(sql)


_CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id TEXT PRIMARY KEY,
    profile JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS saved_trips (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    trip JSONB NOT NULL,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_trips_user
    ON saved_trips (user_id);
"""

"""A machine that boots while Postgres is down must reconnect on its own."""

import asyncio

import pytest

from app import db


@pytest.fixture(autouse=True)
def _restore_db_state():
    saved = (db._DATABASE_URL, db._engine, db._sessionmaker,
             db._reconnect_task, db._RECONNECT_EVERY_S)
    yield
    task = db._reconnect_task
    if task is not None and not task.done():
        task.cancel()
    (db._DATABASE_URL, db._engine, db._sessionmaker,
     db._reconnect_task, db._RECONNECT_EVERY_S) = saved


async def test_boot_with_database_down_recovers_in_background(monkeypatch):
    attempts = {"n": 0}

    async def flaky_connect(url):
        attempts["n"] += 1
        # 3 boot attempts + 2 background attempts fail, then it answers.
        if attempts["n"] <= 5:
            raise ConnectionResetError("postgres is down")
        db._engine = object()

    monkeypatch.setattr(db, "_DATABASE_URL", "postgres://u:p@h:5432/d")
    monkeypatch.setattr(db, "_engine", None)
    monkeypatch.setattr(db, "_connect_once", flaky_connect)
    monkeypatch.setattr(db, "_RECONNECT_EVERY_S", 0.01)

    # Skip the 1.5 s boot backoff but keep the short reconnect interval.
    real_sleep = asyncio.sleep
    monkeypatch.setattr(asyncio, "sleep", lambda s: real_sleep(0 if s >= 1 else s))

    await db.init_db()
    assert not db.is_available()
    assert db._reconnect_task is not None

    await asyncio.wait_for(db._reconnect_task, timeout=2)
    assert db.is_available()
    assert attempts["n"] == 6


async def test_healthy_boot_starts_no_background_task(monkeypatch):
    async def ok_connect(url):
        db._engine = object()

    monkeypatch.setattr(db, "_DATABASE_URL", "postgres://u:p@h:5432/d")
    monkeypatch.setattr(db, "_engine", None)
    monkeypatch.setattr(db, "_reconnect_task", None)
    monkeypatch.setattr(db, "_connect_once", ok_connect)

    await db.init_db()
    assert db.is_available()
    assert db._reconnect_task is None

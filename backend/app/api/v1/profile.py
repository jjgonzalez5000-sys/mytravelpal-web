"""User profile + saved trips persistence.

Uses Postgres when DATABASE_URL is set, falls back to in-memory
dicts for local dev / tests.
"""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available

router = APIRouter(prefix="/profile", tags=["profile"])

# In-memory fallback when no DB is configured.
_PROFILES: dict[str, dict[str, Any]] = {}
_TRIPS: dict[str, list[dict[str, Any]]] = {}


class ProfilePayload(BaseModel):
    profile: dict[str, Any]


class ProfileResponse(BaseModel):
    profile: dict[str, Any] | None = None


@router.get("", response_model=ProfileResponse)
async def get_profile(
    user: AuthUser = Depends(current_user_required),
) -> ProfileResponse:
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            row = await session.execute(
                text("SELECT profile FROM user_profiles WHERE user_id = :uid"),
                {"uid": user.id},
            )
            result = row.mappings().first()
            return ProfileResponse(
                profile=result["profile"] if result else None,
            )
    return ProfileResponse(profile=_PROFILES.get(user.id))


@router.put("", response_model=ProfileResponse)
async def save_profile(
    payload: ProfilePayload,
    user: AuthUser = Depends(current_user_required),
) -> ProfileResponse:
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            await session.execute(
                text("""
                    INSERT INTO user_profiles (user_id, profile, updated_at)
                    VALUES (:uid, :profile, NOW())
                    ON CONFLICT (user_id)
                    DO UPDATE SET profile = :profile, updated_at = NOW()
                """),
                {"uid": user.id, "profile": json.dumps(payload.profile)},
            )
            await session.commit()
    else:
        _PROFILES[user.id] = payload.profile
    return ProfileResponse(profile=payload.profile)


@router.delete("")
async def delete_profile(
    user: AuthUser = Depends(current_user_required),
) -> dict[str, str]:
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            await session.execute(
                text("DELETE FROM user_profiles WHERE user_id = :uid"),
                {"uid": user.id},
            )
            await session.commit()
    else:
        _PROFILES.pop(user.id, None)
    return {"status": "deleted"}


# --- Saved trips ---

class TripsPayload(BaseModel):
    trips: list[dict[str, Any]]


class TripsResponse(BaseModel):
    trips: list[dict[str, Any]] = []


@router.get("/trips", response_model=TripsResponse)
async def get_trips(
    user: AuthUser = Depends(current_user_required),
) -> TripsResponse:
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            rows = await session.execute(
                text(
                    "SELECT trip FROM saved_trips "
                    "WHERE user_id = :uid ORDER BY saved_at DESC"
                ),
                {"uid": user.id},
            )
            return TripsResponse(
                trips=[r["trip"] for r in rows.mappings().all()],
            )
    return TripsResponse(trips=_TRIPS.get(user.id, []))


@router.put("/trips", response_model=TripsResponse)
async def save_trips(
    payload: TripsPayload,
    user: AuthUser = Depends(current_user_required),
) -> TripsResponse:
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            await session.execute(
                text("DELETE FROM saved_trips WHERE user_id = :uid"),
                {"uid": user.id},
            )
            for trip in payload.trips:
                await session.execute(
                    text(
                        "INSERT INTO saved_trips (user_id, trip, saved_at) "
                        "VALUES (:uid, :trip, NOW())"
                    ),
                    {"uid": user.id, "trip": json.dumps(trip)},
                )
            await session.commit()
    else:
        _TRIPS[user.id] = payload.trips
    return TripsResponse(trips=payload.trips)

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
    """Erase EVERY row we hold for this user (profile + saved trips
    + anything future tables add). GDPR right-to-erasure endpoint
    and the one wired to the "Borrar mi cuenta" button in the
    mobile Settings screen.

    Also exposed at `/v1/me/account` (DELETE) with a friendlier
    name — this legacy path stays for backwards compat with clients
    already shipped.
    """
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            await session.execute(
                text("DELETE FROM user_profiles WHERE user_id = :uid"),
                {"uid": user.id},
            )
            await session.execute(
                text("DELETE FROM saved_trips WHERE user_id = :uid"),
                {"uid": user.id},
            )
            await session.commit()
    else:
        _PROFILES.pop(user.id, None)
        _TRIPS.pop(user.id, None)
    return {"status": "deleted"}


class ExportResponse(BaseModel):
    """Full user-data dump for GDPR portability requests. Small
    dataset (single-user, cap ~50 trips) so JSON in-response is
    fine — no streaming needed. Client renders it as a downloadable
    file.
    """
    user_id: str
    email: str
    profile: dict[str, Any] | None = None
    trips: list[dict[str, Any]] = []


@router.get("/export", response_model=ExportResponse)
async def export_profile(
    user: AuthUser = Depends(current_user_required),
) -> ExportResponse:
    """Download-my-data endpoint. Returns everything the backend
    stores linked to this user. The mobile client offers a "Save
    JSON" button in Settings that hits this and shares/saves the
    payload.
    """
    profile: dict[str, Any] | None = None
    trips: list[dict[str, Any]] = []
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            prow = await session.execute(
                text(
                    "SELECT profile FROM user_profiles WHERE user_id = :uid"
                ),
                {"uid": user.id},
            )
            presult = prow.mappings().first()
            if presult:
                profile = presult["profile"]
            trows = await session.execute(
                text(
                    "SELECT trip FROM saved_trips "
                    "WHERE user_id = :uid ORDER BY saved_at DESC"
                ),
                {"uid": user.id},
            )
            trips = [r["trip"] for r in trows.mappings().all()]
    else:
        profile = _PROFILES.get(user.id)
        trips = list(_TRIPS.get(user.id, []))
    return ExportResponse(
        user_id=user.id,
        email=user.email,
        profile=profile,
        trips=trips,
    )


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

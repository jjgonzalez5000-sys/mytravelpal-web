"""User profile + saved trips persistence.

Uses Postgres when DATABASE_URL is set, falls back to in-memory
dicts for local dev / tests.
"""

from __future__ import annotations

import json
import logging
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available

_log = logging.getLogger(__name__)

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
    """Persist the profile blob.

    The client's PUT payload carries their traveller preferences +
    settings, but NOT the sibling data that lives in the same JSON
    column and is owned by other endpoints (`garage`, and any future
    endpoint that stores under a top-level key). Naively writing the
    payload used to wipe those keys on every mobile settings tap —
    tester report 2026-09-28: "the garage vehicles disappear".
    The fix: read the existing blob first, then apply the payload as
    a shallow overlay so keys the payload doesn't mention are
    preserved. Endpoints that OWN a specific key still overwrite it
    freely via their own dedicated PUT/POST/DELETE routes.
    """
    existing = await _read_profile(user.id)
    merged = {**existing, **payload.profile}
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
                {"uid": user.id, "profile": json.dumps(merged)},
            )
            await session.commit()
    else:
        _PROFILES[user.id] = merged
    return ProfileResponse(profile=merged)


@router.delete("", status_code=status.HTTP_200_OK)
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

    Delete order matters: `saved_trips` is the child table (no FK
    yet, but if we ever add ON DELETE RESTRICT this order lets the
    call keep succeeding). Any exception is logged with a stack
    trace so future regressions surface in `fly logs` instead of
    dying silently as a 500.
    """
    if db_available():
        try:
            async with get_session() as session:
                from sqlalchemy import text
                # Children first: saved trips → then the profile
                # row itself. Order is defensive against a future
                # FK constraint from saved_trips.user_id.
                await session.execute(
                    text("DELETE FROM saved_trips WHERE user_id = :uid"),
                    {"uid": user.id},
                )
                await session.execute(
                    text("DELETE FROM user_profiles WHERE user_id = :uid"),
                    {"uid": user.id},
                )
                await session.commit()
        except Exception:
            # Log the stack trace so `fly logs` shows the real
            # cause instead of the bare `Internal Server Error`
            # the mobile client sees. Re-raise so the client
            # doesn't get a false success.
            _log.exception(
                "delete_account failed for user_id=%s", user.id,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": "delete_failed"},
            )
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


# --- Garage (multi-vehicle) ---
#
# Stored inline in the same `profile` JSONB blob under a "garage" key.
# No schema migration required — the column already exists and
# arbitrary keys are fine. Auto-migration: on the first GET, if the
# blob has no `garage` array but does have legacy
# `vehicle_model_id` + `current_tank_level_percent`, we synthesise a
# single entry so returning users see their existing car pre-loaded.


class GarageVehicleIn(BaseModel):
    """Payload for creating / updating a garage entry.

    `id` is server-generated on POST — clients must not send one. On
    PUT the `id` comes from the URL path.
    """
    name: str = Field(min_length=1, max_length=64)
    model_id: str = Field(min_length=1, max_length=128)
    default_tank_percent: int = Field(default=100, ge=0, le=100)
    notes: str | None = Field(default=None, max_length=280)


class GarageVehicleUpdate(BaseModel):
    """Partial update. All fields optional; only ones sent are applied."""
    name: str | None = Field(default=None, min_length=1, max_length=64)
    default_tank_percent: int | None = Field(default=None, ge=0, le=100)
    notes: str | None = Field(default=None, max_length=280)


class GarageVehicleOut(BaseModel):
    id: str
    name: str
    model_id: str
    default_tank_percent: int
    notes: str | None = None


class GarageResponse(BaseModel):
    vehicles: list[GarageVehicleOut] = Field(default_factory=list)


def _load_profile_blob(user_id: str) -> dict[str, Any] | None:
    """Sync helper for the in-memory fallback path."""
    return _PROFILES.get(user_id)


async def _read_profile(user_id: str) -> dict[str, Any]:
    """Return the current profile blob (empty dict when missing)."""
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            row = await session.execute(
                text("SELECT profile FROM user_profiles WHERE user_id = :uid"),
                {"uid": user_id},
            )
            result = row.mappings().first()
            if result and isinstance(result["profile"], dict):
                return dict(result["profile"])
            return {}
    blob = _PROFILES.get(user_id)
    return dict(blob) if isinstance(blob, dict) else {}


async def _write_profile(user_id: str, blob: dict[str, Any]) -> None:
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
                {"uid": user_id, "profile": json.dumps(blob)},
            )
            await session.commit()
    else:
        _PROFILES[user_id] = blob


def _synthesise_legacy(blob: dict[str, Any]) -> list[dict[str, Any]] | None:
    """Build a synthetic single-entry garage from the pre-multi-vehicle
    fields on the profile blob, if any. Returns None if the legacy
    fields aren't present."""
    model_id = blob.get("vehicle_model_id")
    if not isinstance(model_id, str) or not model_id:
        return None
    tank = blob.get("current_tank_level_percent")
    tank_pct = int(tank) if isinstance(tank, (int, float)) else 100
    return [
        {
            "id": str(uuid.uuid4()),
            "name": "Mi coche",
            "model_id": model_id,
            "default_tank_percent": max(0, min(100, tank_pct)),
            "notes": None,
        }
    ]


def _garage_from_blob(blob: dict[str, Any]) -> list[dict[str, Any]]:
    raw = blob.get("garage")
    if isinstance(raw, list):
        # Filter defensively — a stray non-dict entry shouldn't crash the response.
        return [v for v in raw if isinstance(v, dict) and "id" in v]
    return []


def _validate_model_id(model_id: str) -> None:
    from app.data.vehicle_models import find
    if find(model_id) is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "unknown_vehicle_model", "model_id": model_id},
        )


def _to_out(v: dict[str, Any]) -> GarageVehicleOut:
    return GarageVehicleOut(
        id=str(v["id"]),
        name=str(v.get("name", "")),
        model_id=str(v.get("model_id", "")),
        default_tank_percent=int(v.get("default_tank_percent", 100)),
        notes=v.get("notes") if isinstance(v.get("notes"), str) else None,
    )


@router.get("/garage", response_model=GarageResponse)
async def get_garage(
    user: AuthUser = Depends(current_user_required),
) -> GarageResponse:
    blob = await _read_profile(user.id)
    existing = _garage_from_blob(blob)
    if not existing:
        # First read — try to auto-migrate the pre-multi-vehicle fields
        # so returning users see their car without redoing the picker.
        synth = _synthesise_legacy(blob)
        if synth is not None:
            blob["garage"] = synth
            await _write_profile(user.id, blob)
            return GarageResponse(vehicles=[_to_out(v) for v in synth])
        return GarageResponse(vehicles=[])
    return GarageResponse(vehicles=[_to_out(v) for v in existing])


@router.post("/garage", response_model=GarageVehicleOut)
async def add_garage_vehicle(
    payload: GarageVehicleIn,
    user: AuthUser = Depends(current_user_required),
) -> GarageVehicleOut:
    _validate_model_id(payload.model_id)
    blob = await _read_profile(user.id)
    existing = _garage_from_blob(blob)
    entry = {
        "id": str(uuid.uuid4()),
        "name": payload.name,
        "model_id": payload.model_id,
        "default_tank_percent": payload.default_tank_percent,
        "notes": payload.notes,
    }
    existing.append(entry)
    blob["garage"] = existing
    await _write_profile(user.id, blob)
    return _to_out(entry)


@router.put("/garage/{vehicle_id}", response_model=GarageVehicleOut)
async def update_garage_vehicle(
    vehicle_id: str,
    payload: GarageVehicleUpdate,
    user: AuthUser = Depends(current_user_required),
) -> GarageVehicleOut:
    blob = await _read_profile(user.id)
    existing = _garage_from_blob(blob)
    for v in existing:
        if str(v.get("id")) == vehicle_id:
            if payload.name is not None:
                v["name"] = payload.name
            if payload.default_tank_percent is not None:
                v["default_tank_percent"] = payload.default_tank_percent
            if payload.notes is not None:
                v["notes"] = payload.notes
            blob["garage"] = existing
            await _write_profile(user.id, blob)
            return _to_out(v)
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail={"error": "unknown_garage_vehicle", "id": vehicle_id},
    )


@router.delete("/garage/{vehicle_id}", status_code=status.HTTP_200_OK)
async def delete_garage_vehicle(
    vehicle_id: str,
    user: AuthUser = Depends(current_user_required),
) -> dict[str, str]:
    blob = await _read_profile(user.id)
    existing = _garage_from_blob(blob)
    trimmed = [v for v in existing if str(v.get("id")) != vehicle_id]
    if len(trimmed) == len(existing):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "unknown_garage_vehicle", "id": vehicle_id},
        )
    blob["garage"] = trimmed
    await _write_profile(user.id, blob)
    return {"status": "deleted", "id": vehicle_id}


async def resolve_garage_vehicle(
    user_id: str,
    vehicle_id: str,
) -> dict[str, Any] | None:
    """Public helper used by the /plan endpoint. Returns the raw
    garage entry dict for `user_id` + `vehicle_id`, or None when the
    id isn't in that user's garage. Kept as an async coroutine so the
    plan flow can look it up without duplicating the JSONB read."""
    blob = await _read_profile(user_id)
    for v in _garage_from_blob(blob):
        if str(v.get("id")) == vehicle_id:
            return v
    return None

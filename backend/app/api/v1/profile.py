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
    subscription_tier: str | None = None  # "free" | "essential" | "premium"
    subscription_expires_at: str | None = None


def _extract_subscription(
    profile: dict[str, Any] | None,
) -> tuple[str, str | None]:
    """Return (tier, expires_at) from a profile blob.

    Always returns a string tier ("free" when missing or expired).
    """
    from datetime import UTC, datetime
    if not isinstance(profile, dict):
        return "free", None
    sub = profile.get("subscription")
    if not isinstance(sub, dict):
        return "free", None
    tier = sub.get("tier")
    expires_raw = sub.get("expires_at")
    if expires_raw:
        try:
            expires_dt = datetime.fromisoformat(expires_raw)
            if expires_dt.tzinfo is None:
                expires_dt = expires_dt.replace(tzinfo=UTC)
            if datetime.now(UTC) > expires_dt:
                return "free", None
        except ValueError:
            pass
    if tier in {"essential", "premium"}:
        return tier, expires_raw
    return "free", None


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
            profile_blob = result["profile"] if result else None
            tier, expires_at = _extract_subscription(profile_blob)
            return ProfileResponse(
                profile=profile_blob,
                subscription_tier=tier,
                subscription_expires_at=expires_at,
            )
    profile_blob = _PROFILES.get(user.id)
    tier, expires_at = _extract_subscription(profile_blob)
    return ProfileResponse(
        profile=profile_blob,
        subscription_tier=tier,
        subscription_expires_at=expires_at,
    )


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


class NickCheckResponse(BaseModel):
    available: bool


@router.get("/check-nick", response_model=NickCheckResponse)
async def check_nick(
    nick: str,
    user: AuthUser = Depends(current_user_required),
) -> NickCheckResponse:
    """Check whether a Hall of Fame nick is taken by another user.

    Case-sensitive exact match against the ``_hall_nick`` field stored
    in the profile JSONB. The current user's own nick always counts as
    available so they can re-save without a false conflict.
    """
    normalized = nick.strip()
    if not normalized:
        return NickCheckResponse(available=False)
    if db_available():
        async with get_session() as session:
            from sqlalchemy import text
            row = await session.execute(
                text(
                    "SELECT 1 FROM user_profiles "
                    "WHERE profile->>'_hall_nick' = :nick "
                    "AND user_id != :uid LIMIT 1"
                ),
                {"nick": normalized, "uid": user.id},
            )
            taken = row.mappings().first() is not None
            return NickCheckResponse(available=not taken)
    # In-memory fallback (dev / tests)
    for uid, blob in _PROFILES.items():
        if uid == user.id:
            continue
        if isinstance(blob, dict) and blob.get("_hall_nick") == normalized:
            return NickCheckResponse(available=False)
    return NickCheckResponse(available=True)


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
    if model_id == "__custom__":
        return  # Custom vehicles pass; actual specs live in notes.
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


# --- User learning profile ---
#
# Stored under user_profiles.profile["learning"]. Explicit fields
# (questionnaire answers) and implicit fields (incrementing counters)
# live here. The ai-context endpoint distils these into a short string
# that LLM calls (Companion, Inspire) inject as user context.


class UserLearningIn(BaseModel):
    # Explicit preferences (set by questionnaire)
    preferred_countries: list[str] = Field(default_factory=list)
    typical_trip_duration_days: int | None = None
    prefers_scenic_routes: bool | None = None
    prefers_budget_accommodation: bool | None = None  # True=budget, False=comfort
    dietary_restrictions: list[str] = Field(default_factory=list)  # vegetarian, vegan, halal, gluten_free
    prefers_local_food: bool | None = None
    typical_departure_hour: int | None = None  # 0-23
    eco_conscious: bool | None = None  # prefers EVs, avoids motorways
    trip_purpose: str | None = None  # leisure, family, business, adventure
    interests: list[str] = Field(default_factory=list)  # culture, nature, food, shopping
    # Implicit (incremented by app, not user-set)
    total_plans_made: int = 0
    total_multi_day_plans: int = 0
    countries_visited: list[str] = Field(default_factory=list)
    features_used: dict[str, int] = Field(default_factory=dict)  # {feature: count}


class UserLearningResponse(BaseModel):
    learning: dict[str, Any]


@router.get("/learning", response_model=UserLearningResponse)
async def get_learning(
    user: AuthUser = Depends(current_user_required),
) -> UserLearningResponse:
    blob = await _read_profile(user.id)
    raw = blob.get("learning") or {}
    # Populate defaults for any missing explicit fields.
    defaults = UserLearningIn().model_dump()
    merged = {**defaults, **raw}
    return UserLearningResponse(learning=merged)


@router.put("/learning", response_model=UserLearningResponse)
async def save_learning(
    payload: UserLearningIn,
    user: AuthUser = Depends(current_user_required),
) -> UserLearningResponse:
    """Shallow-merge the learning payload into the existing learning sub-key.
    Implicit counters sent as 0 by a client that didn't fetch first are
    NOT written when the stored value is already higher — prevents
    accidental resets when the questionnaire re-submits."""
    blob = await _read_profile(user.id)
    existing = blob.get("learning") or {}
    update = payload.model_dump(exclude_unset=True)
    # Protect implicit counter fields from being decremented.
    _COUNTER_FIELDS = {"total_plans_made", "total_multi_day_plans"}
    for field in _COUNTER_FIELDS:
        if field in update:
            current_val = existing.get(field, 0)
            if isinstance(current_val, int) and update[field] < current_val:
                update[field] = current_val
    new_learning = {**existing, **update}
    blob["learning"] = new_learning
    await _write_profile(user.id, blob)
    return UserLearningResponse(learning=new_learning)


class AiContextResponse(BaseModel):
    context: str


@router.get("/ai-context", response_model=AiContextResponse)
async def get_ai_context(
    user: AuthUser = Depends(current_user_required),
) -> AiContextResponse:
    """Return a short, LLM-ready summary of what the AI knows about the user.

    Called by Companion and Inspire to inject user context into prompts.
    Kept under 300 characters and factual.
    """
    blob = await _read_profile(user.id)
    learning: dict[str, Any] = blob.get("learning") or {}

    parts: list[str] = []

    # Scenic / budget / eco
    prefs: list[str] = []
    if learning.get("prefers_scenic_routes"):
        prefs.append("scenic routes")
    if learning.get("eco_conscious"):
        prefs.append("eco-conscious")
    if learning.get("prefers_local_food"):
        prefs.append("local food")
    if prefs:
        parts.append("Prefers " + ", ".join(prefs))

    # Dietary
    diet = learning.get("dietary_restrictions") or []
    if diet:
        parts.append(", ".join(diet))

    # Accommodation
    budget_pref = learning.get("prefers_budget_accommodation")
    if budget_pref is True:
        parts.append("budget hotels")
    elif budget_pref is False:
        parts.append("comfort hotels")

    # Departure
    dep_hour = learning.get("typical_departure_hour")
    if isinstance(dep_hour, int):
        parts.append(f"departs ~{dep_hour:02d}h")

    # Trip purpose / interests
    purpose = learning.get("trip_purpose")
    if purpose:
        parts.append(f"{purpose} travel")
    interests = learning.get("interests") or []
    if interests:
        parts.append("interests: " + ", ".join(interests))

    # Duration
    duration = learning.get("typical_trip_duration_days")
    if isinstance(duration, int) and duration > 0:
        parts.append(f"typical {duration}-day trips")

    # History
    total_plans = learning.get("total_plans_made", 0)
    if isinstance(total_plans, int) and total_plans > 0:
        parts.append(f"{total_plans} trips planned")
    countries = learning.get("preferred_countries") or learning.get("countries_visited") or []
    if countries:
        parts.append("often in " + "/".join(countries[:3]))

    context = ". ".join(parts)
    # Hard cap at 300 chars.
    if len(context) > 300:
        context = context[:297] + "..."
    if not context:
        context = "New user, no preferences recorded yet."
    return AiContextResponse(context=context)


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

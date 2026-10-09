"""Companion group sessions — driver shares live position with passengers.

Architecture: polling (not WebSockets).
- Driver pushes state every ~10s via PUT.
- Passengers poll via GET every ~5s.
- Max one-way latency: ~15s, acceptable for road-trip context.
- Works cleanly with Fly.io HA because every PUT carries the full
  session_id so the load balancer can pin it to one machine if needed.

Endpoints:

POST /v1/companion/session           (JWT required)
    Driver creates a new session. Returns session_id + 6-char join_code.

PUT  /v1/companion/session/{session_id}  (JWT required, must be driver)
    Driver pushes current state (position, ETA, radar, etc.).

GET  /v1/companion/session/{join_code}   (X-API-Key only, public for passengers)
    Passenger polls. Returns current state_json + join_code metadata.
    Returns 404 when session expired (>12h) or deleted.

DELETE /v1/companion/session/{session_id}  (JWT required, must be driver)
    Driver ends the session explicitly.
"""

from __future__ import annotations

import json
import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available

_log = logging.getLogger(__name__)

router = APIRouter(prefix="/companion", tags=["companion-session"])

# In-memory fallback for local dev without DB.
_SESSIONS: dict[str, dict[str, Any]] = {}  # keyed by session_id
_CODE_TO_ID: dict[str, str] = {}           # join_code -> session_id

_JOIN_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _gen_join_code(length: int = 6) -> str:
    # `secrets`, not `random`: the code is the only thing protecting a live
    # trip's state, and `random` (Mersenne Twister) is predictable from its
    # outputs. The alphabet leaves out I, O, 0 and 1 so codes read aloud
    # or typed from a screen are not misread.
    return "".join(secrets.choice(_JOIN_CODE_CHARS) for _ in range(length))


# --- Pydantic models ---

class SessionCreateResponse(BaseModel):
    session_id: str
    join_code: str
    expires_at: str


class StopInfo(BaseModel):
    """One planned stop along the route (from the trip plan)."""
    name: str | None = None
    km: float = 0.0  # distance from trip origin along the route
    type: Literal["meal", "rest", "fuel", "hotel", "destination"] = "rest"
    eta_ms: int | None = None  # absolute epoch ms ETA


class DriverStatePayload(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    speed_kmh: float = Field(ge=0, le=400)
    next_stop_name: str | None = None
    next_stop_eta_ms: int | None = None
    next_stop_lat: float | None = None
    next_stop_lon: float | None = None
    radar_ahead_km: float | None = None
    radar_max_speed: int | None = None
    destination_eta_ms: int | None = None
    remaining_km: float | None = None
    # Route-progress fields — used by proactive suggestions + passenger view.
    current_km: float | None = None  # driver's position along the route in km
    stops: list[StopInfo] = Field(default_factory=list)  # full planned stop list


class SessionStateResponse(BaseModel):
    join_code: str
    session_id: str
    driver_user_id: str
    state: dict[str, Any]
    last_ping: str
    expires_at: str


# --- Helpers ---

def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _expires_iso(hours: int = 12) -> str:
    return (datetime.now(UTC) + timedelta(hours=hours)).isoformat()


# --- Endpoints ---

@router.post("/session", response_model=SessionCreateResponse)
async def create_session(
    user: AuthUser = Depends(current_user_required),
) -> SessionCreateResponse:
    """Driver creates a new companion session and gets a join code."""
    session_id = str(uuid.uuid4())
    expires_at = _expires_iso(12)

    if db_available():
        from sqlalchemy import text
        # Pick a unique join code (retry up to 5 times).
        join_code: str | None = None
        async with get_session() as session:
            for _ in range(5):
                candidate = _gen_join_code()
                row = await session.execute(
                    text(
                        "SELECT join_code FROM companion_sessions "
                        "WHERE join_code = :code AND expires_at > NOW()"
                    ),
                    {"code": candidate},
                )
                if row.first() is None:
                    join_code = candidate
                    break
            if join_code is None:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail={"error": "join_code_generation_failed"},
                )
            await session.execute(
                text("""
                    INSERT INTO companion_sessions
                        (session_id, join_code, driver_user_id,
                         state_json, expires_at)
                    VALUES (:sid, :code, :uid, '{}', CAST(:exp AS TIMESTAMPTZ))
                """),
                {
                    "sid": session_id,
                    "code": join_code,
                    "uid": user.id,
                    "exp": expires_at,
                },
            )
            await session.commit()
    else:
        join_code = _gen_join_code()
        _SESSIONS[session_id] = {
            "session_id": session_id,
            "join_code": join_code,
            "driver_user_id": user.id,
            "state": {},
            "created_at": _now_iso(),
            "expires_at": expires_at,
            "last_ping": _now_iso(),
        }
        _CODE_TO_ID[join_code] = session_id

    return SessionCreateResponse(
        session_id=session_id,
        join_code=join_code,
        expires_at=expires_at,
    )


@router.put("/session/{session_id}", status_code=status.HTTP_200_OK)
async def push_driver_state(
    session_id: str,
    payload: DriverStatePayload,
    user: AuthUser = Depends(current_user_required),
) -> dict[str, bool]:
    """Driver pushes current position + ETA. Called every ~10s."""
    state_dict = payload.model_dump(exclude_none=True)

    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            row = await session.execute(
                text("""
                    SELECT driver_user_id
                    FROM companion_sessions
                    WHERE session_id = :sid AND expires_at > NOW()
                """),
                {"sid": session_id},
            )
            result = row.mappings().first()
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        if result["driver_user_id"] != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "not_the_driver"},
            )
        async with get_session() as session:
            await session.execute(
                text("""
                    UPDATE companion_sessions
                    SET state_json = :state, last_ping = NOW()
                    WHERE session_id = :sid
                """),
                {"state": json.dumps(state_dict), "sid": session_id},
            )
            await session.commit()
    else:
        entry = _SESSIONS.get(session_id)
        if entry is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        if entry["driver_user_id"] != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "not_the_driver"},
            )
        exp = entry.get("expires_at")
        if exp and datetime.fromisoformat(exp) < datetime.now(UTC):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        entry["state"] = state_dict
        entry["last_ping"] = _now_iso()

    return {"ok": True}


@router.get("/session/{join_code}", response_model=SessionStateResponse)
async def get_session_state(join_code: str) -> SessionStateResponse:
    """Passenger polls current driver state. Public endpoint (X-API-Key gate
    is handled by the global middleware, not per-route auth).

    join_code is case-insensitive; normalised to uppercase.
    """
    join_code = join_code.upper()

    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            row = await session.execute(
                text("""
                    SELECT session_id, driver_user_id,
                           state_json, last_ping, expires_at
                    FROM companion_sessions
                    WHERE join_code = :code AND expires_at > NOW()
                """),
                {"code": join_code},
            )
            result = row.mappings().first()
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        last_ping = result["last_ping"]
        expires_at = result["expires_at"]
        return SessionStateResponse(
            join_code=join_code,
            session_id=result["session_id"],
            driver_user_id=result["driver_user_id"],
            state=result["state_json"] or {},
            last_ping=last_ping.isoformat()
            if hasattr(last_ping, "isoformat") else str(last_ping),
            expires_at=expires_at.isoformat()
            if hasattr(expires_at, "isoformat") else str(expires_at),
        )

    sid = _CODE_TO_ID.get(join_code)
    entry = _SESSIONS.get(sid) if sid else None
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "session_not_found"},
        )
    exp = entry.get("expires_at")
    if exp and datetime.fromisoformat(exp) < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "session_not_found"},
        )
    return SessionStateResponse(
        join_code=join_code,
        session_id=entry["session_id"],
        driver_user_id=entry["driver_user_id"],
        state=entry.get("state", {}),
        last_ping=entry["last_ping"],
        expires_at=entry["expires_at"],
    )


@router.delete("/session/{session_id}", status_code=status.HTTP_200_OK)
async def end_session(
    session_id: str,
    user: AuthUser = Depends(current_user_required),
) -> dict[str, str]:
    """Driver explicitly ends the session."""
    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            row = await session.execute(
                text(
                    "SELECT driver_user_id FROM companion_sessions "
                    "WHERE session_id = :sid"
                ),
                {"sid": session_id},
            )
            result = row.mappings().first()
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        if result["driver_user_id"] != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "not_the_driver"},
            )
        async with get_session() as session:
            await session.execute(
                text(
                    "DELETE FROM companion_sessions WHERE session_id = :sid"
                ),
                {"sid": session_id},
            )
            await session.commit()
    else:
        entry = _SESSIONS.get(session_id)
        if entry is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        if entry["driver_user_id"] != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "not_the_driver"},
            )
        code = entry.get("join_code")
        _SESSIONS.pop(session_id, None)
        if code:
            _CODE_TO_ID.pop(code, None)

    return {"status": "ended", "session_id": session_id}


# --- Proactive suggestion endpoint ---

_SUGGEST_THRESHOLD_KM = 15.0  # only fire within this distance of the next stop


class SuggestPayload(BaseModel):
    """Called by the driver app every ~5 km of progress."""
    current_km: float
    stops: list[StopInfo] = Field(default_factory=list)
    lang: str = Field(default="en", max_length=5)


class SuggestResponse(BaseModel):
    suggestion: str | None = None
    action: str | None = None


@router.post(
    "/session/{session_id}/suggest",
    response_model=SuggestResponse,
    status_code=status.HTTP_200_OK,
)
async def proactive_suggest(
    session_id: str,
    payload: SuggestPayload,
    user: AuthUser = Depends(current_user_required),
) -> SuggestResponse:
    """Proactive tip based on current position and upcoming stops.

    Called every ~5 km of progress by the driver app.
    Returns a short natural-language suggestion when within
    `_SUGGEST_THRESHOLD_KM` of the next stop; null otherwise.
    """
    # Verify the session belongs to this driver (best-effort; tolerate
    # missing session for local dev without DB).
    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            row = await session.execute(
                text(
                    "SELECT driver_user_id FROM companion_sessions "
                    "WHERE session_id = :sid AND expires_at > NOW()"
                ),
                {"sid": session_id},
            )
            result = row.mappings().first()
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "session_not_found"},
            )
        if result["driver_user_id"] != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": "not_the_driver"},
            )

    # Find the next upcoming stop.
    upcoming = sorted(
        [s for s in payload.stops if s.km > payload.current_km],
        key=lambda s: s.km,
    )
    if not upcoming:
        return SuggestResponse()

    next_stop = upcoming[0]
    km_ahead = next_stop.km - payload.current_km

    # Only fire when within threshold.
    if km_ahead > _SUGGEST_THRESHOLD_KM:
        return SuggestResponse()

    stop_name = next_stop.name or next_stop.type
    stop_type = next_stop.type

    # Build a short prompt for the LLM.
    prompt = (
        f"You are a road-trip driving companion. "
        f"Answer in {payload.lang}, max 1 sentence, TTS-friendly (no markdown). "
        f"The driver is {km_ahead:.0f} km from their next planned {stop_type} stop"
        f" called '{stop_name}'. "
        f"Generate a warm, brief proactive tip to remind them. "
        f"Example: 'In 8 km you'll reach Ven y Ven — your planned lunch stop. Hungry?'"
    )

    from app.providers.llm import default_llm_provider
    try:
        llm = default_llm_provider()
        suggestion_raw = await llm.generate_narrative(prompt)
        suggestion = suggestion_raw.strip()
        if len(suggestion) > 200:
            suggestion = suggestion[:197] + "..."
    except Exception:
        # LLM unavailable — fall back to a canned message.
        suggestion = (
            f"In {km_ahead:.0f} km: {stop_name} ({stop_type})."
        )

    # Derive an action hint for the mobile client.
    action_map = {
        "meal": "show_stop_detail",
        "rest": "show_stop_detail",
        "fuel": "suggest_fuel_stop",
        "hotel": "open_hotel_list",
        "destination": "show_stop_detail",
    }
    action = action_map.get(stop_type, "show_stop_detail")

    # Fire-and-forget usage log.
    try:
        from app.services.usage_tracking import log_event
        await log_event(
            user_id=user.id,
            provider="anthropic",
            endpoint="companion_suggest",
            tokens_in=0,
            tokens_out=0,
            cost_eur=0.0,
            meta={"stop_type": stop_type, "km_ahead": round(km_ahead, 1)},
        )
    except Exception:
        pass

    return SuggestResponse(suggestion=suggestion, action=action)

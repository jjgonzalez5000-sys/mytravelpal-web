"""Per-user daily quota for LLM-backed endpoints.

Guards Trip Inspiration + narrative from cost blow-up (abuse,
misconfigured client loop, credential leak). A single per-user
counter with a UTC-day window: reset at midnight UTC.

Free tier gets a generous-for-normal-use but low-for-abuse budget;
Premium raises it 5-10x. See `project_ai_cost_defense` memory for
the layered plan this is layer 1 of.

Storage is in-memory — good enough for the single Fly machine in
closed beta. Migrate to Redis when we add a second machine or when
we ship layer 5 (anomaly detection) which also needs shared state.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date
from typing import Literal

from fastapi import Depends, HTTPException, status

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser

AiKind = Literal["inspire", "narrative"]

# (kind, is_premium) -> daily cap. Free-tier caps are deliberately
# low to force a paywall; Premium caps are still bounded to keep a
# runaway subscribed user from blowing the Anthropic monthly cap.
_LIMITS: dict[tuple[AiKind, bool], int] = {
    ("inspire", False): 3,
    ("inspire", True): 20,
    ("narrative", False): 5,
    ("narrative", True): 50,
}

# {(user_id, kind, ymd) -> count}
_hits: dict[tuple[str, AiKind, str], int] = defaultdict(int)


def _today_key() -> str:
    return date.today().isoformat()


def check_and_bump(user: AuthUser, kind: AiKind, is_premium: bool) -> None:
    """Increment the day's counter for `user` and raise 429 if the
    quota is exhausted. Idempotent within the same request only via
    caller convention; call once per accepted request AFTER passing
    all other validation.
    """
    key = (user.id, kind, _today_key())
    cap = _LIMITS[(kind, is_premium)]
    used = _hits[key]
    if used >= cap:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": "ai_quota_exceeded",
                "kind": kind,
                "limit": cap,
                "reset": "next UTC midnight",
                "message": (
                    f"Daily AI limit reached ({cap} {kind}s). "
                    "Resets at midnight UTC."
                    + ("" if is_premium else " Premium doubles this cap.")
                ),
            },
        )
    _hits[key] = used + 1


async def require_inspire_quota(
    user: AuthUser = Depends(current_user_required),
) -> AuthUser:
    """FastAPI dep for `/v1/trips/inspire`. Enforces auth + quota.
    Premium detection: for the beta we treat every authed user as
    premium=True since the paywall isn't wired yet; flip when the
    subscription check lands (see `project_launch_plan`).
    """
    check_and_bump(user, "inspire", is_premium=True)
    return user


async def require_narrative_quota(
    user: AuthUser = Depends(current_user_required),
) -> AuthUser:
    """Same shape for `/v1/trips/narrative`."""
    check_and_bump(user, "narrative", is_premium=True)
    return user

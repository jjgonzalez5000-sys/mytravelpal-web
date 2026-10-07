"""Trip sharing — share a trip plan snapshot via a short URL.

POST /v1/trips/share  (JWT required)
    Body: {plan: {...}, request: {...}}
    Returns: {slug: "ABC123", url: "https://www.mytravelpal.io/join/ABC123"}

GET /v1/trips/share/{slug}  (public, no auth)
    Returns: {plan: {...}, request: {...}, created_at: "..."}

Slug: 6 random chars from [A-Z2-9] (excludes O, 0, I, 1 to avoid confusion).
Plan + request stored as compressed JSON in JSONB columns.
Entries expire after 30 days; GET returns 404 for expired slugs.
"""

from __future__ import annotations

import json
import logging
import random
import string
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available

_log = logging.getLogger(__name__)

router = APIRouter(prefix="/trips", tags=["trip-sharing"])

# In-memory fallback for local dev without DB.
_SHARES: dict[str, dict[str, Any]] = {}

# Characters used for slugs: uppercase letters + digits, minus O/0/I/1.
_SLUG_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _gen_slug(length: int = 6) -> str:
    return "".join(random.choices(_SLUG_CHARS, k=length))


class ShareCreatePayload(BaseModel):
    plan: dict[str, Any]
    request: dict[str, Any]


class ShareCreateResponse(BaseModel):
    slug: str
    url: str


class ShareGetResponse(BaseModel):
    slug: str
    plan: dict[str, Any]
    request: dict[str, Any]
    created_at: str


@router.post("/share", response_model=ShareCreateResponse)
async def create_share(
    payload: ShareCreatePayload,
    http_request: Request,
    user: AuthUser = Depends(current_user_required),
) -> ShareCreateResponse:
    """Store a trip plan snapshot and return a shareable slug."""
    # Build a unique slug. Collisions are astronomically unlikely
    # (32^6 = 1 billion combos) but we retry a couple times to be safe.
    slug: str | None = None
    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            for _ in range(5):
                candidate = _gen_slug()
                row = await session.execute(
                    text(
                        "SELECT slug FROM trip_shares "
                        "WHERE slug = :slug AND expires_at > NOW()"
                    ),
                    {"slug": candidate},
                )
                if row.first() is None:
                    slug = candidate
                    break
            if slug is None:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail={"error": "slug_generation_failed"},
                )
            await session.execute(
                text("""
                    INSERT INTO trip_shares
                        (slug, user_id, plan_json, request_json)
                    VALUES (:slug, :uid, :plan, :req)
                """),
                {
                    "slug": slug,
                    "uid": user.id,
                    "plan": json.dumps(payload.plan),
                    "req": json.dumps(payload.request),
                },
            )
            await session.commit()
    else:
        for _ in range(5):
            candidate = _gen_slug()
            existing = _SHARES.get(candidate)
            if existing is None:
                slug = candidate
                break
            # Treat expired in-memory entries as available.
            exp = existing.get("expires_at")
            if exp and datetime.fromisoformat(exp) < datetime.now(UTC):
                slug = candidate
                break
        if slug is None:
            slug = _gen_slug()
        now = datetime.now(UTC)
        _SHARES[slug] = {
            "user_id": user.id,
            "plan": payload.plan,
            "request": payload.request,
            "created_at": now.isoformat(),
            "expires_at": now.replace(
                year=now.year + (1 if now.month == 12 else 0),
                month=(now.month % 12) + 1 if now.month == 12 else now.month + 1
                if now.month < 12 else 1,
            ).isoformat(),
        }

    # Build the public URL. We keep the base configurable via an env
    # var so local dev can use localhost and prod uses the real domain.
    import os
    base = os.environ.get(
        "MYTRAVELPAL_WEB_BASE_URL", "https://www.mytravelpal.io"
    ).rstrip("/")
    url = f"{base}/join/{slug}"
    return ShareCreateResponse(slug=slug, url=url)


@router.get("/share/{slug}", response_model=ShareGetResponse)
async def get_share(slug: str) -> ShareGetResponse:
    """Retrieve a shared trip plan by slug. Public, no auth required."""
    slug = slug.upper()
    if db_available():
        from sqlalchemy import text
        async with get_session() as session:
            row = await session.execute(
                text("""
                    SELECT plan_json, request_json, created_at
                    FROM trip_shares
                    WHERE slug = :slug AND expires_at > NOW()
                """),
                {"slug": slug},
            )
            result = row.mappings().first()
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "share_not_found"},
            )
        return ShareGetResponse(
            slug=slug,
            plan=result["plan_json"],
            request=result["request_json"],
            created_at=result["created_at"].isoformat()
            if hasattr(result["created_at"], "isoformat")
            else str(result["created_at"]),
        )

    entry = _SHARES.get(slug)
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "share_not_found"},
        )
    exp = entry.get("expires_at")
    if exp and datetime.fromisoformat(exp) < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "share_not_found"},
        )
    return ShareGetResponse(
        slug=slug,
        plan=entry["plan"],
        request=entry["request"],
        created_at=entry["created_at"],
    )

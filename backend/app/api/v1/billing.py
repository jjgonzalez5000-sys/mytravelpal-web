"""Play Billing purchase validation.

Closed-beta STUB: accepts any token and maps the product_id to a tier.
No real Google Play Developer API call is made — the receipt is trusted
as-is.  This is intentional for the closed-beta phase where all testers
are invited and receipt forgery is not a concern.

TODO (before production / open beta):
  Wire real Google Play Developer API (androidpublisher.googleapis.com):
    1. Create a service account in Google Cloud Console with the
       "Android Publisher" OAuth scope.
    2. Store the JSON key as a Fly secret: GOOGLE_PLAY_SA_KEY_JSON
    3. Replace _verify_stub() below with a call to:
         https://androidpublisher.googleapis.com/androidpublisher/v3/
           applications/{packageName}/purchases/subscriptions/
           {subscriptionId}/tokens/{token}
    4. Check purchaseState == 0 (active) and expiryTimeMillis.
    5. Raise HTTP 402 for expired / cancelled tokens.
"""

from __future__ import annotations

import json
import logging
import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available
from app.services.usage_tracking import log_event

_log = logging.getLogger(__name__)

router = APIRouter(prefix="/billing", tags=["billing"])

# ------------------------------------------------------------------
# SKU catalogue
# ------------------------------------------------------------------

_KNOWN_PACKAGE = "com.mytravelpal.travel"

# Map SKU -> (tier, duration_days)
_SKU_MAP: dict[str, tuple[Literal["essential", "premium"], int]] = {
    "mytravelpal_essential_yearly":  ("essential", 365),
    "mytravelpal_premium_monthly":   ("premium",    31),
    "mytravelpal_premium_yearly":    ("premium",   365),
}


# ------------------------------------------------------------------
# Request / response models
# ------------------------------------------------------------------

class ValidateRequest(BaseModel):
    purchase_token: str
    product_id: str
    package_name: str


class ValidateResponse(BaseModel):
    valid: bool
    tier: Literal["free", "essential", "premium"]
    expires_at: str | None
    subscription_id: str


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

async def _read_profile_blob(user_id: str) -> dict:
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
    return {}


async def _write_profile_blob(user_id: str, blob: dict) -> None:
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


def _verify_stub(
    purchase_token: str,
    product_id: str,
    package_name: str,
) -> tuple[str, int]:
    """Closed-beta stub: trust the client, return (tier, duration_days).

    TODO: replace with a real Google Play Developer API call before
    production.  See module docstring for the exact endpoint + service
    account setup.
    """
    if package_name != _KNOWN_PACKAGE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "unknown_package", "package_name": package_name},
        )
    if product_id not in _SKU_MAP:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "unknown_product_id", "product_id": product_id},
        )
    tier, days = _SKU_MAP[product_id]
    return tier, days


# ------------------------------------------------------------------
# Public helper: read subscription from stored profile
# ------------------------------------------------------------------

async def get_subscription_tier(user_id: str) -> Literal["free", "essential", "premium"]:
    """Return the stored subscription tier for a user, or 'free'.

    Used by premium gating dependencies so they don't have to duplicate
    the DB read logic.
    """
    blob = await _read_profile_blob(user_id)
    sub = blob.get("subscription")
    if not isinstance(sub, dict):
        return "free"
    tier = sub.get("tier")
    expires_raw = sub.get("expires_at")
    # Treat expired subscriptions as free.
    if expires_raw:
        try:
            expires_dt = datetime.fromisoformat(expires_raw)
            if expires_dt.tzinfo is None:
                expires_dt = expires_dt.replace(tzinfo=UTC)
            if datetime.now(UTC) > expires_dt:
                return "free"
        except ValueError:
            pass
    if tier in {"essential", "premium"}:
        return tier  # type: ignore[return-value]
    return "free"


# ------------------------------------------------------------------
# Endpoint
# ------------------------------------------------------------------

@router.post("/validate", response_model=ValidateResponse)
async def validate_purchase(
    payload: ValidateRequest,
    user: AuthUser = Depends(current_user_required),
) -> ValidateResponse:
    """Validate a Google Play purchase token and store the subscription.

    Closed-beta behaviour: the token is accepted as-is and the tier is
    derived purely from the product_id.  The TODO in the module docstring
    explains how to wire the real Play Developer API before launch.
    """
    tier, duration_days = _verify_stub(
        payload.purchase_token,
        payload.product_id,
        payload.package_name,
    )

    now = datetime.now(UTC)
    expires_at = (now + timedelta(days=duration_days)).isoformat()
    subscription_id = str(uuid.uuid4())

    # Persist into profile JSONB under the "subscription" key.
    blob = await _read_profile_blob(user.id)
    blob["subscription"] = {
        "tier": tier,
        "sku": payload.product_id,
        "expires_at": expires_at,
        "purchase_token": payload.purchase_token,
        "subscription_id": subscription_id,
        "validated_at": now.isoformat(),
    }
    await _write_profile_blob(user.id, blob)

    # Fire-and-forget telemetry.
    await log_event(
        user_id=user.id,
        provider="play_billing",
        endpoint="billing_validate",
        cost_eur=0.0,
        meta={
            "product_id": payload.product_id,
            "tier": tier,
            "expires_at": expires_at,
        },
    )

    _log.info(
        "billing_validate user=%s sku=%s tier=%s expires=%s",
        user.id,
        payload.product_id,
        tier,
        expires_at,
    )

    return ValidateResponse(
        valid=True,
        tier=tier,
        expires_at=expires_at,
        subscription_id=subscription_id,
    )

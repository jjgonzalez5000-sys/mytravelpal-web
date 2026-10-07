"""Premium gating.

Original MVP placeholder: the client sends `X-MyTravelPal-Premium: true`
header and the backend trusted it blindly.  This still works for the
closed beta where all testers are invited.

New subscription-aware dependencies (`require_essential_subscription`,
`require_premium_subscription`) check the stored profile["subscription"]
JSONB, written by POST /v1/billing/validate.  They fall back to the
header check so the closed-beta flow keeps working while the mobile
client is being updated to call the validate endpoint.

Production: the Google Play Developer API stub in billing.py will be
replaced with a real receipt check before open beta.
"""

from __future__ import annotations

from fastapi import Depends, Header, HTTPException, status

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser

_HEADER = "x-mytravelpal-premium"


def is_premium(x_mytravelpal_premium: str | None = Header(default=None)) -> bool:
    """Return True when the client claims Premium status via header.

    Legacy helper — header-only, no DB read.  Used by routes that have
    not yet been migrated to subscription-aware dependencies.
    """
    return (x_mytravelpal_premium or "").strip().lower() in {"true", "1", "yes"}


def require_premium(premium: bool = None) -> bool:  # type: ignore[assignment]
    """Route dependency: raises 402 unless the request declares Premium.

    Usage:
        @router.post("/premium-thing")
        async def endpoint(_: bool = Depends(require_premium)) -> ...:
    """
    # FastAPI resolves this via the sub-dependency below; the parameter
    # signature above is only for clarity in docs.
    raise RuntimeError("unreachable — replaced by _require_premium_impl")


async def _require_premium_impl(
    x_mytravelpal_premium: str | None = Header(default=None),
) -> bool:
    if is_premium(x_mytravelpal_premium):
        return True
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail={
            "error": "premium_required",
            "message": "This feature is available on the Premium plan.",
        },
    )


# Re-bind the name so `Depends(require_premium)` at the route level
# resolves to the async implementation. We keep the docstring above
# for readability.
require_premium = _require_premium_impl  # type: ignore[assignment]


# ------------------------------------------------------------------
# Subscription-aware dependencies (billing.py validates and stores)
# ------------------------------------------------------------------

async def require_essential_subscription(
    user: AuthUser = Depends(current_user_required),
    x_mytravelpal_premium: str | None = Header(default=None),
) -> AuthUser:
    """Raises 402 unless the user has Essential or Premium tier.

    Checks profile["subscription"]["tier"] from the DB first.
    Falls back to the `X-MyTravelPal-Premium` header so the closed-beta
    header flow keeps working while mobile is updated.

    Usage:
        @router.get("/essential-thing")
        async def endpoint(user: AuthUser = Depends(require_essential_subscription)):
    """
    from app.api.v1.billing import get_subscription_tier
    tier = await get_subscription_tier(user.id)
    if tier in {"essential", "premium"}:
        return user
    # Legacy header fallback for closed beta
    if is_premium(x_mytravelpal_premium):
        return user
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail={
            "error": "essential_required",
            "message": "This feature is available on the Essential or Premium plan.",
        },
    )


async def require_premium_subscription(
    user: AuthUser = Depends(current_user_required),
    x_mytravelpal_premium: str | None = Header(default=None),
) -> AuthUser:
    """Raises 402 unless the user has Premium tier.

    Checks profile["subscription"]["tier"] from the DB first.
    Falls back to the `X-MyTravelPal-Premium` header so the closed-beta
    header flow keeps working while mobile is updated.

    Usage:
        @router.get("/premium-thing")
        async def endpoint(user: AuthUser = Depends(require_premium_subscription)):
    """
    from app.api.v1.billing import get_subscription_tier
    tier = await get_subscription_tier(user.id)
    if tier == "premium":
        return user
    # Legacy header fallback for closed beta
    if is_premium(x_mytravelpal_premium):
        return user
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail={
            "error": "premium_required",
            "message": "This feature is available on the Premium plan.",
        },
    )

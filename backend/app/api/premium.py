"""Premium gating.

MVP placeholder: the client sends `X-MyTravelPal-Premium: true` on
requests where the user is a paying subscriber. The dependency checks
the header and raises 402 (Payment Required) when a Premium-gated
feature is requested by a non-Premium client.

Production will replace this with a proper receipt-verification flow
(RevenueCat webhook, Apple StoreKit / Google Play Billing) that hydrates
the request with a verified subscription record. The dependency shape
stays the same so route handlers don't need to change.
"""

from __future__ import annotations

from fastapi import Header, HTTPException, status

_HEADER = "x-mytravelpal-premium"


def is_premium(x_mytravelpal_premium: str | None = Header(default=None)) -> bool:
    """Return True when the client claims Premium status.

    Not a security check yet — trust the client; production replaces this
    with real receipt verification.
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

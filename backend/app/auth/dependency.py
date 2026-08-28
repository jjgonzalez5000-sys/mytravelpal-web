"""FastAPI dependencies for auth-gated endpoints."""

from __future__ import annotations

import jwt
from fastapi import Header, HTTPException, status

from .jwt import AuthUser, decode_token


async def current_user_optional(
    authorization: str | None = Header(default=None),
) -> AuthUser | None:
    """Return the authenticated user if a valid Bearer token is present.

    Returns None when the header is missing or the token is invalid —
    routes that want to *require* a user use `current_user_required`.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        return None
    try:
        return decode_token(token)
    except jwt.PyJWTError:
        return None


async def current_user_required(
    authorization: str | None = Header(default=None),
) -> AuthUser:
    """Same as `current_user_optional` but raises 401 when no user
    found.

    IMPORTANT: no extra params without explicit markers here. An
    earlier `user: AuthUser | None = None` fallback made FastAPI
    treat `user` as an implicit body param — every dependent
    endpoint then required the body to be wrapped as
    `{payload: {...}, user: {...}}` and returned 422 for the
    normal `{profile: {...}}` shape. Removing the param restores
    the plain "body = the endpoint's single Pydantic model" rule.
    """
    resolved = await current_user_optional(authorization=authorization)
    if resolved is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "auth_required"},
            headers={"WWW-Authenticate": "Bearer"},
        )
    return resolved

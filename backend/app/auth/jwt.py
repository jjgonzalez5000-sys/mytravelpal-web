"""App-issued JWT helpers.

We issue a short-lived JWT after a successful login (via Google, Facebook,
or the demo provider). The mobile client stores it and sends it in the
`Authorization: Bearer …` header on subsequent requests.

MVP: HS256 with a symmetric secret from `MYTRAVELPAL_JWT_SECRET`. When
we scale to multiple backends and rotate keys, swap to RS256 or hand
over to Cognito / Auth0 — the `AuthUser` dependency stays.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt

_DEFAULT_SECRET = "dev-secret-not-for-production-set-MYTRAVELPAL_JWT_SECRET-in-prod"
_ALGORITHM = "HS256"
_ISSUER = "mytravelpal"
_TOKEN_TTL = timedelta(days=30)


def _secret() -> str:
    return os.environ.get("MYTRAVELPAL_JWT_SECRET", _DEFAULT_SECRET)


@dataclass(frozen=True, slots=True)
class AuthUser:
    id: str
    email: str
    display_name: str
    provider: str


def issue_token(user: AuthUser, *, now: datetime | None = None) -> str:
    """Return a compact JWT for `user`, valid for `_TOKEN_TTL`."""
    now = now or datetime.now(tz=timezone.utc)
    payload = {
        "iss": _ISSUER,
        "sub": user.id,
        "email": user.email,
        "name": user.display_name,
        "provider": user.provider,
        "iat": int(now.timestamp()),
        "exp": int((now + _TOKEN_TTL).timestamp()),
    }
    return jwt.encode(payload, _secret(), algorithm=_ALGORITHM)


def decode_token(token: str) -> AuthUser:
    """Return the [`AuthUser`] encoded in `token`, or raise `jwt.PyJWTError`."""
    payload = jwt.decode(
        token, _secret(), algorithms=[_ALGORITHM], issuer=_ISSUER,
    )
    return AuthUser(
        id=str(payload["sub"]),
        email=str(payload.get("email", "")),
        display_name=str(payload.get("name", "")),
        provider=str(payload.get("provider", "unknown")),
    )

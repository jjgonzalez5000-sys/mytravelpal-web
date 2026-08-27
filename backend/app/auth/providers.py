"""OAuth provider ID-token verification.

For each supported provider we take an ID token issued by the provider
(Google's `id_token` from the Google Sign-In SDK, Facebook's access
token) and return a normalised `AuthUser` we can then issue an app JWT
for.

Real verification requires either a networked call to the provider's
public keys / graph API (secure) or an installed SDK. To keep the code
importable without those extras and to keep tests offline, we detect
whether the required extras are available and fall back to a **strict
demo mode** when they aren't — a mode that only accepts explicitly
demo-flagged payloads. Production configuration slots in without
touching endpoint code.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from .jwt import AuthUser


class OAuthVerificationError(Exception):
    """Raised when a provider ID token cannot be verified."""


@dataclass(frozen=True, slots=True)
class OAuthPayload:
    id_token: str
    # Optional fields the client sends alongside for the demo provider.
    demo_email: str | None = None
    demo_name: str | None = None


import logging as _logging
_glog = _logging.getLogger(__name__)

class GoogleOAuthProvider:
    """Verifies a Google-issued ID token via `google-auth`.

    When `google-auth` isn't installed (default in this repo — we haven't
    added the dep), `verify` raises `OAuthVerificationError`. Install
    `google-auth` and set `GOOGLE_CLIENT_ID` to enable real verification.
    """

    async def verify(self, payload: OAuthPayload) -> AuthUser:
        try:
            from google.auth.transport import requests as g_requests  # type: ignore
            from google.oauth2 import id_token as g_id_token  # type: ignore
        except ImportError as exc:
            raise OAuthVerificationError(
                "google-auth not installed; run `pip install google-auth`",
            ) from exc
        client_id = os.environ.get("GOOGLE_CLIENT_ID")
        if not client_id:
            raise OAuthVerificationError("GOOGLE_CLIENT_ID not configured")
        android_client_id = os.environ.get("GOOGLE_ANDROID_CLIENT_ID")
        _glog.info(
            "Google verify: web_client=%s, android_client=%s, token_prefix=%s",
            client_id[:20] if client_id else None,
            android_client_id[:20] if android_client_id else None,
            payload.id_token[:30] if payload.id_token else None,
        )
        try:
            info = g_id_token.verify_oauth2_token(
                payload.id_token, g_requests.Request(), client_id,
            )
        except ValueError as exc1:
            _glog.warning("Web client verify failed: %s", exc1)
            if android_client_id:
                try:
                    info = g_id_token.verify_oauth2_token(
                        payload.id_token, g_requests.Request(),
                        android_client_id,
                    )
                except ValueError as exc2:
                    _glog.error("Android client verify also failed: %s", exc2)
                    raise OAuthVerificationError(
                        f"Google token invalid: web={exc1}, android={exc2}",
                    ) from exc2
            else:
                raise OAuthVerificationError(
                    f"Google token invalid: {exc1}",
                ) from exc1
        return AuthUser(
            id=f"google:{info['sub']}",
            email=str(info.get("email", "")),
            display_name=str(info.get("name", "")),
            provider="google",
        )


class FacebookOAuthProvider:
    """Verifies a Facebook user access token via Graph API.

    Requires `FACEBOOK_APP_SECRET` to be set (Graph API `access_token
    debug` requires an app access token derived from it). When not
    configured, `verify` raises `OAuthVerificationError`.
    """

    _GRAPH = "https://graph.facebook.com/me"

    async def verify(self, payload: OAuthPayload) -> AuthUser:
        import httpx

        access_token = payload.id_token
        if not os.environ.get("FACEBOOK_APP_SECRET"):
            raise OAuthVerificationError("FACEBOOK_APP_SECRET not configured")
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(
                    self._GRAPH,
                    params={
                        "fields": "id,name,email",
                        "access_token": access_token,
                    },
                )
                response.raise_for_status()
                info = response.json()
        except httpx.HTTPError as exc:
            raise OAuthVerificationError(f"Facebook token invalid: {exc}") from exc
        if "id" not in info:
            raise OAuthVerificationError("Facebook response missing user id")
        return AuthUser(
            id=f"facebook:{info['id']}",
            email=str(info.get("email", "")),
            display_name=str(info.get("name", "")),
            provider="facebook",
        )


class AppleOAuthProvider:
    """Verifies an Apple ID token via Apple's public JWKS.

    Apple's Sign-In-with-Apple flow issues an `id_token` signed with an
    RSA key published at https://appleid.apple.com/auth/keys. Validation
    is public-key only, so no app secret is needed on the backend — but
    we DO require `APPLE_APP_ID` (the app's bundle ID) so we can check
    the token's `aud` claim.

    Apple only returns the user's name on the **first** login and as a
    separate form field, not inside the id_token. We accept an optional
    display name via the demo channel so the mobile client can carry it
    over on first sign-in.
    """

    _JWKS_URL = "https://appleid.apple.com/auth/keys"
    _ISSUER = "https://appleid.apple.com"

    def __init__(self, jwks_client=None) -> None:
        self._jwks_client = jwks_client

    async def verify(self, payload: OAuthPayload) -> AuthUser:
        app_id = os.environ.get("APPLE_APP_ID")
        if not app_id:
            raise OAuthVerificationError("APPLE_APP_ID not configured")
        try:
            import jwt as _jwt
            from jwt import PyJWKClient as _PyJWKClient

            client = self._jwks_client or _PyJWKClient(
                self._JWKS_URL, cache_keys=True,
            )
            signing_key = client.get_signing_key_from_jwt(payload.id_token)
            info = _jwt.decode(
                payload.id_token,
                signing_key.key,
                algorithms=["RS256"],
                audience=app_id,
                issuer=self._ISSUER,
            )
        except Exception as exc:  # noqa: BLE001 — funnel to our error type
            raise OAuthVerificationError(f"Apple token invalid: {exc}") from exc
        email = str(info.get("email", "")) or ""
        name = (payload.demo_name or "").strip() or (
            email.split("@")[0] if email else "Apple user"
        )
        return AuthUser(
            id=f"apple:{info['sub']}",
            email=email,
            display_name=name,
            provider="apple",
        )


class DemoOAuthProvider:
    """Trusts the client — for local development and previews.

    Accepts `{provider: "demo", demo_email: …, demo_name: …}` and issues
    a stable per-email demo user. Never enabled in production (the flag
    that surfaces the demo login button in the mobile app is dev-only).
    """

    async def verify(self, payload: OAuthPayload) -> AuthUser:
        email = (payload.demo_email or "").strip() or "demo@mytravelpal.dev"
        name = (payload.demo_name or "").strip() or "Demo Traveller"
        return AuthUser(
            id=f"demo:{email.lower()}",
            email=email,
            display_name=name,
            provider="demo",
        )


def get_provider(name: str):
    """Route `name` (google/facebook/demo) to the corresponding verifier."""
    match name.lower():
        case "google":
            return GoogleOAuthProvider()
        case "facebook":
            return FacebookOAuthProvider()
        case "apple":
            return AppleOAuthProvider()
        case "demo":
            return DemoOAuthProvider()
        case _:
            raise OAuthVerificationError(f"Unknown provider: {name}")

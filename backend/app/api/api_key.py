"""API-key gate.

Deployment scenario: the production URL is on the public internet so
the mobile APK can reach it, but we don't want strangers who guess or
scrape the URL to use our compute/quota. A static `X-API-Key` header
solves the "no random discovery" threat model:

- If `MYTRAVELPAL_API_KEY` is set in the environment, every incoming
  request to `/v1/*` must present it. Otherwise 401.
- Local dev leaves the env var unset → the middleware is a no-op, all
  requests pass. Existing tests keep working without headers.
- `/health` is always open — infra probes need it.

Not a security replacement for JWT auth; it's a rate-limit-by-obscurity
layer. Real security lives on top: JWT for user identity, Premium
header for tier gating, both already implemented.
"""

from __future__ import annotations

import os
from typing import Awaitable, Callable

from fastapi import Request, Response
from starlette.responses import JSONResponse

_HEADER = "x-mytravelpal-api-key"
_EXEMPT_PATHS: frozenset[str] = frozenset({"/health", "/", "/docs", "/openapi.json"})


async def api_key_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    expected = os.environ.get("MYTRAVELPAL_API_KEY")
    if not expected:
        # Dev / test mode — gate disabled.
        return await call_next(request)

    path = request.url.path
    if path in _EXEMPT_PATHS or path.startswith("/docs") or path.startswith("/redoc"):
        return await call_next(request)
    # Preflight for CORS
    if request.method == "OPTIONS":
        return await call_next(request)

    got = request.headers.get(_HEADER, "")
    if got != expected:
        return JSONResponse(
            status_code=401,
            content={
                "error": "api_key_required",
                "message": (
                    "Missing or invalid X-MyTravelPal-Api-Key header."
                ),
            },
        )
    return await call_next(request)

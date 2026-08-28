"""In-memory rate limiter middleware.

Cheap protection against runaway clients: a reverse-engineered APK key
in the wild, a broken loop in a beta build hammering `/plan`, or a
naive scraper. In-memory (not Redis) because we run a single Fly
machine — the counter dies with the process, which is fine: a
suspend/resume cycle also implies the client has to re-connect and
the burst allowance resets. When we scale to > 1 machine, migrate to
`fly-http-request-headers` upstream limits or a shared Redis.

Two-tier policy:
- Per-token (authenticated user via Bearer JWT): generous, drivers do
  many `/plan` calls when tweaking preferences.
- Per-IP fallback (no bearer): stricter, since that's mostly scrapers
  or misconfigured clients.

Sliding-window counter using monotonic bucket keys — keeps memory
bounded (~O(active clients) entries + a periodic sweep).
"""

from __future__ import annotations

import time
from collections import defaultdict, deque
from typing import Awaitable, Callable

from fastapi import Request, Response
from starlette.responses import JSONResponse


# Sliding windows: (max_requests, window_seconds).
# Per authenticated user: 120 req / min covers heavy interactive use
# (each replan is ~1 call, POI toggles < 10/min in practice).
_AUTH_LIMIT = 120
_AUTH_WINDOW_S = 60.0
# Per-IP anonymous (no bearer): tighter. Real users hit /geocode
# during autocomplete typing which fires ~1/char, so 60 req/min
# leaves headroom for a fast typer.
_IP_LIMIT = 60
_IP_WINDOW_S = 60.0

# Exempt paths — health checks and docs shouldn't burn the budget.
_EXEMPT_PREFIXES: tuple[str, ...] = ("/health", "/docs", "/redoc", "/openapi.json")

# In-memory window store keyed by client identity.
_hits: dict[str, deque[float]] = defaultdict(deque)
# Periodic sweep of dead entries so long-idle keys don't leak.
_last_sweep: float = 0.0
_SWEEP_INTERVAL_S = 300.0  # every 5 min


def _client_key(request: Request) -> tuple[str, int, float]:
    """Return (key, limit, window) for the request."""
    auth = request.headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        token = auth[7:].strip()
        # First 24 chars of the JWT are stable per user session; using
        # the full token would leak more into the log if we ever emit
        # the key.
        return (f"auth:{token[:24]}", _AUTH_LIMIT, _AUTH_WINDOW_S)
    # Fly forwards the real client IP in `fly-client-ip`; fall back
    # to Starlette's `.client.host` for local dev.
    ip = (
        request.headers.get("fly-client-ip")
        or request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        or (request.client.host if request.client else "unknown")
    )
    return (f"ip:{ip}", _IP_LIMIT, _IP_WINDOW_S)


def _maybe_sweep(now: float) -> None:
    """Drop empty deques so idle keys don't accumulate forever."""
    global _last_sweep
    if now - _last_sweep < _SWEEP_INTERVAL_S:
        return
    _last_sweep = now
    dead = [k for k, dq in _hits.items() if not dq]
    for k in dead:
        del _hits[k]


async def rate_limit_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    path = request.url.path
    if any(path.startswith(p) for p in _EXEMPT_PREFIXES):
        return await call_next(request)
    if request.method == "OPTIONS":
        return await call_next(request)

    now = time.monotonic()
    key, limit, window = _client_key(request)
    dq = _hits[key]
    # Drop entries outside the current window.
    cutoff = now - window
    while dq and dq[0] < cutoff:
        dq.popleft()
    if len(dq) >= limit:
        retry_after = max(1, int(window - (now - dq[0])))
        return JSONResponse(
            status_code=429,
            content={
                "error": "rate_limited",
                "message": (
                    f"Too many requests — {limit} per "
                    f"{int(window)}s. Retry in {retry_after}s."
                ),
            },
            headers={"Retry-After": str(retry_after)},
        )
    dq.append(now)
    _maybe_sweep(now)
    return await call_next(request)

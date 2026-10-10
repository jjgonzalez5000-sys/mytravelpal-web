import logging
import os

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.logging import LoggingIntegration

from app.api.api_key import api_key_middleware
from app.api.rate_limit import rate_limit_middleware
from app.api.v1 import router as v1_router

_log = logging.getLogger(__name__)

_dsn = os.environ.get("SENTRY_DSN")
if _dsn:
    sentry_sdk.init(
        dsn=_dsn,
        integrations=[
            FastApiIntegration(),
            # Capture WARNING+ logs as breadcrumbs, ERROR+ as events.
            LoggingIntegration(level=logging.WARNING, event_level=logging.ERROR),
        ],
        traces_sample_rate=0.1,   # 10 % of requests get a perf trace
        profiles_sample_rate=0.0,
        environment=os.environ.get("FLY_APP_NAME", "local"),
        release=os.environ.get("FLY_IMAGE_REF", "dev"),
    )
    # WARNING level so the init message actually surfaces in the
    # default Fly logging config (INFO on `app.*` loggers is filtered
    # out — uvicorn only opts its own loggers into INFO). It's not
    # semantically a warning but it's a rare boot-time event and
    # visibility matters for verifying the DSN wire-up.
    _log.warning("Sentry initialised (DSN set, %s)", _dsn.split("@")[-1])
else:
    _log.warning("Sentry disabled — SENTRY_DSN not set")


from contextlib import asynccontextmanager

from app.db import init_db


@asynccontextmanager
async def _lifespan(a):
    await init_db()
    yield


app = FastAPI(
    title="MyTravelPal API",
    version="0.2.0",
    description="Trip planning API with optimal-departure-window computation.",
    lifespan=_lifespan,
)

# CORS allow-list. Native mobile clients don't send an Origin header,
# so they're unaffected by CORS entirely — the list is only relevant
# for the web build and for third-party sites that might try to
# invoke the API from a browser. Wildcard was fine during MVP dev but
# leaks the API surface to any origin once we go public. Override at
# runtime with `MYTRAVELPAL_CORS_ORIGINS` (comma-separated) for
# local dev / preview envs — e.g. `http://localhost:3000,
# http://localhost:8080`.
_default_origins = ["https://mytravelpal.app", "https://www.mytravelpal.app"]
_env_origins = os.environ.get("MYTRAVELPAL_CORS_ORIGINS", "").strip()
_cors_origins = (
    [o.strip() for o in _env_origins.split(",") if o.strip()]
    if _env_origins
    else _default_origins
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Content-Type", "Authorization",
        "X-MyTravelPal-Api-Key", "X-MyTravelPal-Premium",
    ],
)

# API-key gate. No-op unless `MYTRAVELPAL_API_KEY` is set (production).
app.middleware("http")(api_key_middleware)
# Rate limiter runs BEFORE api_key thanks to Starlette's stack order
# (last-added is outermost). That's the correct order — kill flood
# traffic before we spend a hash-compare on the API key. In-memory
# per-process; see `rate_limit.py` for the multi-machine caveat.
app.middleware("http")(rate_limit_middleware)

app.include_router(v1_router, prefix="/v1")


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    from app import db

    # Liveness stays "ok" even without a database (the stores fall back
    # to memory), but `db` makes a silent fallback visible.
    state = "memory" if not db._DATABASE_URL else (
        "up" if db.is_available() else "down"
    )
    return {"status": "ok", "db": state}





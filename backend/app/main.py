import logging
import os

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.logging import LoggingIntegration

from app.api.api_key import api_key_middleware
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
    _log.info("Sentry initialised (DSN set)")
else:
    _log.info("Sentry disabled — SENTRY_DSN not set")


app = FastAPI(
    title="MyTravelPal API",
    version="0.1.0",
    description="Trip planning API with optimal-departure-window computation.",
)

# MVP: permissive CORS so the Flutter web build served on any localhost
# port can call the API. Tighten to an allow-list before going public.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API-key gate. No-op unless `MYTRAVELPAL_API_KEY` is set (production).
app.middleware("http")(api_key_middleware)

app.include_router(v1_router, prefix="/v1")


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    return {"status": "ok"}

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.api_key import api_key_middleware
from app.api.v1 import router as v1_router

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

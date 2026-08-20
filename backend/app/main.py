from fastapi import FastAPI

from app.api.v1 import router as v1_router

app = FastAPI(
    title="MyTravelPal API",
    version="0.1.0",
    description="Trip planning API with optimal-departure-window computation.",
)

app.include_router(v1_router, prefix="/v1")


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    return {"status": "ok"}

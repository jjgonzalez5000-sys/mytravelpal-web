"""Diagnostics endpoints for operators.

These are meant to help you verify the pipeline behind features that
depend on flaky third-party services (currently: fires via NASA FIRMS).
Nothing here is a substitute for real observability — they're one-shot
probes you run when a user reports "I picked a route near a big fire
and got no alert".

Path: `/v1/diagnostics/…`. Public — no auth required, since they're
already read-only, low-cardinality, and small-payload. Add auth later
if we start exposing sensitive-looking counts.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.providers.firms import FirmsFireProvider

router = APIRouter(prefix="/diagnostics", tags=["diagnostics"])


class FiresProbeResult(BaseModel):
    bbox: list[float]
    count: int
    sample: list["FireSample"]
    fetched_at: datetime


class FireSample(BaseModel):
    lat: float
    lon: float
    severity: str
    description: str


@router.get("/fires", response_model=FiresProbeResult)
async def fires_probe(
    west: float = Query(..., ge=-180.0, le=180.0),
    south: float = Query(..., ge=-90.0, le=90.0),
    east: float = Query(..., ge=-180.0, le=180.0),
    north: float = Query(..., ge=-90.0, le=90.0),
    sample: int = Query(5, ge=0, le=25),
) -> FiresProbeResult:
    """Return the count and a sample of active-fire hotspots in `bbox`.

    Example: probe the Iberian summer corridor with
    `?west=-9&south=36&east=3&north=44`.

    Use this when a user reports missing fire alerts — if this returns
    `count: 0` you know the trip really had nothing near it; if it
    returns > 0 but the trip plan didn't include them, the issue is
    the bbox intersection in `firms.events_along`.
    """
    now = datetime.now(timezone.utc)
    provider = FirmsFireProvider()
    events = await provider.fetch_bbox((west, south, east, north), now=now)
    return FiresProbeResult(
        bbox=[west, south, east, north],
        count=len(events),
        fetched_at=now,
        sample=[
            FireSample(
                lat=e.coordinate.lat,
                lon=e.coordinate.lon,
                severity=e.severity.value,
                description=e.description,
            )
            for e in events[:sample]
        ],
    )


@router.get("/places-usage")
async def places_usage() -> dict:
    """Geoapify Places credits spent today and how well the shared cache is
    working (hit rate, misses, calls that failed and were not cached). Read
    it before the free allowance (3,000 a day) runs out."""
    from app.services import poi_cache

    return poi_cache.stats()


FiresProbeResult.model_rebuild()

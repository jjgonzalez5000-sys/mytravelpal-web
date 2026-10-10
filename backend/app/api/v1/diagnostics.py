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


@router.get("/here-fuel-codes")
async def here_fuel_codes(
    lat: float = Query(48.137, ge=-90.0, le=90.0),
    lon: float = Query(11.575, ge=-180.0, le=180.0),
    catalogue: str = Query("", max_length=20),
) -> dict:
    """Ask HERE's Fuel Prices API what it knows around a point and list the
    fuel codes it returns (with a sample price each), plus one raw station.

    Use it to find out whether HERE carries a product we do not map yet
    (AdBlue, HVO, ...), or why a country shows no prices: the HTTP status
    and the start of the error body come back when the call fails."""
    import httpx

    from app.providers import fuel_here as fh

    if not fh._api_key() and not fh._app_id():  # noqa: SLF001
        return {"configured": False}
    if catalogue not in ("", "fuelTypes", "fuel-types", "fuelProducts"):
        return {"error": "unknown catalogue"}
    params = {"in": f"circle:{lat:.5f},{lon:.5f};r=15000"}
    url = fh._FUEL_PRICES_ENDPOINT  # noqa: SLF001
    if catalogue:
        # Try HERE's own list of fuel codes (the exact path is not
        # documented where we could read it, hence the few candidates).
        params = {}
        url = url.rsplit("/", 1)[0] + "/" + catalogue
    headers: dict[str, str] = {}
    async with httpx.AsyncClient(timeout=15.0) as client:
        token = await fh._fetch_bearer_token(client) if fh._app_id() else None  # noqa: SLF001
        if token:
            headers["Authorization"] = f"Bearer {token}"
        else:
            params["apiKey"] = fh._api_key() or ""  # noqa: SLF001
        r = await client.get(url, params=params, headers=headers)
    if catalogue:
        return {"url": url, "status": r.status_code, "body": r.text[:3000]}
    if r.status_code != 200:
        return {"configured": True, "status": r.status_code, "body": r.text[:300]}
    stations = (r.json().get("stations") or [])
    counts: dict[str, int] = {}
    sample: dict[str, dict] = {}
    for s in stations:
        for p in s.get("prices") or []:
            code = str(p.get("fuelType"))
            counts[code] = counts.get(code, 0) + 1
            sample.setdefault(code, p)
    return {
        "configured": True,
        "status": 200,
        "stations": len(stations),
        "fuel_codes": dict(sorted(counts.items(), key=lambda kv: -kv[1])),
        "sample_price_per_code": sample,
        "example_station": stations[0] if stations else None,
    }


FiresProbeResult.model_rebuild()

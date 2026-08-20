from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.domain import Country
from app.providers import get_providers
from app.providers.factory import Providers

router = APIRouter(prefix="/geocode", tags=["geocode"])


class CoordinateOut(BaseModel):
    lat: float
    lon: float


class GeocodeResultOut(BaseModel):
    display_name: str
    coordinate: CoordinateOut
    country: Country


class GeocodeResponse(BaseModel):
    results: list[GeocodeResultOut]


def _providers() -> Providers:
    return get_providers()


@router.get("", response_model=GeocodeResponse)
async def geocode(
    q: str = Query(..., min_length=1, max_length=128, description="Search query"),
    limit: int = Query(5, ge=1, le=20),
    providers: Providers = Depends(_providers),
) -> GeocodeResponse:
    results = await providers.geocoding.search(q, limit=limit)
    return GeocodeResponse(
        results=[
            GeocodeResultOut(
                display_name=r.display_name,
                coordinate=CoordinateOut(lat=r.coordinate.lat, lon=r.coordinate.lon),
                country=r.country,
            )
            for r in results
        ],
    )

from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel

from app.domain import Country
from app.providers import get_providers
from app.providers.factory import Providers

router = APIRouter(prefix="/geocode", tags=["geocode"])


def _resolve_lang(
    lang_param: str | None, accept_language: str | None,
) -> str | None:
    """Pick the caller's preferred language for `display_name`.

    Explicit `?lang=xx` wins because the mobile client sends it. When
    it's absent, sniff the first token of `Accept-Language` (browsers
    format it as e.g. `es-ES,es;q=0.9,en;q=0.8`). Returns None when
    neither is set — providers then default to English.
    """
    if lang_param:
        return lang_param
    if accept_language:
        first = accept_language.split(",", 1)[0].strip()
        if first:
            return first
    return None


class CoordinateOut(BaseModel):
    lat: float
    lon: float


class GeocodeResultOut(BaseModel):
    display_name: str
    coordinate: CoordinateOut
    country: Country
    poi_class: str | None = None
    poi_type: str | None = None


class GeocodeResponse(BaseModel):
    results: list[GeocodeResultOut]


def _providers() -> Providers:
    return get_providers()


@router.get("", response_model=GeocodeResponse)
async def geocode(
    q: str = Query(..., min_length=1, max_length=512, description="Search query"),
    limit: int = Query(5, ge=1, le=20),
    lang: str | None = Query(
        None,
        max_length=16,
        description=(
            "Preferred language for display names (ISO 639-1, e.g. 'es'). "
            "Falls back to Accept-Language header, then English."
        ),
    ),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
    providers: Providers = Depends(_providers),
) -> GeocodeResponse:
    results = await providers.geocoding.search(
        q, limit=limit, lang=_resolve_lang(lang, accept_language),
    )
    return GeocodeResponse(
        results=[
            GeocodeResultOut(
                display_name=r.display_name,
                coordinate=CoordinateOut(lat=r.coordinate.lat, lon=r.coordinate.lon),
                country=r.country,
                poi_class=r.poi_class,
                poi_type=r.poi_type,
            )
            for r in results
        ],
    )


@router.get("/reverse", response_model=GeocodeResultOut)
async def reverse_geocode(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    lang: str | None = Query(
        None,
        max_length=16,
        description=(
            "Preferred language for display names (ISO 639-1, e.g. 'es'). "
            "Falls back to Accept-Language header, then English."
        ),
    ),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
    providers: Providers = Depends(_providers),
) -> GeocodeResultOut:
    """Return the nearest known place for `lat`,`lon`.

    Powers the mobile app's "Use my current location" button.
    Returns 404 when no supported-country populated place is close
    enough — the client is expected to show a friendly "we couldn't
    place you" message rather than blowing up.
    """
    result = await providers.geocoding.reverse(
        lat, lon, lang=_resolve_lang(lang, accept_language),
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "no_place_found", "lat": lat, "lon": lon},
        )
    return GeocodeResultOut(
        display_name=result.display_name,
        coordinate=CoordinateOut(
            lat=result.coordinate.lat, lon=result.coordinate.lon,
        ),
        country=result.country,
        poi_class=result.poi_class,
        poi_type=result.poi_type,
    )

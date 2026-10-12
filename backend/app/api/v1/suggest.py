"""AI stop suggestions for a stretch of route (Premium).

``POST /v1/trips/suggest-stops`` takes the polyline of the stretch the driver
is interested in (usually one day) and how much free time they have, finds
REAL places of interest near it, lets the model pick and explain, and
returns only validated picks with their real detour. See
``app.services.stop_suggestions`` for why the model can never add a place.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import time
from typing import Literal

from fastapi import APIRouter, Depends, Header, Query
from pydantic import BaseModel, Field

from app.api.ai_quota import check_and_bump
from app.api.premium import require_premium_subscription
from app.api.v1.inspire import _LANGUAGE_NAMES, _resolve_locale
from app.auth.jwt import AuthUser
from app.providers import get_providers
from app.providers.factory import Providers
from app.services import stop_suggestions as ss

router = APIRouter(prefix="/trips", tags=["suggest"])
_log = logging.getLogger(__name__)

Interest = Literal["food", "viewpoint", "culture", "nature", "kids"]

_PLACES_BUDGET_S = 20.0
_CACHE_TTL_S = 6 * 3600
_CACHE_MAX = 256


class PointIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


class SuggestRequest(BaseModel):
    route: list[PointIn] = Field(
        min_length=2, max_length=600,
        description="Polyline of the stretch to look along (e.g. one day).",
    )
    free_minutes: int = Field(default=90, ge=15, le=480)
    interests: list[Interest] = Field(default_factory=list, max_length=5)
    travellers: int = Field(default=1, ge=1, le=20)
    has_kids: bool = False
    has_pets: bool = False
    locale: str = Field(
        default="en", pattern=r"^[a-zA-Z]{2}(-[A-Za-z]{2})?$",
    )
    limit: int = Field(default=5, ge=1, le=8)
    exclude_names: list[str] = Field(default_factory=list, max_length=30)


class SuggestionOut(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    category: str
    why: str
    visit_minutes: int
    detour_minutes: int
    distance_from_route_km: float
    along_km: float
    fits_window: bool
    website: str | None = None
    google_place_id: str | None = None
    google_maps_url: str | None = None
    # Address, phone, opening hours, Wikipedia link... when the place has them.
    attributes: dict[str, str] = Field(default_factory=dict)


class SuggestResponse(BaseModel):
    suggestions: list[SuggestionOut]
    # False when the model did not take part (unavailable / bad answer):
    # the places are real but have no explanation.
    ai: bool
    reason: str | None = None
    window_minutes: int
    used_minutes: int


# (cache key) -> (stored_at, response)
_CACHE: dict[str, tuple[float, SuggestResponse]] = {}


def _cache_key(req: SuggestRequest, lang: str) -> str:
    payload = json.dumps(
        {
            "r": [[round(p.lat, 3), round(p.lon, 3)] for p in req.route],
            # Exact minutes: the cached answer carries fits_window and
            # window_minutes computed for this value.
            "f": req.free_minutes,
            "x": sorted({n.strip().lower() for n in req.exclude_names}),
            "i": sorted(req.interests),
            "t": req.travellers, "k": req.has_kids, "p": req.has_pets,
            "l": lang, "n": req.limit,
        },
        separators=(",", ":"),
    )
    return hashlib.sha1(payload.encode()).hexdigest()


def _cache_get(key: str) -> SuggestResponse | None:
    hit = _CACHE.get(key)
    if hit is None:
        return None
    stored, resp = hit
    if time.time() - stored > _CACHE_TTL_S:
        _CACHE.pop(key, None)
        return None
    return resp


def _cache_put(key: str, resp: SuggestResponse) -> None:
    if len(_CACHE) >= _CACHE_MAX:
        oldest = min(_CACHE, key=lambda k: _CACHE[k][0])
        _CACHE.pop(oldest, None)
    _CACHE[key] = (time.time(), resp)


async def _fetch_places(
    line: list[tuple[float, float]], interests: list[str],
) -> list[dict] | None:
    """Raw Geoapify features along the route, or None when the places
    provider is not configured."""
    from app.providers import geoapify_poi as geo
    from app.domain import Coordinate

    key = geo._api_key()  # noqa: SLF001
    if not key:
        return None
    categories = ",".join(
        ss.CATEGORIES_BY_INTEREST[i] for i in interests
        if i in ss.CATEGORIES_BY_INTEREST
    )
    samples = ss.sample_route(line, every_km=25.0, max_samples=16)
    total_km = ss.cumulative_km(line)[-1]
    spacing = total_km / max(1, len(samples) - 1) if len(samples) > 1 else 25.0
    radius_km = min(25.0, max(12.0, spacing / 2 + ss.MAX_KM_FROM_ROUTE / 2))
    client = geo._new_client()  # noqa: SLF001
    try:
        results = await asyncio.wait_for(
            asyncio.gather(
                *[
                    geo._search(  # noqa: SLF001
                        client, categories,
                        geo._circle_filter(  # noqa: SLF001
                            Coordinate(lat=lat, lon=lon), radius_km,
                        ),
                        key,
                    )
                    for lat, lon in samples
                ],
                return_exceptions=True,
            ),
            timeout=_PLACES_BUDGET_S,
        )
    except asyncio.TimeoutError:
        _log.warning("suggest-stops: places search exceeded %.0fs", _PLACES_BUDGET_S)
        return []
    finally:
        await client.aclose()
    features: list[dict] = []
    for r in results:
        if isinstance(r, list):
            features.extend(r)
    return features


@router.post("/suggest-stops", response_model=SuggestResponse)
async def suggest_stops(
    payload: SuggestRequest,
    providers: Providers = Depends(get_providers),
    user: AuthUser = Depends(require_premium_subscription),
    lang: str | None = Query(default=None, max_length=16),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
) -> SuggestResponse:
    """Premium. Pick real stops near the route that fit the driver's time."""
    body_locale = payload.locale if payload.locale != "en" else None
    resolved = _resolve_locale(body_locale, lang, accept_language) or payload.locale
    code = resolved.lower().split("-")[0]
    language_name = _LANGUAGE_NAMES.get(code, "English")
    interests: list[str] = list(payload.interests) or list(ss.DEFAULT_INTERESTS)
    if payload.has_kids and "kids" not in interests:
        interests.append("kids")

    key = _cache_key(payload, code)
    cached = _cache_get(key)
    if cached is not None:
        return cached

    # Only a call that really reaches the places API / the model is metered.
    check_and_bump(user, "suggest", is_premium=True)

    line = [(p.lat, p.lon) for p in payload.route]
    features = await _fetch_places(line, interests)
    if features is None:
        return SuggestResponse(
            suggestions=[], ai=False, reason="places_unavailable",
            window_minutes=payload.free_minutes, used_minutes=0,
        )
    excluded = {n.strip().lower() for n in payload.exclude_names}
    candidates = ss.select_candidates(features, line, exclude_names=excluded)
    if not candidates:
        # Not cached: the places provider swallows its own failures
        # (timeout, 429 once the free quota is gone) and returns [], which
        # cannot be told apart from a stretch with nothing of interest.
        return SuggestResponse(
            suggestions=[], ai=False, reason="no_places",
            window_minutes=payload.free_minutes, used_minutes=0,
        )

    prompt = ss.build_prompt(
        candidates,
        free_minutes=payload.free_minutes, interests=interests,
        travellers=payload.travellers, has_kids=payload.has_kids,
        has_pets=payload.has_pets, language_name=language_name,
        limit=payload.limit,
    )
    ai = True
    reason: str | None = None
    picks: list[ss.Pick] = []
    try:
        raw = await providers.llm.generate_narrative(
            prompt, user_id=user.id, endpoint="suggest",
        )
        picks = ss.parse_picks(raw, candidates, payload.limit)
    except Exception as exc:  # noqa: BLE001
        _log.warning("suggest-stops: LLM failed: %r", exc)
    if not picks:
        # The places are real; only the explanation is missing.
        ai = False
        reason = "llm_unavailable"
        picks = ss.fallback_picks(candidates, payload.limit)

    fitted = ss.fit_picks(picks, candidates, payload.free_minutes)
    used = sum(
        s.candidate.detour_minutes + s.visit_minutes
        for s in fitted if s.fits_window
    )
    resp = SuggestResponse(
        suggestions=[
            SuggestionOut(
                id=s.candidate.id, name=s.candidate.name,
                lat=s.candidate.lat, lon=s.candidate.lon,
                category=s.candidate.category, why=s.why,
                visit_minutes=s.visit_minutes,
                detour_minutes=s.candidate.detour_minutes,
                distance_from_route_km=s.candidate.distance_km,
                along_km=s.candidate.along_km,
                fits_window=s.fits_window, website=s.candidate.website,
                attributes=dict(s.candidate.attributes),
                google_place_id=dict(s.candidate.attributes).get("google_place_id"),
                google_maps_url=dict(s.candidate.attributes).get("google_maps_url"),
            )
            for s in fitted
        ],
        ai=ai, reason=reason,
        window_minutes=payload.free_minutes, used_minutes=used,
    )
    # An answer without the model is not worth keeping: the next try
    # should get the chance of a real explanation.
    if ai:
        _cache_put(key, resp)
    return resp

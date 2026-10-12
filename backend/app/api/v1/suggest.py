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
from dataclasses import asdict
from typing import Any, Literal

from fastapi import APIRouter, Depends, Header, Query
from pydantic import BaseModel, Field

from app.api.ai_quota import check_and_bump
from app.api.premium import require_premium_subscription
from app.api.v1.inspire import _LANGUAGE_NAMES, _resolve_locale
from app.auth.jwt import AuthUser
from app.providers import get_providers
from app.providers.factory import Providers
from app.services import stop_suggestions as ss
from app.services import suggest_cache

router = APIRouter(prefix="/trips", tags=["suggest"])
_log = logging.getLogger(__name__)

Interest = Literal[
    "food", "viewpoint", "culture", "history", "nature", "beach", "kids",
    "shopping",
]

_PLACES_BUDGET_S = 20.0
_CACHE_TTL_S = 24 * 3600
_CACHE_MAX = 256
# Corridor key: route samples snapped to ~5 km, so near-identical routes share.
_CORRIDOR_SNAP_DEG = 0.05
_FOOD_LIMIT = 40
_OTHER_LIMIT = 80


class PointIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


class SuggestRequest(BaseModel):
    route: list[PointIn] = Field(
        min_length=2, max_length=600,
        description="Polyline of the stretch to look along (e.g. one day).",
    )
    free_minutes: int = Field(default=90, ge=15, le=480)
    interests: list[Interest] = Field(default_factory=list, max_length=8)
    travellers: int = Field(default=1, ge=1, le=20)
    has_kids: bool = False
    has_pets: bool = False
    locale: str = Field(
        default="en", pattern=r"^[a-zA-Z]{2}(-[A-Za-z]{2})?$",
    )
    limit: int = Field(default=5, ge=1, le=15)
    # Extra real places (not picked by the model) so the app can filter by kind.
    extras: int = Field(default=0, ge=0, le=30)
    exclude_names: list[str] = Field(default_factory=list, max_length=30)


class SuggestionOut(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    category: str
    # Normalised type: food, viewpoint, culture, history, nature, beach,
    # kids, shopping or other.
    kind: str = "other"
    why: str
    visit_minutes: int
    detour_minutes: int
    distance_from_route_km: float
    along_km: float
    fits_window: bool
    # False for the extra places that the model did not choose.
    picked: bool = True
    website: str | None = None
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


# (corridor key) -> (stored_at, core). The core is what is expensive to
# produce (places + the model's picks); fit flags and exclusions are
# recomputed for every request.
_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_background: set[asyncio.Task] = set()


def _free_bucket(minutes: int) -> int:
    for edge in (60, 120, 240):
        if minutes <= edge:
            return edge
    return 480


def _cache_key(
    req: SuggestRequest, lang: str, interests: list[str],
    line: list[tuple[float, float]],
) -> str:
    g = _CORRIDOR_SNAP_DEG
    samples = ss.sample_route(line, every_km=25.0, max_samples=16)
    total_km = ss.cumulative_km(line)[-1]
    payload = json.dumps(
        {
            "r": [[round(la / g), round(lo / g)] for la, lo in samples],
            "d": round(total_km / 10),
            "f": _free_bucket(req.free_minutes),
            "i": sorted(interests),
            "l": lang, "n": req.limit,
        },
        separators=(",", ":"),
    )
    return hashlib.sha1(payload.encode()).hexdigest()


def _core_to_json(
    candidates: list[ss.Candidate], picks: list[ss.Pick],
) -> dict[str, Any]:
    return {
        "candidates": [
            {**asdict(c), "attributes": [list(a) for a in c.attributes]}
            for c in candidates
        ],
        "picks": [asdict(p) for p in picks],
    }


def _core_from_json(
    data: dict[str, Any],
) -> tuple[list[ss.Candidate], list[ss.Pick]] | None:
    try:
        candidates = [
            ss.Candidate(
                **{**c, "attributes": tuple(tuple(a) for a in c["attributes"])},
            )
            for c in data["candidates"]
        ]
        picks = [ss.Pick(**p) for p in data["picks"]]
    except (KeyError, TypeError, ValueError):
        return None
    return candidates, picks


def _l1_put(key: str, core: dict[str, Any], stored_at: float) -> None:
    if len(_CACHE) >= _CACHE_MAX:
        oldest = min(_CACHE, key=lambda k: _CACHE[k][0])
        _CACHE.pop(oldest, None)
    _CACHE[key] = (stored_at, core)


async def _cache_get(key: str) -> dict[str, Any] | None:
    hit = _CACHE.get(key)
    if hit is not None:
        stored, core = hit
        if time.time() - stored <= _CACHE_TTL_S:
            return core
        _CACHE.pop(key, None)
    from_db = await suggest_cache.db_get(key)
    if from_db is None:
        return None
    core, left = from_db
    _l1_put(key, core, time.time() - (_CACHE_TTL_S - left))
    return core


def _cache_put(key: str, core: dict[str, Any]) -> None:
    _l1_put(key, core, time.time())
    try:
        task = asyncio.get_running_loop().create_task(
            suggest_cache.db_put(key, core, _CACHE_TTL_S),
        )
    except RuntimeError:
        return
    _background.add(task)
    task.add_done_callback(_background.discard)


async def _fetch_places(
    line: list[tuple[float, float]], interests: list[str],
) -> list[dict] | None:
    """Raw Geoapify features along the route, or None when the places
    provider is not configured. Food is queried apart from the rest so the
    many restaurants cannot push sights out of a truncated answer."""
    from app.providers import geoapify_poi as geo
    from app.domain import Coordinate

    key = geo._api_key()  # noqa: SLF001
    if not key:
        return None
    food = ss.CATEGORIES_BY_INTEREST["food"] if "food" in interests else ""
    other = ",".join(
        ss.CATEGORIES_BY_INTEREST[i] for i in interests
        if i != "food" and i in ss.CATEGORIES_BY_INTEREST
    )
    groups = [(c, n) for c, n in ((food, _FOOD_LIMIT), (other, _OTHER_LIMIT)) if c]
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
                        key, limit=limit,
                    )
                    for lat, lon in samples
                    for categories, limit in groups
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


def _out(s: ss.Suggestion, *, picked: bool) -> SuggestionOut:
    c = s.candidate
    return SuggestionOut(
        id=c.id, name=c.name, lat=c.lat, lon=c.lon,
        category=c.category, kind=c.kind, why=s.why,
        visit_minutes=s.visit_minutes, detour_minutes=c.detour_minutes,
        distance_from_route_km=c.distance_km, along_km=c.along_km,
        fits_window=s.fits_window, picked=picked, website=c.website,
        attributes=dict(c.attributes),
    )


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

    line = [(p.lat, p.lon) for p in payload.route]
    excluded = {n.strip().lower() for n in payload.exclude_names}
    key = _cache_key(payload, code, interests, line)

    candidates: list[ss.Candidate] = []
    picks: list[ss.Pick] = []
    ai = True
    reason: str | None = None
    cached = await _cache_get(key)
    core = _core_from_json(cached) if cached is not None else None
    if core is not None:
        candidates = ss.rebase_candidates(core[0], line)
        picks = core[1]
    else:
        # Only a call that really reaches the places API / the model is metered.
        check_and_bump(user, "suggest", is_premium=True)

        features = await _fetch_places(line, interests)
        if features is None:
            return SuggestResponse(
                suggestions=[], ai=False, reason="places_unavailable",
                window_minutes=payload.free_minutes, used_minutes=0,
            )
        candidates = ss.select_candidates(features, line)
        if not candidates:
            # Not cached: the places provider swallows its own failures
            # (timeout, 429 once the free quota is gone) and returns [], which
            # cannot be told apart from a stretch with nothing of interest.
            return SuggestResponse(
                suggestions=[], ai=False, reason="no_places",
                window_minutes=payload.free_minutes, used_minutes=0,
            )
        shown = [c for c in candidates if c.name.lower() not in excluded]
        prompt = ss.build_prompt(
            shown,
            free_minutes=payload.free_minutes, interests=interests,
            travellers=payload.travellers, has_kids=payload.has_kids,
            has_pets=payload.has_pets, language_name=language_name,
            limit=payload.limit,
        )
        try:
            raw = await providers.llm.generate_narrative(
                prompt, user_id=user.id, endpoint="suggest",
            )
            picks = ss.parse_picks(raw, shown, payload.limit)
        except Exception as exc:  # noqa: BLE001
            _log.warning("suggest-stops: LLM failed: %r", exc)
        if picks:
            # An answer without the model is not worth keeping: the next try
            # should get the chance of a real explanation.
            _cache_put(key, _core_to_json(candidates, picks))
        else:
            # The places are real; only the explanation is missing.
            ai = False
            reason = "llm_unavailable"
            picks = ss.fallback_picks(shown, payload.limit)

    candidates = [c for c in candidates if c.name.lower() not in excluded]
    if not candidates:
        return SuggestResponse(
            suggestions=[], ai=False, reason="no_places",
            window_minutes=payload.free_minutes, used_minutes=0,
        )
    fitted = ss.fit_picks(picks, candidates, payload.free_minutes)
    used = sum(
        s.candidate.detour_minutes + s.visit_minutes
        for s in fitted if s.fits_window
    )
    extras = (
        ss.extra_suggestions(
            candidates, {s.candidate.id for s in fitted},
            payload.free_minutes, payload.extras,
        )
        if payload.extras else []
    )
    return SuggestResponse(
        suggestions=[_out(s, picked=True) for s in fitted]
        + [_out(s, picked=False) for s in extras],
        ai=ai, reason=reason,
        window_minutes=payload.free_minutes, used_minutes=used,
    )

"""Lazy Google place lookup, hit only when the user taps "Open in Maps".

POIs that were not pre-enriched during ``/plan`` (day-plan stops, fuel,
AI suggestions, saved places) have no Google place id. The mobile app
asks here for one so the Maps card shows the same business as the app
instead of a neighbouring one at the same pin.
"""

from __future__ import annotations

import logging
import os
import re
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from app.auth.dependency import current_user_optional
from app.auth.jwt import AuthUser
from app.providers import google_places as gp

router = APIRouter(prefix="/places", tags=["places"])
_log = logging.getLogger(__name__)

DAILY_LIMIT = int(os.environ.get("MYTRAVELPAL_GOOGLE_RESOLVE_DAILY_LIMIT", "500"))
PER_CLIENT_DAILY_LIMIT = int(
    os.environ.get("MYTRAVELPAL_GOOGLE_RESOLVE_CLIENT_LIMIT", "60"),
)
_ALERT_FRACTIONS = (0.7, 0.9, 1.0)

_SYNTHETIC_NAME = re.compile(r"^\s*km\s*\d+", re.IGNORECASE)

_calls_by_day: dict[str, int] = defaultdict(int)
_client_calls: dict[tuple[str, str], int] = defaultdict(int)
_alerted: set[tuple[str, float]] = set()
_enricher: gp.GooglePlacesEnricher | None = None


class ResolvedPlace(BaseModel):
    google_place_id: str | None = None
    google_maps_url: str | None = None
    google_name: str | None = None
    google_address: str | None = None


def _today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def _alert(message: str) -> None:
    _log.error(message)
    try:
        import sentry_sdk

        sentry_sdk.capture_message(message, level="warning")
    except Exception:  # noqa: BLE001 - alerting must never break a request
        pass


def _count_call() -> bool:
    """Count one billable lookup; False once the global daily cap is spent."""
    day = _today()
    if DAILY_LIMIT and _calls_by_day[day] >= DAILY_LIMIT:
        return False
    _calls_by_day[day] += 1
    used = _calls_by_day[day]
    for frac in _ALERT_FRACTIONS:
        if DAILY_LIMIT and used >= DAILY_LIMIT * frac and (day, frac) not in _alerted:
            _alerted.add((day, frac))
            _alert(
                f"Google Places resolve: {used}/{DAILY_LIMIT} lookups used "
                f"today ({int(frac * 100)}%)",
            )
    return True


def _client_id(request: Request, user: AuthUser | None) -> str:
    if user is not None:
        return f"u:{user.id}"
    ip = (
        request.headers.get("fly-client-ip")
        or request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        or (request.client.host if request.client else "unknown")
    )
    return f"ip:{ip}"


def _get_enricher() -> gp.GooglePlacesEnricher:
    global _enricher
    if _enricher is None:
        _enricher = gp.GooglePlacesEnricher()
    return _enricher


@router.get("/resolve", response_model=ResolvedPlace)
async def resolve_place(
    request: Request,
    name: str = Query(min_length=1, max_length=120),
    lat: float = Query(ge=-90.0, le=90.0),
    lon: float = Query(ge=-180.0, le=180.0),
    address: str | None = Query(default=None, max_length=200),
    user: AuthUser | None = Depends(current_user_optional),
) -> ResolvedPlace:
    """Google place id for a POI, or an empty body when no match is certain."""
    key = gp._api_key()
    name = name.strip()
    if not key or not name or _SYNTHETIC_NAME.match(name):
        return ResolvedPlace()
    found, _ = gp.cache_lookup(name, lat, lon)
    if not found:
        # Cache hits are free; only real Google calls consume the budgets.
        cid = (_client_id(request, user), _today())
        if _client_calls[cid] >= PER_CLIENT_DAILY_LIMIT:
            raise HTTPException(status_code=429, detail="resolve_limit")
        if not _count_call():
            return ResolvedPlace()
        _client_calls[cid] += 1
    extra = await _get_enricher()._lookup(
        name, lat, lon, key, (address or "").strip() or None,
    )
    if not extra:
        return ResolvedPlace()
    return ResolvedPlace(
        google_place_id=extra.get("google_place_id"),
        google_maps_url=extra.get("google_maps_url"),
        google_name=extra.get("google_name"),
        google_address=extra.get("google_address"),
    )

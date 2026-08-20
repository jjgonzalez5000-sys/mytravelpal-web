from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.domain import (
    AdverseEventSeverity,
    AdverseEventType,
    Coordinate,
    Country,
)
from app.providers import get_providers
from app.providers.factory import Providers

router = APIRouter(prefix="/adverse-events", tags=["adverse_events"])


class SubmitAdverseEventRequest(BaseModel):
    type: AdverseEventType
    severity: AdverseEventSeverity = AdverseEventSeverity.WARNING
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)
    description: str = Field(min_length=1, max_length=280)
    country: Country | None = None
    ttl_hours: float = Field(default=24.0, gt=0.0, le=24 * 7)


class SubmittedAdverseEventOut(BaseModel):
    id: str
    type: AdverseEventType
    severity: AdverseEventSeverity
    lat: float
    lon: float
    description: str
    reported_at: datetime
    expires_at: datetime
    country: Country | None


def _providers() -> Providers:
    return get_providers()


@router.post("", response_model=SubmittedAdverseEventOut)
async def submit_event(
    payload: SubmitAdverseEventRequest,
    providers: Providers = Depends(_providers),
) -> SubmittedAdverseEventOut:
    now = datetime.now(timezone.utc)
    event = providers.user_marked_events.submit(
        type=payload.type,
        severity=payload.severity,
        coordinate=Coordinate(lat=payload.lat, lon=payload.lon),
        description=payload.description,
        reported_at=now,
        country=payload.country,
    )
    # ttl_hours override
    if payload.ttl_hours != 24.0:
        # Refresh expires_at using the requested TTL.
        # Direct list mutation for MVP simplicity; a persistent store would
        # do this transactionally.
        from datetime import timedelta

        new_expires = now + timedelta(hours=payload.ttl_hours)
        registry = providers.user_marked_events._events  # noqa: SLF001
        for i, e in enumerate(registry):
            if e.id == event.id:
                registry[i] = _replace_expires(e, new_expires)
                event = registry[i]
                break

    return SubmittedAdverseEventOut(
        id=event.id,
        type=event.type,
        severity=event.severity,
        lat=event.coordinate.lat,
        lon=event.coordinate.lon,
        description=event.description,
        reported_at=event.reported_at,
        expires_at=event.expires_at,
        country=event.country,
    )


def _replace_expires(event, new_expires):
    from dataclasses import replace

    return replace(event, expires_at=new_expires)

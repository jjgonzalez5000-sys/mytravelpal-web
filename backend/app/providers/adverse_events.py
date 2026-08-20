"""Adverse-event providers: fires, strikes, weather, user-reported hazards.

The MVP ships with three providers:

- `UserMarkedAdverseEventsProvider` — in-memory registry of events submitted
  through `POST /v1/adverse-events`. Auto-expires items past their
  `expires_at`. Postgres migration is a follow-up sprint.
- `MockAdverseEventsProvider` — a small, deterministic list of plausible
  events near common EU-4 corridors. Useful for demos and tests.
- `CompositeAdverseEventsProvider` — multiplexes several providers into
  one call.

Real integrations (EFFIS for wildfires, Open-Meteo for adverse weather,
national road authority feeds for strikes and roadwork) slot in behind
`AdverseEventsProvider` in a later sprint.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Protocol

from app.domain import (
    AdverseEvent,
    AdverseEventSeverity,
    AdverseEventSource,
    AdverseEventType,
    Coordinate,
    Country,
    Route,
)


class AdverseEventsProvider(Protocol):
    async def events_along(self, route: Route, *, now: datetime) -> tuple[AdverseEvent, ...]:
        """Return all currently active adverse events the provider knows about.

        Route-distance filtering is applied downstream by the search service —
        providers return a superset and let the caller narrow down.
        """
        ...


class UserMarkedAdverseEventsProvider:
    """Process-local registry of user-submitted events.

    Suitable for MVP; migrate to Postgres before multi-instance deployment.
    """

    def __init__(self) -> None:
        self._events: list[AdverseEvent] = []

    def submit(
        self,
        *,
        type: AdverseEventType,
        severity: AdverseEventSeverity,
        coordinate: Coordinate,
        description: str,
        reported_at: datetime,
        expires_at: datetime | None = None,
        country: Country | None = None,
    ) -> AdverseEvent:
        if expires_at is None:
            expires_at = reported_at + timedelta(hours=24)
        event = AdverseEvent(
            id=uuid.uuid4().hex,
            type=type,
            severity=severity,
            source=AdverseEventSource.USER,
            coordinate=coordinate,
            description=description.strip(),
            reported_at=reported_at,
            expires_at=expires_at,
            country=country,
        )
        self._events.append(event)
        return event

    def all_active(self, *, now: datetime) -> tuple[AdverseEvent, ...]:
        self._events = [e for e in self._events if e.expires_at >= now]
        return tuple(self._events)

    async def events_along(self, route: Route, *, now: datetime) -> tuple[AdverseEvent, ...]:  # noqa: ARG002
        return self.all_active(now=now)


_DEMO_EVENTS: tuple[tuple[AdverseEventType, AdverseEventSeverity, Coordinate, str, Country], ...] = (
    (AdverseEventType.STRIKE, AdverseEventSeverity.WARNING,
     Coordinate(48.85, 2.35), "Rail workers strike — extra road traffic expected.", Country.FR),
    (AdverseEventType.ROADWORK, AdverseEventSeverity.INFO,
     Coordinate(45.76, 4.84), "A6 southbound: night roadworks, 1 lane closed.", Country.FR),
    (AdverseEventType.FIRE, AdverseEventSeverity.CRITICAL,
     Coordinate(43.55, 5.10), "Wildfire near motorway — heavy smoke.", Country.FR),
    (AdverseEventType.WEATHER, AdverseEventSeverity.WARNING,
     Coordinate(42.50, 1.53), "Heavy snowfall in the Pyrenees — winter tyres required.", Country.ES),
    (AdverseEventType.ACCIDENT, AdverseEventSeverity.WARNING,
     Coordinate(41.65, -0.90), "Multi-vehicle accident on AP-2 near Zaragoza.", Country.ES),
    (AdverseEventType.PROTEST, AdverseEventSeverity.INFO,
     Coordinate(45.46, 9.19), "Farmer tractors marching towards Milano centre.", Country.IT),
    (AdverseEventType.FLOOD, AdverseEventSeverity.CRITICAL,
     Coordinate(44.50, 11.34), "Flash-flood warning around Bologna.", Country.IT),
    (AdverseEventType.SNOW, AdverseEventSeverity.WARNING,
     Coordinate(46.20, 6.15), "Fresh snow above 1200 m — chains recommended for alpine passes.", Country.CH),
)


class MockAdverseEventsProvider:
    """Deterministic demo events near common EU-4 corridors."""

    def __init__(self, *, ttl_hours: float = 24.0) -> None:
        self._ttl = timedelta(hours=ttl_hours)

    async def events_along(self, route: Route, *, now: datetime) -> tuple[AdverseEvent, ...]:  # noqa: ARG002
        # Deterministic IDs so the same demo event has the same id across calls.
        events = tuple(
            AdverseEvent(
                id=f"mock:{i}",
                type=t,
                severity=s,
                source=AdverseEventSource.MOCK,
                coordinate=coord,
                description=desc,
                reported_at=now - timedelta(hours=2),
                expires_at=now + self._ttl,
                country=country,
            )
            for i, (t, s, coord, desc, country) in enumerate(_DEMO_EVENTS)
        )
        return events


@dataclass(frozen=True, slots=True)
class CompositeAdverseEventsProvider:
    """Fans out to several providers and concatenates their results."""

    providers: tuple[AdverseEventsProvider, ...]

    async def events_along(self, route: Route, *, now: datetime) -> tuple[AdverseEvent, ...]:
        collected: list[AdverseEvent] = []
        for p in self.providers:
            collected.extend(await p.events_along(route, now=now))
        return tuple(collected)

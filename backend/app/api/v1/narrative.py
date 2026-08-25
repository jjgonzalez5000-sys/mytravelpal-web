"""Trip narrative endpoint (Premium feature).

Runs the trip planner internally, then asks the LLM to produce a
friendly narrative with tailored recommendations. Separate endpoint from
`/trips/plan` so the fast planner isn't blocked by LLM latency, and so
Premium gating (which today is a client-side UX concern; server-side
subscription checks come with real auth) can be reasoned about at the
route level.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.premium import require_premium
from app.api.v1.trips import TripPlanRequest, plan_trip
from app.domain import Coordinate
from app.providers import get_providers
from app.providers.factory import Providers
from app.services.trip_narrative import generate_trip_narrative

router = APIRouter(prefix="/trips", tags=["narrative"])


class NarrativeRequest(BaseModel):
    plan_request: TripPlanRequest
    origin_name: str = "your origin"
    destination_name: str = "your destination"


class NarrativeResponse(BaseModel):
    narrative: str
    origin_name: str
    destination_name: str
    generated_at: datetime


def _providers() -> Providers:
    return get_providers()


@router.post("/narrative", response_model=NarrativeResponse)
async def trip_narrative(
    payload: NarrativeRequest,
    providers: Providers = Depends(_providers),
    _premium: bool = Depends(require_premium),
) -> NarrativeResponse:
    # Plan first (uses the same DI, so hotels/restaurants/adverse events
    # honor the flags the client passed in the plan_request).
    plan = await plan_trip(payload.plan_request, providers=providers)

    # Rebuild the domain objects the narrative service expects.
    from datetime import timedelta

    from app.domain import (
        AdverseEvent,
        AdverseEventSource,
        Country,
        Hotel,
        Restaurant,
        RestStop,
        Route,
        TimeWindow,
    )

    route = Route(
        origin=Coordinate(
            lat=payload.plan_request.origin.lat,
            lon=payload.plan_request.origin.lon,
        ),
        destination=Coordinate(
            lat=payload.plan_request.destination.lat,
            lon=payload.plan_request.destination.lon,
        ),
        distance_km=plan.route.distance_km,
        free_flow_duration=timedelta(minutes=plan.route.free_flow_minutes),
        polyline=plan.route.polyline,
        toll_cost_eur=plan.route.toll_cost_eur,
        countries_crossed=tuple(plan.route.countries_crossed),
    )

    recommended: TimeWindow | None = None
    for w in plan.time_windows:
        if w.recommended:
            recommended = TimeWindow(
                departure_at=w.departure_at,
                estimated_duration=timedelta(minutes=w.estimated_minutes),
                traffic_factor=w.traffic_factor,
                recommended=True,
            )
            break

    rest_stops = tuple(
        RestStop(
            coordinate=Coordinate(lat=s.lat, lon=s.lon),
            distance_from_origin_km=s.distance_from_origin_km,
            cumulative_driving_hours=s.cumulative_driving_hours,
            recommended_break_minutes=s.recommended_break_minutes,
        )
        for s in plan.rest_stops
    )

    hotels = tuple(
        Hotel(
            name=h.name, country=h.country,
            price_eur_per_night=h.price_eur_per_night,
            price_band=h.price_band,
            distance_from_route_km=h.distance_from_route_km,
            detour_minutes=h.detour_minutes,
            coordinate=Coordinate(lat=h.lat, lon=h.lon),
        )
        for h in plan.hotels
    )
    restaurants = tuple(
        Restaurant(
            name=r.name, country=r.country,
            price_eur_per_meal=r.price_eur_per_meal,
            price_band=r.price_band,
            distance_from_route_km=r.distance_from_route_km,
            detour_minutes=r.detour_minutes,
            coordinate=Coordinate(lat=r.lat, lon=r.lon),
        )
        for r in plan.restaurants
    )
    adverse_events = tuple(
        AdverseEvent(
            id=e.id, type=e.type, severity=e.severity,
            source=AdverseEventSource(e.source),
            coordinate=Coordinate(lat=e.lat, lon=e.lon),
            description=e.description,
            reported_at=e.reported_at, expires_at=e.expires_at,
            country=e.country,
        )
        for e in plan.adverse_events
    )

    narrative = await generate_trip_narrative(
        llm=providers.llm,
        origin_name=payload.origin_name,
        destination_name=payload.destination_name,
        desired_departure_at=payload.plan_request.desired_departure_at,
        route=route,
        recommended=recommended,
        rest_stops=rest_stops,
        hotels=hotels,
        restaurants=restaurants,
        adverse_events=adverse_events,
    )

    return NarrativeResponse(
        narrative=narrative,
        origin_name=payload.origin_name,
        destination_name=payload.destination_name,
        generated_at=datetime.now(timezone.utc),
    )

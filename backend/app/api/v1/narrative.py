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

from fastapi import APIRouter, Depends, Header, Query
from pydantic import BaseModel

from app.api.ai_quota import require_narrative_quota
from app.api.premium import require_premium
from app.api.v1.inspire import _language_instruction, _resolve_locale
from app.auth.jwt import AuthUser
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
    # BCP-47-ish 2-letter code. Optional so old mobile builds keep
    # working (default English). When present, the LLM is instructed
    # to write the narrative + recommendations in this language.
    lang: str | None = None


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
    # JWT + daily quota (project_ai_cost_defense layer 1+2). The
    # existing `require_premium` gates the FEATURE; this dep gates
    # the per-user COST.
    _user: AuthUser = Depends(require_narrative_quota),
    # Locale channels — body `lang` field is primary, ?lang= query
    # and Accept-Language header as redundant fallbacks. Old clients
    # sending none of the three inherit the historical English default.
    lang: str | None = Query(default=None, max_length=16),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
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

    # Pass the ACTUAL planned stops (from optimizations + day plan) so
    # the LLM knows what has already been scheduled and doesn't suggest
    # stops the app has already placed.
    planned_meal_stops = []
    planned_sleep = None
    planned_days = []
    if plan.optimizations:
        planned_meal_stops = [
            {
                "slot": m.slot.value if hasattr(m.slot, "value") else str(m.slot),
                "at": m.at.isoformat(),
                "km": m.distance_from_origin_km,
                "restaurant": m.restaurant_name,
                "city": m.city_hint,
                "price_eur": m.restaurant_price_eur_per_meal,
            }
            for m in plan.optimizations.meal_stops
        ]
        s = plan.optimizations.sleep_stop
        if s:
            planned_sleep = {
                "at": s.at.isoformat(),
                "km": s.distance_from_origin_km,
                "hotel": s.hotel_name,
                "city": s.city_hint,
                "price_eur": s.hotel_price_eur_per_night,
            }
    if plan.days:
        planned_days = [
            {
                "day": d.day_index,
                "km": d.to_km - d.from_km,
                "from_km": d.from_km,
                "to_km": d.to_km,
                "sleep_at": d.sleep_at.isoformat() if d.sleep_at else None,
            }
            for d in plan.days
        ]

    resolved_lang = _resolve_locale(payload.lang, lang, accept_language)
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
        planned_meal_stops=planned_meal_stops,
        planned_sleep=planned_sleep,
        planned_days=planned_days,
        language_directive=_language_instruction(resolved_lang),
    )

    return NarrativeResponse(
        narrative=narrative,
        origin_name=payload.origin_name,
        destination_name=payload.destination_name,
        generated_at=datetime.now(timezone.utc),
    )


class AudioRequest(BaseModel):
    """Request to synthesize a pre-generated narrative text to MP3 audio."""
    narrative_text: str
    voice: str = "nova"
    speed: float = 1.0  # 0.25–4.0; passed directly to OpenAI TTS


class AudioResponse(BaseModel):
    audio_base64: str | None  # base64-encoded MP3; None = use device TTS
    voice: str
    model: str


@router.post("/narrative/audio", response_model=AudioResponse)
async def narrative_audio(
    payload: AudioRequest,
    _premium: bool = Depends(require_premium),
    _user: AuthUser = Depends(require_narrative_quota),
) -> AudioResponse:
    """Synthesize narrative text to MP3 using OpenAI TTS.

    Returns ``audio_base64: null`` when OPENAI_API_KEY is not configured —
    the mobile client falls back to device TTS in that case.
    """
    import base64
    from app.providers.tts_openai import synthesize, DEFAULT_MODEL

    mp3_bytes = await synthesize(
        payload.narrative_text,
        voice=payload.voice,
        speed=payload.speed,
    )
    if mp3_bytes is None:
        return AudioResponse(audio_base64=None, voice=payload.voice, model=DEFAULT_MODEL)

    return AudioResponse(
        audio_base64=base64.b64encode(mp3_bytes).decode("ascii"),
        voice=payload.voice,
        model=DEFAULT_MODEL,
    )

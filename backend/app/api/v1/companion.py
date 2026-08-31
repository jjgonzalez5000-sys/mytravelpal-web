"""Companion mode endpoint — rule-based driving assistant.

Phase A of the Companion feature (see project_companion_concept
memory). Takes the driver's current state (GPS, driving time,
profile, preferences) and returns 0..N recommendations the client
surfaces as cards + TTS. Zero LLM cost — pure rules.

Phase B (post-beta) swaps the rule engine for a Claude Haiku call
that produces personalised natural-language recs. Same request /
response shape so the client doesn't need to change.

Design principles:
- Stateless. The client passes everything the engine needs; the
  server holds no session. Scales cheap.
- Throttled at the client: it should hit /tick every ~60s and
  filter dupes locally. The engine still applies per-category
  cooldowns so back-to-back ticks don't spam identical recs.
- Recommendation shape is stable (kind, title, body, actions[])
  so the mobile UI is a simple switch on `kind`.
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any, Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.auth.dependency import current_user_optional
from app.auth.jwt import AuthUser
from app.domain import AdverseEventSeverity, AdverseEventType, Coordinate
from app.providers import get_providers
from app.providers.factory import Providers

router = APIRouter(prefix="/companion", tags=["companion"])

# Radius the Companion queries for critical adverse events.
# Driving: 50 km ≈ 30 min at highway speed — enough react-time.
# Idle (config screen open, no driving yet): 100 km ≈ context-level
# alert so the driver knows before they leave.
_CRITICAL_RADIUS_DRIVING_KM = 50.0
_CRITICAL_RADIUS_IDLE_KM = 100.0

# In-process cache for adverse events. The upstream feeds (EFFIS
# fires, Open-Meteo weather) don't change on 60s scales, so ticking
# them every /tick would waste quota. TTL 5 min hits a real weather
# spike within a few ticks while dropping ~30x provider load.
_ADVERSE_CACHE: dict[str, tuple[float, list[Any]]] = {}
_ADVERSE_CACHE_TTL_S = 300.0


def _haversine_km(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> float:
    """Great-circle distance in km. Same math as
    `providers.routing._haversine_km` but inlined so the endpoint
    doesn't pull the routing provider into its imports.
    """
    r = 6371.0
    p1 = math.radians(a_lat)
    p2 = math.radians(b_lat)
    dp = math.radians(b_lat - a_lat)
    dl = math.radians(b_lon - a_lon)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return r * c


async def _critical_events_near(
    providers: Providers,
    lat: float,
    lon: float,
    radius_km: float,
    now: datetime,
) -> list[Any]:
    """Fetch CRITICAL adverse events within `radius_km` of the
    point. Uses an in-process 5-minute cache keyed by the point
    (rounded to ~10 km grid) so back-to-back ticks share results
    without re-hitting EFFIS / Open-Meteo.

    Under the hood we build a synthetic 2-point Route (`origin` +
    a point one radius north) so the existing
    `events_along` providers see a bbox big enough to cover the
    circle. Post-filter by haversine so results outside the
    radius are dropped.
    """
    import time as _time
    from app.domain import Country, Route
    from datetime import timedelta

    # Cache key: 0.1° grid (~11 km) so nearby ticks share results.
    key = f"{round(lat, 1)}:{round(lon, 1)}:{int(radius_km)}"
    now_mono = _time.monotonic()
    cached = _ADVERSE_CACHE.get(key)
    if cached and now_mono - cached[0] < _ADVERSE_CACHE_TTL_S:
        return cached[1]

    # Synthesise a Route that covers roughly a `radius_km` circle
    # around the point. `north_offset_deg` = radius / 111 (km per
    # deg lat, approx).
    off = radius_km / 111.0
    origin = Coordinate(lat=lat - off, lon=lon)
    destination = Coordinate(lat=lat + off, lon=lon)
    route = Route(
        origin=origin,
        destination=destination,
        distance_km=radius_km * 2,
        free_flow_duration=timedelta(hours=1),
        polyline="",
        toll_cost_eur=0.0,
        countries_crossed=(Country.FR,),  # placeholder; providers usually re-detect
        waypoints=(Coordinate(lat=lat, lon=lon),),
        geometry=(origin, Coordinate(lat=lat, lon=lon), destination),
        avoid_tolls=False,
    )

    try:
        raw = await providers.adverse_events.events_along(route, now=now)
    except Exception:
        raw = ()

    # CLOSURE covers scheduled roadworks / lane closures which
    # upstream feeds often tag as CRITICAL even when they don't
    # constitute a safety emergency. Tester feedback (2026-08-30):
    # roadworks appearing next to fires and floods diluted the
    # signal. Filter them out here — the /plan endpoint still
    # surfaces closures in the normal adverse-events list.
    critical = [
        e for e in raw
        if e.severity == AdverseEventSeverity.CRITICAL
        and e.type != AdverseEventType.CLOSURE
        and _haversine_km(lat, lon, e.coordinate.lat, e.coordinate.lon)
            <= radius_km
    ]
    _ADVERSE_CACHE[key] = (now_mono, critical)
    return critical


class CompanionState(BaseModel):
    """Snapshot of the driver's current context. Everything the
    engine needs to decide what to recommend.
    """
    # GPS
    lat: float
    lon: float
    speed_kmh: float | None = None
    heading_deg: float | None = None
    # Driving session
    driving_time_hours: float = 0.0
    session_started_at: datetime | None = None
    # Config from the Companion setup screen
    break_interval_hours: float = 2.0
    alert_weather: bool = True
    alert_fuel: bool = True
    alert_border: bool = True
    alert_toll: bool = True
    alert_hotel: bool = True
    # Critical adverse-event alerts (fires, floods, quakes, etc.).
    # Historically ungated on the server ("safety > preference")
    # but that hid the choice from users who wanted to silence
    # them (e.g. a passenger with existing anxiety). Now it's a
    # first-class toggle, still default True so the safety-first
    # posture is the norm.
    alert_critical_adverse: bool = True
    # EXPERIMENTAL: when the fatigue heuristic fires (drove >=
    # break_interval without a real stop) also emit an immediate
    # "pull over at the next service area" recommendation. Off by
    # default because the current signal is timer-only — over-
    # eager for drivers who take micro-pauses the phone can't see.
    fatigue_stop_suggestion: bool = False
    # Profile summary (subset — the parts the engine actually uses)
    has_kids: bool = False
    has_pets: bool = False
    bedtime_hour: int = 22
    # Client-side dedup: recs the driver already saw or dismissed
    # this session. The engine won't re-emit these.
    dismissed_kinds: list[str] = Field(default_factory=list)
    # Country the client thinks the driver was in on the previous
    # tick (ISO-2 code, e.g. "FR"). The border-crossing rule
    # fires when the current country (derived from GPS) differs
    # from this. `None` on the first tick after Companion starts
    # (no baseline yet).
    previous_country_code: str | None = None


class CompanionAction(BaseModel):
    """One button on a recommendation card."""
    kind: Literal["dismiss", "open_maps", "later", "call"]
    label: str
    payload: dict[str, Any] = Field(default_factory=dict)


class Recommendation(BaseModel):
    """One card the client renders + optionally speaks via TTS."""
    kind: Literal[
        "break", "meal", "fuel", "weather", "border", "toll",
        "hotel", "adverse",
    ]
    # `high` renders red + auto-TTS; `critical` renders red + auto-
    # TTS AND blocks the rest of the UI (modal-style card) until
    # dismissed. Reserved for CRITICAL adverse events where a
    # silent miss could put the driver at risk.
    priority: Literal["low", "normal", "high", "critical"] = "normal"
    title: str
    body: str
    # Voice-friendly compact version for TTS. When None the client
    # can speak `title` directly.
    speech: str | None = None
    # Optional geo hint so the client can plot the event on the
    # map when the driver taps "Ver en mapa".
    lat: float | None = None
    lon: float | None = None
    # Distance in km from the driver's current position — used by
    # the client for sort + display ("Incendio a 34 km").
    distance_km: float | None = None
    actions: list[CompanionAction] = Field(default_factory=list)


class CompanionTickResponse(BaseModel):
    recommendations: list[Recommendation]
    # Client uses this to align its GPS polling with our engine's
    # cadence — the engine may return an empty list for a few
    # ticks in a row when nothing changes.
    next_tick_seconds: int = 60
    # Country detected on this tick (ISO-2). Client stores it and
    # sends back as `previous_country_code` next tick so the
    # border-crossing rule works statelessly.
    detected_country_code: str | None = None


# Per-country "welcome brief" served when the Companion detects a
# border crossing. Kept short — driver hears this via TTS, no
# scrolling. Speed limits: autopista / carretera / urban when
# applicable; single value = general limit outside cities.
# Quirks flag notable local legalities the driver often forgets.
_COUNTRY_BRIEF: dict[str, dict[str, str]] = {
    "ES": {
        "speed": "120 km/h autopista, 90 carretera, 50 urbano",
        "quirks": "Chaleco reflectante y 2 triángulos obligatorios",
    },
    "FR": {
        "speed": "130 km/h autopista (110 lluvia), 80 carretera",
        "quirks": "Alcoholímetro recomendado, priorité à droite",
    },
    "IT": {
        "speed": "130 km/h autostrada, 90 extraurbana",
        "quirks": "Alcohol 0.0 conductores <21 y profesionales",
    },
    "DE": {
        "speed": "Autobahn sin límite en tramos, 100 extraurbana",
        "quirks": "Umweltzonen — pegatina medioambiental en Berlín, Múnich, etc.",
    },
    "AT": {
        "speed": "130 km/h autobahn, 100 landstrasse",
        "quirks": "Vignette obligatoria (~10€/10 días)",
    },
    "CH": {
        "speed": "120 km/h autopista, 80 carretera",
        "quirks": "Vignette anual obligatoria (~40€), estricto con alcohol",
    },
    "SI": {"speed": "130 km/h autopista", "quirks": "Vignette obligatoria"},
    "CZ": {"speed": "130 km/h dálnice", "quirks": "Vignette obligatoria"},
    "SK": {"speed": "130 km/h", "quirks": "Vignette obligatoria"},
    "HU": {"speed": "130 km/h autópálya", "quirks": "e-Vignette obligatoria"},
    "PT": {
        "speed": "120 km/h autopista",
        "quirks": "Peajes electrónicos SCUT en algunas autopistas",
    },
    "BE": {"speed": "120 km/h autoroute", "quirks": "Prioridad a derecha estricta"},
    "NL": {"speed": "100 km/h autosnelweg (día), 130 noche"},
    "LU": {"speed": "130 km/h autoroute"},
    "GB": {"speed": "70 mph motorway (~112 km/h)", "quirks": "Se conduce por la izquierda"},
    "IE": {"speed": "120 km/h motorway", "quirks": "Se conduce por la izquierda"},
    "GR": {"speed": "130 km/h εθνικές οδοί"},
    "HR": {"speed": "130 km/h autocesta"},
    "PL": {"speed": "140 km/h autostrada", "quirks": "Luces obligatorias día y noche"},
    "RO": {"speed": "130 km/h autostradă", "quirks": "Vignette (rovinieta) obligatoria"},
    "BG": {"speed": "140 km/h magistrala", "quirks": "Vignette obligatoria"},
    "DK": {"speed": "130 km/h motorvej"},
    "SE": {"speed": "120 km/h motorväg"},
    "NO": {"speed": "110 km/h motorvei", "quirks": "Peajes AutoPASS (facturación por matrícula)"},
    "FI": {"speed": "120 km/h moottoritie (verano), 100 invierno"},
    "EE": {"speed": "110 km/h", "quirks": "Luces obligatorias día y noche"},
    "LV": {"speed": "110 km/h", "quirks": "Luces obligatorias día y noche"},
    "LT": {"speed": "130 km/h autostrada (verano)"},
    "IS": {"speed": "90 km/h asfalto, 80 gravilla"},
    "MT": {"speed": "80 km/h", "quirks": "Se conduce por la izquierda"},
    "CY": {"speed": "100 km/h autopista", "quirks": "Se conduce por la izquierda"},
    # Balkans + Andorra (added 2026-08-30)
    "AD": {
        "speed": "90 km/h general, 60 túneles",
        "quirks": "IVA bajo — combustible más barato",
    },
    "BA": {
        "speed": "130 km/h autoput, 100 magistrala",
        "quirks": "Vignette no obligatoria; peajes en tramos concretos",
    },
    "RS": {
        "speed": "130 km/h autoput",
        "quirks": "Peajes por ticket en la autopista (paga al salir)",
    },
    "ME": {
        "speed": "100 km/h general (no autopista salvo Bar–Boljare)",
        "quirks": "Tunel Sozina — peaje ~3.50€",
    },
    "MK": {
        "speed": "130 km/h avtopat",
        "quirks": "Peajes por ticket en autopista",
    },
    "AL": {
        "speed": "110 km/h autostrada (Tirana–Durrës)",
        "quirks": "Muchos carriles compartidos con peatones/animales",
    },
}


def _country_from_coord(lat: float, lon: float) -> str | None:
    """Best-effort ISO-2 country code from GPS. Uses the same
    `detect_country` helper the trip planner uses so results
    stay consistent across features.
    """
    from app.services.country_detection import detect_country
    from app.domain import Coordinate

    c = detect_country(Coordinate(lat=lat, lon=lon))
    return c.value if c else None


_ADVERSE_LABEL = {
    AdverseEventType.FIRE: ("🔥", "Active fire"),
    AdverseEventType.WEATHER: ("⛈️", "Severe weather"),
    AdverseEventType.FLOOD: ("🌊", "Flood"),
    AdverseEventType.SNOW: ("❄️", "Heavy snow"),
    AdverseEventType.EARTHQUAKE: ("🌐", "Earthquake"),
    AdverseEventType.LANDSLIDE: ("⛰️", "Landslide"),
    AdverseEventType.AVALANCHE: ("🏔️", "Avalanche"),
    AdverseEventType.CLOSURE: ("🚧", "Road closure"),
    AdverseEventType.HEATWAVE: ("🌡️", "Heatwave"),
    AdverseEventType.ACCIDENT: ("💥", "Major accident"),
    AdverseEventType.STRIKE: ("📢", "Strike"),
    AdverseEventType.PROTEST: ("👥", "Protest"),
    AdverseEventType.ROADWORK: ("🚧", "Roadwork"),
    AdverseEventType.OTHER: ("⚠️", "Alert"),
}


@router.post("/tick", response_model=CompanionTickResponse)
async def tick(
    state: CompanionState,
    user: AuthUser | None = Depends(current_user_optional),
    providers: Providers = Depends(get_providers),
) -> CompanionTickResponse:
    """Run the Companion engine one tick. Returns 0..N
    recommendations for the current driver state.

    Anonymous access allowed: the Companion mode should be usable
    even for a user who hasn't signed in (F&F beta scenario).
    Personalisation improves with a JWT because the engine can
    then read `profile.travel_pace` etc.
    """
    recs: list[Recommendation] = []
    now = datetime.now(tz=timezone.utc)

    # 1. Break reminder (Fatigue Phase A). Profile-aware rules:
    # - Base interval from `state.break_interval_hours`.
    # - With kids or pets → shrink interval by 25 % (families
    #   need more frequent stops).
    # - Between bedtime and 06:00 → priority `high` from the
    #   first break (night driving is the most fatigue-prone).
    # - Past 3.5 h continuous → priority `high` regardless of
    #   time-of-day.
    # - Past 4.5 h continuous → priority `critical` (mandatory
    #   break flag; matches EU HGV regulation for professional
    #   drivers).
    kids_or_pets = state.has_kids or state.has_pets
    effective_interval = (
        state.break_interval_hours * 0.75 if kids_or_pets
        else state.break_interval_hours
    )
    is_night = (
        now.hour >= state.bedtime_hour
        or now.hour <= 6
    )
    if state.driving_time_hours >= effective_interval and \
            "break" not in state.dismissed_kinds:
        hours = int(state.driving_time_hours)
        minutes = int((state.driving_time_hours - hours) * 60)
        # Priority ladder.
        if state.driving_time_hours >= 4.5:
            priority = "critical"
        elif state.driving_time_hours >= 3.5 or is_night:
            priority = "high"
        else:
            priority = "normal"
        # Reason line — surfaces WHY we're nagging harder.
        reason = None
        if state.driving_time_hours >= 4.5:
            reason = (
                "You've driven over 4.5 h continuously — accident "
                "risk climbs sharply past this point."
            )
        elif is_night:
            reason = (
                "Night driving multiplies fatigue risk. Stop "
                "sooner rather than later."
            )
        elif state.has_kids:
            reason = "The kids will thank you for a short stretch."
        elif state.has_pets:
            reason = "Pets need a bathroom + water break too."
        body = f"You've been driving for {hours}h {minutes}m. " + (
            reason or "A short stop helps you stay sharp."
        )
        speech = (
            f"You've been driving for {hours} hours. "
            + (reason or "Consider a short break at the next rest area.")
        )
        recs.append(Recommendation(
            kind="break",
            priority=priority,
            title="Time for a break",
            body=body,
            speech=speech,
            actions=[
                CompanionAction(kind="dismiss", label="Dismiss"),
                CompanionAction(kind="later", label="In 15 min"),
            ],
        ))
        # Experimental: turn the timer-based fatigue signal into a
        # concrete action — "pull over at the next service area".
        # Only fires when the driver explicitly opted in AND we
        # already crossed the break interval. Sits at high priority
        # so the driver hears the break card and this immediately
        # after.
        if state.fatigue_stop_suggestion and \
                "fatigue_stop" not in state.dismissed_kinds:
            recs.append(Recommendation(
                kind="break",
                priority="high",
                title="Pull over at the next service area",
                body=(
                    "You've been driving without a real break. Fatigue "
                    "builds silently — a five-minute stop now beats a "
                    "microsleep in the next hour."
                ),
                speech=(
                    "Please pull over at the next service area. "
                    "A short stop now beats fatigue later."
                ),
                actions=[
                    CompanionAction(kind="dismiss", label="Dismiss"),
                ],
            ))

    # 2. Hotel suggestion — driver past bedtime and no destination.
    if state.alert_hotel and \
            now.hour >= state.bedtime_hour and \
            state.driving_time_hours >= 5.0 and \
            "hotel" not in state.dismissed_kinds:
        recs.append(Recommendation(
            kind="hotel",
            priority="high",
            title="Consider stopping for the night",
            body=(
                "It's past your usual bedtime and you've been driving "
                "over 5 h. Fatigue is the main road-trip risk."
            ),
            speech=(
                "It's late and you've been driving a long time. "
                "Consider finding a hotel."
            ),
            actions=[
                CompanionAction(kind="dismiss", label="Dismiss"),
                CompanionAction(kind="later", label="In 30 min"),
            ],
        ))

    # 3. Critical adverse events near current position. Gated on
    #    `alert_critical_adverse` (default True) so drivers who
    #    consciously silence them see nothing here — but the
    #    default keeps the safety-first posture. Radius depends
    #    on whether the driver is moving: idle context gets a
    #    bigger heads-up circle so they can decide before leaving.
    driving = state.driving_time_hours > 0.0 or (
        state.speed_kmh is not None and state.speed_kmh > 5.0
    )
    radius = (
        _CRITICAL_RADIUS_DRIVING_KM if driving
        else _CRITICAL_RADIUS_IDLE_KM
    )
    critical_events = (
        await _critical_events_near(
            providers, state.lat, state.lon, radius, now,
        )
        if state.alert_critical_adverse else ()
    )
    seen_ids: set[str] = set()
    for ev in critical_events:
        # Dedup — some providers emit near-identical events at
        # multiple grid cells for the same phenomenon.
        if ev.id in seen_ids:
            continue
        seen_ids.add(ev.id)
        distance_km = _haversine_km(
            state.lat, state.lon, ev.coordinate.lat, ev.coordinate.lon,
        )
        emoji, label = _ADVERSE_LABEL.get(
            ev.type, ("⚠️", "Alert"),
        )
        title = f"{emoji} {label.upper()} · {distance_km:.0f} km"
        body = ev.description or label
        recs.append(Recommendation(
            kind="adverse",
            priority="critical",
            title=title,
            body=body,
            speech=(
                f"Warning: {label.lower()} {distance_km:.0f} kilometres away. "
                f"{body}"
            ),
            lat=ev.coordinate.lat,
            lon=ev.coordinate.lon,
            distance_km=round(distance_km, 1),
            actions=[
                CompanionAction(
                    kind="open_maps",
                    label="View on map",
                    payload={
                        "lat": ev.coordinate.lat,
                        "lon": ev.coordinate.lon,
                    },
                ),
                CompanionAction(kind="dismiss", label="Dismiss"),
            ],
        ))

    # 4. Border-crossing brief. Fires once when the ISO-2
    #    country detected from GPS differs from the one the
    #    client sent as `previous_country_code`. First tick of
    #    a session has no baseline → no rec.
    current_country = _country_from_coord(state.lat, state.lon)
    if (
        state.alert_border
        and current_country is not None
        and state.previous_country_code is not None
        and current_country != state.previous_country_code
    ):
        brief = _COUNTRY_BRIEF.get(current_country, {})
        from app.domain import Country
        try:
            country_display = Country(current_country).value
        except ValueError:
            country_display = current_country
        try:
            from app.data.countries import COUNTRIES as _C
            country_display = _C.get(current_country).display_name  # type: ignore[union-attr]
        except Exception:
            pass
        parts: list[str] = []
        if brief.get("speed"):
            parts.append(brief["speed"])
        # Fuel + toll figures from CountryData when available.
        try:
            from app.data.countries import COUNTRIES as _COUNTRIES
            cd = _COUNTRIES.get(current_country)
            if cd:
                if cd.toll_per_km_eur > 0:
                    parts.append(
                        f"Peaje ~{cd.toll_per_km_eur:.2f} €/km"
                    )
                if cd.vignette_eur > 0:
                    parts.append(
                        f"Vignette ~{cd.vignette_eur:.0f} €"
                    )
                parts.append(
                    f"Gasolina ~{cd.fuel_petrol_anchor_eur:.2f} €/L"
                )
        except Exception:
            pass
        if brief.get("quirks"):
            parts.append(brief["quirks"])
        body = " · ".join(parts) if parts else (
            "New country — drive carefully."
        )
        title = f"🌍 {country_display}"
        recs.append(Recommendation(
            kind="border",
            priority="high",
            title=title,
            body=body,
            speech=f"Entrando en {country_display}. {body}",
            actions=[CompanionAction(kind="dismiss", label="OK")],
        ))

    # Placeholders for future rule-based checks; wire once the
    # client passes richer context (nearby POIs, weather forecast
    # ahead). See project_companion_concept.md for the full list.
    #
    # if state.alert_fuel:    recs.extend(_fuel_rules(state))
    # if state.alert_toll:    recs.extend(_toll_rules(state))

    # Sort by priority so critical/high-priority recs render first.
    priority_rank = {"critical": 0, "high": 1, "normal": 2, "low": 3}
    recs.sort(key=lambda r: priority_rank[r.priority])

    return CompanionTickResponse(
        recommendations=recs,
        next_tick_seconds=60,
    )

from __future__ import annotations

import asyncio
import hashlib
import logging
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.api.premium import is_premium
from app.auth.dependency import current_user_optional
from app.auth.jwt import AuthUser

_log = logging.getLogger(__name__)

from app.domain import (
    AdverseEventSeverity,
    AdverseEventType,
    BreakStyle,
    Coordinate,
    Country,
    FuelType,
    MealPreferences,
    MealSlot,
    OvernightPolicy,
    PriceBand,
    RestStop,
    RestStopType,
    TravelPace,
    Trip,
    TripProfile,
    Vehicle,
    VehicleType,
    Waypoint,
)
from app.domain.entities import Route


def _day_overrides_map(
    payload: "TripPlanRequest",
) -> dict[int, dict[str, int | None]]:
    """Flatten `payload.day_overrides` into the dict shape
    `trip_optimizations.compute` wants. Keeps None values so the
    picker in `compute` can distinguish "not overridden" from "value
    is 0" — 0 is out of the pydantic Field range anyway, but the
    explicit None keeps intent clear.
    """
    out: dict[int, dict[str, int | None]] = {}
    for ov in getattr(payload, "day_overrides", None) or ():
        out[ov.day_index] = {
            "start_hour": ov.start_hour,
            "daily_driving_cap_hours": ov.daily_driving_cap_hours,
        }
    return out


def _reason_for_rest_stop(
    stop: RestStop,
    profile: TripProfile | None,
) -> str | None:
    """Compose the short WHY string mobile shows in the info sheet.
    Combines matched OSM amenity flags with the user's profile prefs
    so a "kid-friendly" area only earns that mention when the driver
    is actually travelling with kids. Falls back to the stop-type
    label when nothing preference-relevant matched.
    """
    reasons: list[str] = []
    has_kids = bool(getattr(profile, "has_kids", False)) if profile else False
    has_pets = bool(getattr(profile, "has_pets", False)) if profile else False
    is_rv = (
        profile is not None
        and getattr(getattr(profile, "vehicle", None), "type", None)
        == VehicleType.CAMPER
    )

    if stop.kid_friendly and has_kids:
        reasons.append("Área compatible con niños según tu perfil")
    if stop.pet_friendly and has_pets:
        reasons.append("Zona para mascotas según tu perfil")
    if stop.rv_friendly and is_rv:
        reasons.append("Compatible con autocaravana según tu perfil")

    # Type-based fallback so every stop has SOMETHING to say when the
    # profile prefs didn't match anything specific.
    if not reasons:
        type_labels = {
            RestStopType.SERVICE_AREA:
                "Área de servicio con restaurante y aseos",
            RestStopType.REST_AREA:
                "Área de descanso con aparcamiento seguro",
            RestStopType.GAS_STATION:
                "Gasolinera para repostar y descansar",
            RestStopType.CARAVAN_SITE:
                "Área para caravanas con servicios completos",
            RestStopType.PARKING:
                "Aparcamiento tranquilo para una pausa breve",
        }
        label = type_labels.get(stop.stop_type)
        if label:
            reasons.append(label)

    if not reasons:
        return None
    return " · ".join(reasons)
from app.providers import get_providers
from app.providers.factory import Providers
from app.providers.google_places import GooglePlacesEnricher
from app.providers.here_places import HerePlacesEnricher
from app.services.adverse_events_filter import filter_events_near_route
from app.services.day_plan import compute as compute_day_plan
from app.services.fuel_cost import FuelCostEstimate, estimate as estimate_fuel
from app.services.fuel_curator import _bucketed_top_cheapest
from app.services.fuel_savings import (
    cross_country_arbitrage as compute_fuel_arbitrage,
    curate_stations as curate_fuel_stations,
    stamp_savings as stamp_fuel_savings,
)
from app.services.hotel_search import filter_hotels
from app.services.hourly_toll_analysis import analyze as hourly_toll_analyze
from app.services.polyline_simplify import simplify as simplify_polyline
from app.services.rest_stops import compute_rest_stops
from app.services.restaurant_search import filter_restaurants
from app.services.time_window import (
    TimeWindowConfig,
    compute_time_windows,
    minutes_saved_vs_desired,
)
from app.providers.tolls_here import HereTollsProvider as _HereTollsProvider
from app.services.intra_section_skips import compute as compute_intra_section_skips
from app.services.partial_toll_skips import compute as compute_partial_skips
from app.services.route_variants import compute_variants
from app.services.toll_savings import compare as compare_toll
from dataclasses import replace as _dc_replace
from app.services.consistency import check_trip as check_trip_consistency
from app.services.plan_cache import get_plan_cache, PlanCacheSlot
from app.services.trip_optimizations import compute as compute_optimizations
from app.services.trip_style import derive_scope as derive_style_scope

router = APIRouter(prefix="/trips", tags=["trips"])


class CoordinateIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


class DayOverrideIn(BaseModel):
    """Per-day tweak of `start_hour` / `daily_driving_cap_hours` for
    a single day in the multi-day plan. Set by the driver tapping an
    edit icon on a day header in ResultScreen.

    `day_index` is 1-based (day 1 = departure day). Values default to
    the profile-level equivalents when absent. Overrides ONLY apply
    to their own day — subsequent days revert to the profile defaults.
    """

    day_index: int = Field(ge=1, le=30)
    start_hour: int | None = Field(default=None, ge=4, le=14)
    daily_driving_cap_hours: int | None = Field(
        default=None, ge=4, le=14,
    )


class WaypointIn(BaseModel):
    """Intermediate stop with an explicit dwell time.

    `dwell_nights = 0` (default) preserves the historical
    behaviour: the router only routes THROUGH the coord as a via
    point. `dwell_nights >= 1` turns the waypoint into an anchor
    that forces the multi-day plan to bookend N days there and
    densifies hotels around it.

    Accepts a bare `{lat, lon}` object too — Pydantic coerces via
    the alias validator so callers on the previous request shape
    (mobile pre-dwell) still work.
    """

    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)
    dwell_nights: int = Field(default=0, ge=0, le=14)
    label: str | None = Field(default=None, max_length=512)


class VehicleIn(BaseModel):
    type: VehicleType = VehicleType.CAR
    fuel_type: FuelType = FuelType.PETROL
    consumption_l_per_100km: float = Field(default=6.5, gt=0, le=40)
    consumption_kwh_per_100km: float = Field(default=18.0, gt=0, le=80)
    fuel_tank_l: float = Field(default=50.0, gt=0, le=200)
    ev_range_km: float = Field(default=350.0, gt=0, le=1200)


class MealPreferencesIn(BaseModel):
    breakfast_hour: int = Field(default=8, ge=4, le=12)
    breakfast_minute: int = Field(default=0, ge=0, le=59)
    lunch_hour: int = Field(default=13, ge=11, le=16)
    lunch_minute: int = Field(default=0, ge=0, le=59)
    dinner_hour: int = Field(default=20, ge=17, le=23)
    dinner_minute: int = Field(default=0, ge=0, le=59)
    typical_stop_minutes: int = Field(default=45, ge=15, le=180)


class TripProfileIn(BaseModel):
    travellers: int = Field(default=1, ge=1, le=9)
    has_kids: bool = False
    has_pets: bool = False
    vehicle: VehicleIn = Field(default_factory=VehicleIn)
    meals: MealPreferencesIn = Field(default_factory=MealPreferencesIn)

    # -- Travel style --
    travel_pace: TravelPace = TravelPace.STEADY
    overnight_policy: OvernightPolicy = OvernightPolicy.IF_NEEDED
    daily_driving_cap_hours: int = Field(default=8, ge=4, le=14)
    bedtime_hour: int = Field(default=22, ge=18, le=23)
    wake_hour: int = Field(default=8, ge=5, le=11)
    # Optional. Independent from wake_hour — the driver may want to
    # wake at 07:00, drive at 07:30 and have breakfast at the first
    # service area. When null, backend falls back to wake_hour.
    preferred_driving_start_hour: int | None = Field(
        default=None, ge=4, le=14,
    )
    break_style: BreakStyle = BreakStyle.SCENIC

    # -- Curated vehicle catalogue (Phase 1: model + tank level) --
    # When `vehicle_model_id` matches an entry in
    # `app.data.vehicle_models` we override the manual sliders on
    # `vehicle` with the catalogue's tank size + consumption. Lets
    # the driver skip the "guess my consumption in L/100 km" step.
    # `current_tank_level_percent` (25 / 50 / 75 / 100) feeds
    # `refuel_window` in the plan response.
    vehicle_model_id: str | None = Field(default=None, max_length=128)
    current_tank_level_percent: int | None = Field(
        default=None,
        ge=0,
        le=100,
        description=(
            "Current fuel level as a percentage of tank capacity. "
            "Common values from the picker: 25, 50, 75, 100. Feeds "
            "the `refuel_window` hint in the response."
        ),
    )

    def to_domain(self) -> TripProfile:
        # Optional catalogue lookup for tank + consumption. Falls back
        # to the manual `vehicle` sliders when the id is unknown or
        # missing, so a broken/stale id doesn't break the plan.
        tank_l = self.vehicle.fuel_tank_l
        consumption = self.vehicle.consumption_l_per_100km
        if self.vehicle_model_id:
            from app.data.vehicle_models import find as _find_vehicle
            hit = _find_vehicle(self.vehicle_model_id)
            if hit is not None:
                tank_l = hit.tank_liters
                consumption = hit.consumption_l100km
        return TripProfile(
            travellers=self.travellers,
            has_kids=self.has_kids,
            has_pets=self.has_pets,
            vehicle=Vehicle(
                type=self.vehicle.type,
                fuel_type=self.vehicle.fuel_type,
                consumption_l_per_100km=consumption,
                consumption_kwh_per_100km=self.vehicle.consumption_kwh_per_100km,
                fuel_tank_l=tank_l,
                ev_range_km=self.vehicle.ev_range_km,
            ),
            meals=MealPreferences(
                breakfast_hour=self.meals.breakfast_hour,
                breakfast_minute=self.meals.breakfast_minute,
                lunch_hour=self.meals.lunch_hour,
                lunch_minute=self.meals.lunch_minute,
                dinner_hour=self.meals.dinner_hour,
                dinner_minute=self.meals.dinner_minute,
                typical_stop_minutes=self.meals.typical_stop_minutes,
            ),
            travel_pace=self.travel_pace,
            overnight_policy=self.overnight_policy,
            daily_driving_cap_hours=self.daily_driving_cap_hours,
            bedtime_hour=self.bedtime_hour,
            wake_hour=self.wake_hour,
            preferred_driving_start_hour=self.preferred_driving_start_hour,
            break_style=self.break_style,
        )


class TripPlanRequest(BaseModel):
    origin: CoordinateIn
    destination: CoordinateIn
    # Optional intermediate stops the router should visit in the
    # order given. Empty (default) = classic point-to-point trip.
    # Up to 8 waypoints — OSRM public demo has a soft limit of
    # 10 total coordinates; we cap at 8 stops + origin +
    # destination.
    waypoints: list[WaypointIn] = Field(default_factory=list, max_length=8)
    desired_departure_at: datetime
    countries: list[Country] | None = Field(
        default=None,
        description=(
            "Optional. If omitted, countries are auto-detected from the "
            "origin/destination coordinates using the launch-country "
            "bounding boxes."
        ),
    )
    hotel_max_detour_minutes: int | None = Field(
        default=None,
        ge=0,
        le=240,
        description=(
            "If set (0 = disabled, > 0 = enabled), search for hotels within "
            "this maximum round-trip detour off the route."
        ),
    )
    hotel_price_band: PriceBand | None = Field(
        default=None,
        description=(
            "Filter hotels by price band. Only applied when "
            "hotel_max_detour_minutes > 0. Legacy single-band field; "
            "prefer `hotel_price_bands` for multi-select."
        ),
    )
    hotel_price_bands: list[PriceBand] | None = Field(
        default=None,
        description=(
            "Multi-band price filter for hotels. If the list contains "
            "PriceBand.ANY or is empty, no filter is applied. Wins over "
            "`hotel_price_band` when set."
        ),
    )
    hotel_min_stars: int | None = Field(
        default=None,
        ge=1,
        le=5,
        description=(
            "Minimum OSM `stars` rating for surfaced hotels (1-5). "
            "When set, hotels lacking the tag are dropped — mappers "
            "often omit stars so the pool can shrink significantly."
        ),
    )
    hotel_include_other: bool = Field(
        default=False,
        description="Include guest houses, motels, apartments in addition to hotels.",
    )
    hotel_destination_radius_km: float | None = Field(
        default=None,
        ge=5.0,
        le=100.0,
        description=(
            "Extra search radius around the DESTINATION to widen "
            "the hotel pool when the corridor pass returned too "
            "few. Defaults to 40 km when omitted; users can push "
            "up to 100 km for rural destinations."
        ),
    )
    hotel_conditions: str | None = Field(
        default=None,
        description=(
            "Geoapify conditions for hotel search. Comma-separated "
            "(e.g. 'internet_access.free,dogs.yes'). Applied at query "
            "time, not post-filter."
        ),
    )
    restaurant_conditions: str | None = Field(
        default=None,
        description=(
            "Geoapify conditions for restaurant search. Comma-separated "
            "(e.g. 'vegetarian,gluten_free'). Applied at query time."
        ),
    )
    restaurant_max_detour_minutes: int | None = Field(
        default=None,
        ge=0,
        le=240,
        description=(
            "If set (0 = disabled, > 0 = enabled), search for restaurants "
            "within this maximum round-trip detour off the route."
        ),
    )
    restaurant_price_band: PriceBand | None = Field(
        default=None,
        description=(
            "Legacy single-band; prefer `restaurant_price_bands`."
        ),
    )
    restaurant_price_bands: list[PriceBand] | None = Field(
        default=None,
        description=(
            "Multi-band price filter for restaurants. `[ANY]` or empty "
            "means no filter."
        ),
    )
    restaurant_cuisines: list[str] | None = Field(
        default=None,
        description=(
            "Optional OSM `cuisine` tag whitelist (e.g. ['italian', "
            "'spanish', 'tapas']). Only restaurants tagged with at least "
            "one match are kept."
        ),
    )
    restaurant_exclude_origin_radius_km: float = Field(
        default=15.0,
        ge=0.0,
        le=100.0,
        description=(
            "Skip restaurants within this straight-line distance of the "
            "origin — a driver planning a trip doesn't need dining tips "
            "next door to their departure point."
        ),
    )
    include_adverse_events: bool = Field(
        default=False,
        description=(
            "If true, include known adverse events (fires, strikes, "
            "weather, roadworks, accidents, protests, floods, snow) "
            "along the route in the response."
        ),
    )
    adverse_events_max_distance_km: float = Field(
        default=12.0,
        gt=0.0,
        le=200.0,
        description=(
            "Maximum great-circle distance from the route for an event to "
            "be included. Only meaningful when include_adverse_events=true. "
            "Default (12 km) tuned for FIRMS fires — beyond that the smoke "
            "plume rarely affects the highway."
        ),
    )
    include_route_comparison: bool = Field(
        default=False,
        description=(
            "If true, compute two extra route variants (toll-free and "
            "scenic) alongside the fastest so the client can render a "
            "side-by-side comparison."
        ),
    )
    include_toll_alternative: bool = Field(
        default=False,
        description=(
            "If true, compute a second route with tolls avoided and "
            "include a side-by-side comparison (money saved vs. minutes "
            "added)."
        ),
    )
    include_hourly_toll_analysis: bool = Field(
        default=False,
        description=(
            "Premium. Given both routes, compute a 24-hour verdict "
            "table (skip tolls at these hours, keep them at those)."
        ),
    )
    include_parking: bool = Field(
        default=False,
        description=(
            "When true, the response ships a `parkings[]` list of "
            "options near the destination (5-10 sorted by distance)."
        ),
    )
    avoid_motorways: bool = Field(default=False)
    prefer_scenic: bool = Field(default=False)
    time_window_span_hours: int = Field(
        default=3,
        ge=1,
        le=12,
        description=(
            "Half-width in hours of the departure window to sample "
            "around the desired departure time. Default ±3h; the "
            "client can expand up to ±12h when the driver wants to "
            "see whether leaving much earlier / later saves more time."
        ),
    )
    time_window_top_n: int = Field(
        default=5,
        ge=3,
        le=24,
        description=(
            "How many candidate departure times to return, sorted by "
            "estimated duration ascending."
        ),
    )
    trip_profile: TripProfileIn | None = None

    # Per-day overrides for start_hour / driving_cap. Set by the
    # user tapping an edit icon on a day header in the ResultScreen
    # to say "on day 3 I want to leave at 10:00 and drive at most
    # 6 hours". Empty (default) means every day uses the profile
    # defaults. Backend loops through days by index; a matching
    # `day_index` here overrides that day only, subsequent days
    # revert to the profile defaults.
    day_overrides: list[DayOverrideIn] = Field(default_factory=list)

    # -- Garage (multi-vehicle) --
    # When set AND the caller is authenticated, the backend looks up
    # the entry in the user's garage and uses its `model_id` +
    # `default_tank_percent` for the refuel-window calc — overriding
    # the standalone `trip_profile.vehicle_model_id` for THIS trip
    # only. Falls through to `trip_profile.vehicle_model_id` when
    # the garage lookup fails (unknown id, anonymous user), so
    # older clients that never send this field keep working.
    garage_vehicle_id: str | None = Field(default=None, max_length=64)


class RouteOut(BaseModel):
    distance_km: float
    free_flow_minutes: float
    polyline: str
    toll_cost_eur: float
    countries_crossed: list[Country]
    geometry: list[list[float]] = Field(
        default_factory=list,
        description=(
            "Ordered [lon, lat] pairs following real roads. Empty when the "
            "backend falls back to the great-circle mock — in that case "
            "clients should render a straight line between origin and "
            "destination."
        ),
    )
    # Country-permit stickers (AT, CH, RO, HU, SK, CZ, SI, BG) —
    # mandatory whenever the route uses ANY motorway in that
    # country. Bundled into `toll_cost_eur` for backwards compat
    # but ALSO exposed here so the mobile can render "Peajes X €
    # + Viñetas Y € obligatorias" and never offer them as
    # skippable in the partial-toll UI. Empty → no vignette
    # country crossed OR HERE didn't classify one.
    vignette_cost_eur: float = 0.0
    vignette_countries: list[str] = Field(default_factory=list)


class TollAlternativeOut(BaseModel):
    distance_km: float
    duration_minutes: float
    toll_cost_eur: float
    savings_eur: float
    time_penalty_minutes: float
    extra_distance_km: float
    worth_it: bool
    geometry: list[list[float]] = Field(default_factory=list)


class PartialTollSkipOut(BaseModel):
    label: str
    kind: str = "named"
    index: int = 1
    total: int | None = None
    distance_from_origin_km: float
    savings_eur: float
    time_penalty_minutes: float
    extra_distance_km: float
    worth_it: bool
    lat: float
    lon: float
    # Polyline of the non-toll alternative route around this skip
    # (from HERE `avoid=tollRoad`, when the key is set). Encoded as
    # a flat list of [lon, lat] pairs — matches the existing mobile
    # `PartialTollSkip.detourGeometry` field so both the day-map
    # overlay AND the Google-Maps deep-link waypoint builder read
    # from one source of truth. Empty list → mobile just places
    # the pin without an alternate polyline.
    detour_geometry: list[list[float]] = Field(default_factory=list)


class IntraSectionSkipOut(BaseModel):
    section_name: str
    exit_gate_name: str
    exit_lat: float
    exit_lon: float
    reentry_gate_name: str
    reentry_lat: float
    reentry_lon: float
    full_section_eur: float
    bypass_eur: float
    savings_eur: float
    free_road_km: float
    time_penalty_minutes: float
    worth_it: bool


class FuelCostOut(BaseModel):
    total_cost_eur: float
    average_unit_price_eur: float
    fuel_type: FuelType
    fuel_units: float
    unit_label: str
    range_ok: bool
    notes: list[str] = Field(default_factory=list)


class MealStopOut(BaseModel):
    slot: MealSlot
    at: datetime
    distance_from_origin_km: float
    restaurant_name: str | None
    restaurant_price_eur_per_meal: float | None
    restaurant_lat: float | None
    restaurant_lon: float | None
    # Reverse-geocoded city near the meal stop coord. Shown in
    # the mobile row as "Cerca de X" so drivers know where the
    # stop actually is without opening a map.
    city_hint: str | None = None
    # The stop's actual GPS. Used by the mobile mini-map thumbnail.
    lat: float | None = None
    lon: float | None = None


class SleepStopOut(BaseModel):
    at: datetime
    distance_from_origin_km: float
    hotel_name: str | None
    hotel_price_eur_per_night: float | None
    hotel_lat: float | None
    hotel_lon: float | None
    city_hint: str | None = None
    lat: float | None = None
    lon: float | None = None


class OptimizationsOut(BaseModel):
    meal_stops: list[MealStopOut]
    sleep_stop: SleepStopOut | None
    fuel_cost: FuelCostOut


class HourlyTollVerdictOut(BaseModel):
    hour: int
    toll_route_minutes: float
    toll_free_route_minutes: float
    savings_eur: float
    recommendation: str


class HourlyTollReportOut(BaseModel):
    verdicts: list[HourlyTollVerdictOut]
    best_hours_to_skip: list[int]
    worst_hours_to_skip: list[int]


class TimeWindowOut(BaseModel):
    departure_at: datetime
    estimated_minutes: float
    traffic_factor: float
    recommended: bool


class FuelPriceOut(BaseModel):
    station_name: str
    country: Country
    price_eur_per_l: float
    price_available: bool = True
    # +€/L below the country median (cheap deal); -€/L means over
    # median. Absent when the median can't be computed (mock data,
    # single-station country). Mobile renders a green savings chip
    # when this is meaningfully positive.
    savings_vs_country_median_eur_per_l: float | None = None
    distance_from_origin_km: float
    lat: float | None = None
    lon: float | None = None
    attributes: dict[str, str] = Field(default_factory=dict)
    unit_label: str = "€/L"
    is_charging_station: bool = False


class FuelArbitrageOut(BaseModel):
    cheaper_country: Country
    cheaper_median_eur_per_l: float
    pricier_country: Country
    pricier_median_eur_per_l: float
    delta_eur_per_l: float
    estimated_tank_saving_eur: float


class DayPlanOut(BaseModel):
    day_index: int
    start_at: datetime
    end_at: datetime
    from_km: float
    to_km: float
    # Forward-declared: RestStopOut is defined below in the file.
    meal_stops: list["MealStopOut"] = Field(default_factory=list)
    rest_stops: list["RestStopOut"] = Field(default_factory=list)
    sleep_at: datetime | None = None
    # Approximate coord where the overnight stop lands. Clients use
    # this to rank hotels for the day's "sleep options" card.
    sleep_lat: float | None = None
    sleep_lon: float | None = None
    # Human-readable label when this day is anchored at a
    # user-picked dwell waypoint (e.g. "Mendrisio"). Mobile shows
    # this in the day header instead of the raw "km 267 → 267"
    # range that reads as nonsense for a stay-put day.
    dwell_label: str | None = None
    from_name: str | None = None
    to_name: str | None = None
    waypoint_labels: list[str] = Field(default_factory=list)
    waypoint_anchors: list["WaypointAnchorOut"] = Field(default_factory=list)


class WaypointAnchorOut(BaseModel):
    label: str
    km: float
    lat: float
    lon: float


class HotelOut(BaseModel):
    name: str
    country: Country
    price_eur_per_night: float
    price_band: PriceBand
    detour_minutes: float
    distance_from_route_km: float
    lat: float
    lon: float
    attributes: dict[str, str] = Field(default_factory=dict)


class RestaurantOut(BaseModel):
    name: str
    country: Country
    price_eur_per_meal: float
    price_band: PriceBand
    detour_minutes: float
    distance_from_route_km: float
    lat: float
    lon: float
    attributes: dict[str, str] = Field(default_factory=dict)
    # Which meal slot(s) this place typically covers. Mobile groups
    # restaurants under "Suggested for breakfast/lunch/dinner"
    # sections based on the intersection with the trip's clock window.
    open_meal_slots: list[MealSlot] = Field(default_factory=list)


class RestStopOut(BaseModel):
    distance_from_origin_km: float
    cumulative_driving_hours: float
    recommended_break_minutes: int
    lat: float
    lon: float
    # OSM-tag-derived amenity flags. Absent tag ⇒ `False`. Consumers
    # use these to filter (mobile "Solo familiar / mascota / RV")
    # and to render inline badges next to each stop.
    kid_friendly: bool = False
    pet_friendly: bool = False
    rv_friendly: bool = False
    # Closest amenity name matched via Overpass (e.g. "Área de servicio
    # Somosierra Norte"). Mobile falls back to a generic "parada"
    # label when null.
    name: str | None = None
    # Shape of the closest amenity — service_area / gas_station /
    # rest_area / caravan_site / parking / unknown. Mobile picks the
    # row icon from this value.
    stop_type: str = "unknown"
    # Short WHY string composed at pick time from the OSM flags +
    # profile prefs ("compatible con niños", "gasolinera 12 c/L más
    # barata que la media del día"). Null → mobile falls back to
    # generic reasons in the info sheet.
    reason: str | None = None


class AdverseEventOut(BaseModel):
    id: str
    type: AdverseEventType
    severity: AdverseEventSeverity
    source: str
    description: str
    reported_at: datetime
    expires_at: datetime
    lat: float
    lon: float
    country: Country | None


class RouteVariantOut(BaseModel):
    key: str
    label: str
    distance_km: float
    free_flow_minutes: float
    toll_cost_eur: float


class SavingsSummaryOut(BaseModel):
    """Money and time the user is expected to save by taking the plan
    the app is nudging them towards, vs. the choice they'd have made
    without it.
    """
    time_saved_minutes_vs_desired: float = Field(
        description=(
            "Minutes saved by taking the recommended departure window "
            "instead of the window closest to the desired time. Positive "
            "when the recommendation is faster. Zero when no better "
            "option was found."
        ),
    )
    money_saved_eur_vs_tolls: float = Field(
        default=0.0,
        description=(
            "Euros saved by taking the toll-free alternative when the "
            "heuristic flags it as worth it. Zero otherwise."
        ),
    )


class RecommendationScopeOut(BaseModel):
    """Which sections the client should surface for this trip.

    Derived server-side from the TripProfile's travel-style fields and
    the route duration. The client is trusted to hide sections when a
    flag is false, but the payload arrays (hotels / restaurants /
    rest_stops) are still populated so features like Favorites and the
    AI narrative keep working from the same response.
    """
    show_rest_stops: bool
    show_hotels: bool
    show_restaurants: bool
    requires_overnight: bool
    rest_stops_count_target: int
    arrival_after_bedtime: bool
    arrival_local_hour: int
    reason: str


def _issue_day_index(
    issue,
    days_out: list["DayPlanOut"],
) -> int | None:
    """Locate the day (1-based) an Issue belongs to by matching its
    context km against each day's `[from_km, to_km]` range. Returns
    None when the issue carries no km hint (e.g. fuel warnings) or
    when no day covers the km. Kept small so both plan endpoints can
    call it right after check_trip_consistency.
    """
    ctx = getattr(issue, "context", None)
    if not ctx:
        return None
    km = ctx.get("km") if isinstance(ctx, dict) else None
    if km is None:
        return None
    try:
        km_val = float(km)
    except (TypeError, ValueError):
        return None
    for d in days_out:
        if d.from_km <= km_val <= d.to_km + 0.001:
            return d.day_index
    return None


def _issue_to_out(
    issue,
    days_out: list["DayPlanOut"],
) -> "ConsistencyIssueOut":
    """Serialize an Issue into its wire model, attaching `day_index`
    and `context` so the mobile client can localize + inline the
    warning inside the matching day card."""
    return ConsistencyIssueOut(
        code=issue.code,
        severity=issue.severity.value,
        message=issue.message,
        context=(dict(issue.context) if issue.context else None),
        day_index=_issue_day_index(issue, days_out),
    )


class ConsistencyIssueOut(BaseModel):
    code: str
    severity: str
    message: str
    # Structured context so mobile clients can render a fully
    # localized message off `code` + these placeholders. Keys vary
    # per code (see `Issue.context` docstring in consistency.py).
    context: dict | None = None
    # 1-based itinerary day this issue anchors to. Populated for
    # meal / sleep codes after the days list is materialised so the
    # mobile client can inline the warning INTO the day card
    # instead of only rendering it in the global banner. Absent for
    # trip-wide codes (e.g. `fuel.no_stations_visible`).
    day_index: int | None = None


class WeatherSegmentOut(BaseModel):
    from_km: float
    to_km: float
    # English fallback — kept for backwards compat. Localised on the
    # client via `icon` (weather-family code) so the label doesn't
    # bake in the server locale.
    label: str
    icon: str
    temperature_c: float | None = None
    lat: float
    lon: float


class ParkingOutTrip(BaseModel):
    name: str
    lat: float
    lon: float
    country: str
    distance_from_destination_km: float
    price_eur_per_hour: float | None = None
    covered: bool | None = None
    capacity: int | None = None
    kind: str = "surface"
    kid_friendly: bool | None = None
    dogs_allowed: bool | None = None
    toilets: bool | None = None
    food_nearby: bool | None = None
    ev_charging: bool | None = None
    rv_friendly: bool | None = None


class RefuelWindowOut(BaseModel):
    """Distance-along-route milestones for the driver's next refuel.

    Populated only when the request's `trip_profile.vehicle_model_id`
    AND `current_tank_level_percent` are set. Absent otherwise so the
    mobile client can leave the chip hidden.

    When the current tank does NOT reach the destination we go one
    step further and pre-pick the CHEAPEST station within the window
    (`suggested_station`) plus the €-savings it earns over the route
    median (`suggested_savings_eur`). Both are optional so old clients
    keep working — they just render the chip without the "auto add"
    call-to-action.
    """
    usable_range_km: float
    comfortable_by_km: float
    must_by_km: float
    reaches_destination: bool
    suggested_station: FuelPriceOut | None = None
    suggested_savings_eur: float | None = None


class TripPlanResponse(BaseModel):
    route: RouteOut
    time_windows: list[TimeWindowOut]
    fuel_prices: list[FuelPriceOut]
    hotels: list[HotelOut]
    restaurants: list[RestaurantOut]
    parkings: list[ParkingOutTrip] = Field(default_factory=list)
    rest_stops: list[RestStopOut]
    adverse_events: list[AdverseEventOut]
    toll_alternative: TollAlternativeOut | None = None
    partial_toll_skips: list[PartialTollSkipOut] = Field(default_factory=list)
    intra_section_skips: list[IntraSectionSkipOut] = Field(default_factory=list)
    optimizations: OptimizationsOut | None = None
    hourly_toll_report: HourlyTollReportOut | None = None
    savings: SavingsSummaryOut = Field(default_factory=lambda: SavingsSummaryOut(
        time_saved_minutes_vs_desired=0.0, money_saved_eur_vs_tolls=0.0,
    ))
    route_variants: list[RouteVariantOut] = Field(default_factory=list)
    recommendation_scope: RecommendationScopeOut | None = None
    consistency_issues: list[ConsistencyIssueOut] = Field(default_factory=list)
    fuel_arbitrage: FuelArbitrageOut | None = None
    days: list[DayPlanOut] = Field(default_factory=list)
    weather_segments: list[WeatherSegmentOut] = Field(default_factory=list)
    refuel_window: RefuelWindowOut | None = None


def _providers() -> Providers:
    return get_providers()


# --- Progressive-plan compute pipeline ------------------------------
#
# The historic ``_plan_trip_impl`` did one monolithic pass and let the
# progressive endpoints slice the response server-side (the "shortcut"
# variant). This split it into four cooperating pieces so ``/plan/core``
# and ``/plan/enrich`` can run genuinely different amounts of work:
#
#   * ``_plan_shared_preamble`` — everything both slices need (route,
#     tollguru quote, time windows, rest stops, effective clock).
#   * ``_plan_core_impl`` — route + windows + day plan built from an
#     empty POI pool. Returns fast; no hotel/restaurant/weather calls.
#   * ``_plan_enrich_impl`` — every provider fan-out that turns a bare
#     day plan into the full trip screen (hotels, restaurants, fuel,
#     weather, adverse events, toll alternatives, parking, refuel).
#   * ``_merge_full`` — reassembles a merged response for the legacy
#     ``POST /plan`` endpoint so pre-progressive mobile clients keep
#     seeing the whole thing in one call.
#
# The three endpoints below each look up their own cache slot before
# spending any compute, so back-to-back retries stay cheap even after
# the shortcut merge went away.


@dataclass(frozen=True, slots=True)
class _Preamble:
    """Cheap-to-compute inputs shared by core + enrich compute paths.

    Built once per request by :func:`_plan_shared_preamble` and handed
    to both :func:`_plan_core_impl` and :func:`_plan_enrich_impl`. The
    two slices need the same route, tollguru quote and time windows —
    computing them twice would double every request's provider load.
    """

    origin: Coordinate
    destination: Coordinate
    waypoints: tuple[Coordinate, ...]
    dwell_waypoints: tuple[Waypoint, ...]
    countries_override: tuple[Country, ...] | None
    profile: TripProfile | None
    # Route with tollguru's real toll cost folded in when the quote
    # succeeded; otherwise the routing provider's estimate is left
    # untouched.
    route: Route
    # Empty tuple when tollguru returned nothing — kept as a tuple
    # (never None) so downstream call sites don't have to guard.
    real_tolls: tuple
    route_hash: str
    # Unenriched rest stops (compute_rest_stops output). Enrich adds
    # Overpass amenity flags on top; core ships an empty list on the
    # wire because the client doesn't render rest stops from /core.
    rest_stops_domain: tuple
    windows: tuple
    effective_departure_at: datetime
    effective_arrival_at: datetime


async def _plan_shared_preamble(
    payload: TripPlanRequest,
    providers: Providers,
) -> _Preamble:
    """Build the shared inputs both compute paths need.

    Routing runs first because everything else depends on the route
    geometry. Tollguru + time_windows then run in parallel so the
    combined preamble stays under ~3 s even on a Paris → Rome trip
    where each of the two adds ~1.5 s on its own.
    """

    origin = Coordinate(lat=payload.origin.lat, lon=payload.origin.lon)
    destination = Coordinate(
        lat=payload.destination.lat, lon=payload.destination.lon,
    )
    waypoints = tuple(
        Coordinate(lat=w.lat, lon=w.lon) for w in payload.waypoints
    )
    # Full waypoint list (including dwell metadata) — the routing
    # provider only needs coords, but downstream services
    # (day_plan, hotel densification) need dwell_nights + label.
    dwell_waypoints = tuple(
        Waypoint(
            coordinate=Coordinate(lat=w.lat, lon=w.lon),
            dwell_nights=w.dwell_nights,
            label=w.label,
        )
        for w in payload.waypoints
    )
    countries_override = (
        tuple(payload.countries) if payload.countries else None
    )
    profile = payload.trip_profile.to_domain() if payload.trip_profile else None

    route = await providers.routing.route(
        origin, destination, countries_override,
        waypoints=waypoints,
        avoid_motorways=payload.avoid_motorways,
        prefer_scenic=payload.prefer_scenic,
    )

    # Toll pricing and time windows are independent post-route — run
    # them concurrently to keep the preamble short.
    _tolls_coro = (
        providers.tollguru.quote(route)
        if providers.tollguru is not None and route.geometry
        else asyncio.sleep(0, result=None)
    )
    _windows_coro = compute_time_windows(
        route=route,
        desired_departure_at=payload.desired_departure_at,
        traffic=providers.traffic,
        config=TimeWindowConfig(
            window_span=timedelta(hours=payload.time_window_span_hours),
            top_n=payload.time_window_top_n,
        ),
    )
    _quote, windows = await asyncio.gather(_tolls_coro, _windows_coro)
    real_tolls: tuple = ()
    if _quote is not None:
        real_tolls = tuple(_quote.tolls)
        route = _dc_replace(route, toll_cost_eur=round(_quote.total_eur, 2))

    # Rest stops are cheap and both slices need them — enrich enriches
    # further, core ships them as empty on the wire but the day plan
    # still uses the unenriched coords to slice into per-day buckets.
    rest_stops_domain = compute_rest_stops(route, profile=profile)

    # Effective departure: ALWAYS the user's picked time. Previously
    # this defaulted to `windows[0].departure_at` (the fastest
    # sample), which meant a driver with profile preferred_driving_
    # start_hour=10:00 saw their whole plan built around a 05:30
    # departure just because 05:30 happened to be the fastest slot.
    # The recommended window is still surfaced under `time_windows`
    # so the user can opt in explicitly with one tap (mobile fires
    # `_replanWithDeparture` on tap). Anchor drives BOTH
    # `compute_optimizations` (meal / sleep clocks) AND the
    # consistency check (arrival timestamp); they stay in sync
    # because they both consume `effective_departure_at`.
    effective_departure_at = payload.desired_departure_at
    # Pace-dependent pause overhead — same table as
    # `trip_optimizations._PAUSE_RATIO_BY_PACE`. Kept inline here so
    # the check can compute an accurate arrival even before `opt` is
    # built (opt is gated on `profile is not None` but the check
    # itself must run either way).
    _pause_ratio_by_pace = {
        "push": 0.04, "steady": 0.10, "savour": 0.17,
    }
    _pace_value = (
        profile.travel_pace.value if profile is not None else "steady"
    )
    _pause_ratio = _pause_ratio_by_pace.get(_pace_value, 0.10)
    # Multi-day-aware arrival: single-day trips are just
    # `dep + wall_hours(trip)`. Multi-day trips have to fold in
    # ~13 h of overnight rest at the end of each intermediate day
    # (from sleep to wake_hour of the next day). Without this the
    # consistency check falsely fires "breakfast at Thu 08:00 but
    # trip ends at Thu 07:35" for Day 2+ meals — the check thought
    # the trip was continuous.
    # OSRM's `free_flow_duration` uses posted speed limits and knows
    # nothing about real traffic, rush hour, border crossings, fuel
    # stops, urban approach slowdowns, or the driver stopping to
    # actually enjoy the country they're driving through. Users kept
    # reporting arrivals landing an hour early on 6+ h trips because
    # of this optimism. A flat 1.15 multiplier bakes in the average
    # gap we measured against Google Maps ETAs across ES/FR/IT/DE
    # (median +14 %, p90 +22 %). Cheap, universal, no per-route
    # calibration. Premium can later swap this for hourly speed
    # profiles per European bbox.
    _REALISM_FACTOR = 1.15
    _trip_hours = (
        route.free_flow_duration.total_seconds() / 3600.0
    ) * _REALISM_FACTOR
    _cap_hours = float(
        getattr(profile, "daily_driving_cap_hours", 8) or 8,
    ) if profile is not None else 24.0
    # Prefer `preferred_driving_start_hour` when set — the arrival
    # estimate has to match what `trip_optimizations` actually does
    # or the consistency check falsely fires "breakfast at Thu 08:00
    # but trip ends at Thu 07:35".
    _wake_hour = 0
    if profile is not None:
        _wake_hour = (
            getattr(profile, "preferred_driving_start_hour", None)
            or getattr(profile, "wake_hour", 8)
        )
    _day_start = effective_departure_at
    _remaining = _trip_hours
    _day_end = effective_departure_at
    while _remaining > 0.01:
        _drive = min(_cap_hours, _remaining)
        _day_end = _day_start + timedelta(
            hours=_drive * (1.0 + _pause_ratio),
        )
        _remaining -= _drive
        if _remaining <= 0.01:
            break
        # Wake next day at wake_hour; fall through when no profile.
        _next_wake_at = _day_end.replace(
            hour=_wake_hour, minute=0, second=0, microsecond=0,
        )
        if _next_wake_at <= _day_end:
            _next_wake_at += timedelta(days=1)
        _day_start = _next_wake_at
    effective_arrival_at = _day_end

    # Route hash keys the shared caches downstream services keep
    # (weather forecast, geocoding) so multiple slice computes on the
    # same route stay warm.
    _hash_seed = (route.polyline or "").encode("utf-8")
    if not _hash_seed:
        _hash_seed = repr(tuple(
            (round(c.lat, 5), round(c.lon, 5)) for c in route.geometry
        )).encode("utf-8")
    route_hash = hashlib.sha256(_hash_seed).hexdigest()

    return _Preamble(
        origin=origin,
        destination=destination,
        waypoints=waypoints,
        dwell_waypoints=dwell_waypoints,
        countries_override=countries_override,
        profile=profile,
        route=route,
        real_tolls=real_tolls,
        route_hash=route_hash,
        rest_stops_domain=tuple(rest_stops_domain),
        windows=tuple(windows),
        effective_departure_at=effective_departure_at,
        effective_arrival_at=effective_arrival_at,
    )


def _enforce_premium_gates(
    payload: TripPlanRequest, premium: bool,
) -> None:
    """Raise 402 for any premium-only feature toggled on by a free user.

    Called by every endpoint BEFORE the cache lookup so a cached
    response from an earlier premium request can never bypass the
    gate for a subsequent free-tier caller with the same payload.
    """

    if payload.include_hourly_toll_analysis and not premium:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": "premium_required",
                "message": (
                    "Hourly toll analysis is a Premium feature. "
                    "Upgrade to enable it."
                ),
            },
        )


_VIGNETTE_OP_COUNTRY_HINTS: dict[str, str] = {
    "austria": "AT", "österreich": "AT",
    "switzerland": "CH", "swiss": "CH", "schweiz": "CH",
    "romania": "RO", "rovinieta": "RO",
    "hungary": "HU", "matrica": "HU",
    "slovakia": "SK", "slovak": "SK",
    "czech": "CZ", "czechia": "CZ",
    "slovenia": "SI",
    "bulgaria": "BG",
}


def _guess_country_from_operator(operator: str) -> str:
    """Extract a 2-letter country code from HERE's `tollSystem`
    operator string when it matches a known vignette-country name
    fragment. Returns "" when nothing matches — caller filters."""
    if not operator:
        return ""
    op = operator.lower()
    for needle, code in _VIGNETTE_OP_COUNTRY_HINTS.items():
        if needle in op:
            return code
    return ""


def _empty_route() -> RouteOut:
    """Canonical empty RouteOut for the enrich-slice wire payload."""

    return RouteOut(
        distance_km=0.0,
        free_flow_minutes=0.0,
        polyline="",
        toll_cost_eur=0.0,
        countries_crossed=[],
        geometry=[],
    )


def _fuel_type_value(profile: TripProfile | None) -> str | None:
    """Best-effort read of the profile's fuel-type value.

    Used by the fuel provider to dispatch to charging stations for
    ELECTRIC vehicles vs. gasoline for the default case.
    """

    if profile is None or profile.vehicle is None:
        return None
    ft = getattr(profile.vehicle, "fuel_type", None)
    return ft.value if ft is not None else None


async def _plan_core_impl(
    payload: TripPlanRequest,
    providers: Providers,
    premium: bool,
    user: AuthUser | None,
    preamble: _Preamble,
) -> TripPlanResponse:
    """Fast compute path — route + days + savings + windows.

    This is what the mobile ``ResultScreen`` needs to render the map,
    hero card, and the day tabs immediately. It runs zero enrich
    providers (no hotel search, no restaurant fan-out, no weather
    fetch), and reuses the shared preamble the enrich path also
    consumes so the two never redo the routing / tollguru work.

    Fuel cost is a placeholder built from the vehicle profile + a
    default 1.75 €/L median (``estimate_fuel`` falls back to that
    when handed an empty price tuple). Enrich replaces this with the
    real per-country median once the fuel provider has run.
    """

    del user  # Not needed for core — kept in the signature for parity.

    route = preamble.route
    profile = preamble.profile
    rest_stops_domain = preamble.rest_stops_domain
    windows = preamble.windows
    effective_departure_at = preamble.effective_departure_at
    effective_arrival_at = preamble.effective_arrival_at

    # Trip-style scope: which sections the client should surface. Only
    # computed when the caller passes a profile — else the response's
    # `recommendation_scope` stays null and the client renders the
    # legacy "show everything" behaviour.
    scope_out: RecommendationScopeOut | None = None
    if profile is not None:
        scope = derive_style_scope(
            profile=profile,
            route=route,
            desired_departure_at=payload.desired_departure_at,
        )
        scope_out = RecommendationScopeOut(
            show_rest_stops=scope.show_rest_stops,
            show_hotels=scope.show_hotels,
            show_restaurants=scope.show_restaurants,
            requires_overnight=scope.requires_overnight,
            rest_stops_count_target=scope.rest_stops_count_target,
            arrival_after_bedtime=scope.arrival_after_bedtime,
            arrival_local_hour=scope.arrival_local_hour,
            reason=scope.reason,
        )

    # Basic optimizations — empty hotel + restaurant pool so no
    # provider work happens. Meal-stop generation still runs when the
    # user opted in, but every stop lands with ``restaurant=None``.
    optimizations_out: OptimizationsOut | None = None
    opt_domain = None
    fuel_cost_domain = None
    if profile is not None:
        include_meal_stops = bool(
            payload.restaurant_max_detour_minutes
            and payload.restaurant_max_detour_minutes > 0
        )
        opt = compute_optimizations(
            departure_at=effective_departure_at,
            trip_duration_hours=(
                route.free_flow_duration.total_seconds() / 3600.0
            ),
            rest_stops=rest_stops_domain,
            restaurants_by_slot={},
            hotels=(),
            profile=profile,
            include_meal_stops=include_meal_stops,
            day_overrides=_day_overrides_map(payload),
        )
        opt_domain = opt
        # Placeholder fuel cost — real one is computed in enrich. Falls
        # back to a hard-coded 1.75 €/L default inside ``estimate_fuel``
        # when the price tuple is empty.
        cost = estimate_fuel(route, profile.vehicle, ())
        fuel_cost_domain = cost
        optimizations_out = OptimizationsOut(
            meal_stops=[
                MealStopOut(
                    slot=m.slot,
                    at=m.at,
                    distance_from_origin_km=m.rest_stop.distance_from_origin_km,
                    restaurant_name=None,
                    restaurant_price_eur_per_meal=None,
                    restaurant_lat=None,
                    restaurant_lon=None,
                    city_hint=None,
                    lat=m.rest_stop.coordinate.lat,
                    lon=m.rest_stop.coordinate.lon,
                )
                for m in opt.meal_stops
            ],
            sleep_stop=(
                SleepStopOut(
                    at=opt.sleep_stop.at,
                    distance_from_origin_km=(
                        opt.sleep_stop.rest_stop.distance_from_origin_km
                    ),
                    hotel_name=None,
                    hotel_price_eur_per_night=None,
                    hotel_lat=None,
                    hotel_lon=None,
                    city_hint=None,
                    lat=opt.sleep_stop.rest_stop.coordinate.lat,
                    lon=opt.sleep_stop.rest_stop.coordinate.lon,
                )
                if opt.sleep_stop is not None else None
            ),
            fuel_cost=FuelCostOut(
                total_cost_eur=cost.total_cost_eur,
                average_unit_price_eur=cost.average_unit_price_eur,
                fuel_type=cost.fuel_type,
                fuel_units=cost.fuel_units,
                unit_label=cost.unit_label,
                range_ok=cost.range_ok,
                notes=list(cost.notes),
            ),
        )

    # Day plan — same helper as before but seeded with the *basic*
    # opt (no real hotels/restaurants). ``from_name`` / ``to_name`` /
    # ``city_hint`` are all left None here because the reverse-geocode
    # pass lives in enrich.
    days_out: list[DayPlanOut] = []
    if profile is not None:
        multiday = compute_day_plan(
            departure_at=effective_departure_at,
            trip_duration_hours=(
                route.free_flow_duration.total_seconds() / 3600.0
            ),
            profile=profile,
            optimizations=opt_domain,
            rest_stops=rest_stops_domain,
            route_distance_km=route.distance_km,
            route=route,
            waypoints=preamble.dwell_waypoints,
            day_overrides=_day_overrides_map(payload),
        )
        if multiday is not None:
            for d in multiday.days:
                days_out.append(
                    DayPlanOut(
                        day_index=d.day_index,
                        start_at=d.start_at,
                        end_at=d.end_at,
                        from_km=d.from_km,
                        to_km=d.to_km,
                        meal_stops=[
                            MealStopOut(
                                slot=m.slot,
                                at=m.at,
                                distance_from_origin_km=(
                                    m.rest_stop.distance_from_origin_km
                                ),
                                restaurant_name=None,
                                restaurant_price_eur_per_meal=None,
                                restaurant_lat=None,
                                restaurant_lon=None,
                                city_hint=None,
                                lat=m.rest_stop.coordinate.lat,
                                lon=m.rest_stop.coordinate.lon,
                            )
                            for m in d.meal_stops
                        ],
                        # Core ships an empty rest_stops per-day too —
                        # enrich re-computes with amenity flags and the
                        # merge picks those up for /plan legacy.
                        rest_stops=[],
                        sleep_at=d.sleep_at,
                        sleep_lat=(
                            d.sleep_coord.lat if d.sleep_coord else None
                        ),
                        sleep_lon=(
                            d.sleep_coord.lon if d.sleep_coord else None
                        ),
                        dwell_label=d.dwell_label,
                        from_name=None,
                        to_name=None,
                        waypoint_labels=list(d.waypoint_labels),
                        waypoint_anchors=[
                            WaypointAnchorOut(
                                label=a.label, km=a.km,
                                lat=a.lat, lon=a.lon,
                            )
                            for a in d.waypoint_anchors
                        ],
                    )
                )

    savings = SavingsSummaryOut(
        time_saved_minutes_vs_desired=minutes_saved_vs_desired(
            windows, payload.desired_departure_at,
        ),
        money_saved_eur_vs_tolls=0.0,
    )

    consistency_out = [
        _issue_to_out(i, days_out)
        for i in check_trip_consistency(
            departure_at=effective_departure_at,
            arrival_at=effective_arrival_at,
            optimizations=opt_domain,
            route=route,
            fuel_cost=fuel_cost_domain,
            fuel_prices=(),
            # Core phase doesn't run fuel providers yet — mark data
            # as unavailable so the "no stations visible" warning
            # doesn't fire prematurely (fuel data lives in enrich).
            fuel_data_available=False,
        )
    ]

    simplified = simplify_polyline(route.geometry, epsilon_km=0.2)
    # Split the toll figure into skippable-booth toll cost vs
    # country vignettes so the mobile can render them as separate
    # lines and never offer a "skip this" affordance for a vignette.
    _vignette_cost = round(
        sum(t.cost_eur for t in preamble.real_tolls if t.is_vignette),
        2,
    )
    # Country hint: extract the last capitalised token of each
    # vignette booth's `operator` field. HERE stamps it as e.g.
    # "Autobahn Vignette (Austria)" or "Rovinieta". Best-effort —
    # falls back to empty list when nothing parseable.
    _vignette_countries = sorted({
        _guess_country_from_operator(t.operator)
        for t in preamble.real_tolls if t.is_vignette
    } - {""})
    return TripPlanResponse(
        route=RouteOut(
            distance_km=route.distance_km,
            free_flow_minutes=_minutes(route.free_flow_duration),
            polyline=route.polyline,
            toll_cost_eur=route.toll_cost_eur,
            countries_crossed=list(route.countries_crossed),
            geometry=[[c.lon, c.lat] for c in simplified],
            vignette_cost_eur=_vignette_cost,
            vignette_countries=_vignette_countries,
        ),
        time_windows=[
            TimeWindowOut(
                departure_at=w.departure_at,
                estimated_minutes=_minutes(w.estimated_duration),
                traffic_factor=w.traffic_factor,
                recommended=w.recommended,
            )
            for w in windows
        ],
        fuel_prices=[],
        hotels=[],
        restaurants=[],
        parkings=[],
        rest_stops=[],
        adverse_events=[],
        toll_alternative=None,
        partial_toll_skips=[],
        intra_section_skips=[],
        optimizations=optimizations_out,
        hourly_toll_report=None,
        savings=savings,
        route_variants=[],
        recommendation_scope=scope_out,
        consistency_issues=consistency_out,
        fuel_arbitrage=None,
        days=days_out,
        weather_segments=[],
        refuel_window=None,
    )


async def _plan_enrich_impl(
    payload: TripPlanRequest,
    providers: Providers,
    premium: bool,
    user: AuthUser | None,
    preamble: _Preamble,
) -> TripPlanResponse:
    """Slow compute path — every provider fan-out core skipped.

    Runs the hotel + restaurant corridor pass, Google/HERE enrichment,
    fuel prices, adverse events, weather forecast, toll alternatives,
    parking, and route variants. Also re-computes the optimizations
    and day plan with the real POI pool so ``/plan`` legacy sees the
    populated version and ``/plan/enrich`` HTTP layer can clear the
    core-owned duplicates on its way out.
    """

    # Premium gate is also enforced at the endpoint layer BEFORE the
    # cache lookup — kept here as a safety net in case a future caller
    # invokes this function directly without going through the router.
    _enforce_premium_gates(payload, premium)

    route = preamble.route
    profile = preamble.profile
    origin = preamble.origin
    destination = preamble.destination
    dwell_waypoints = preamble.dwell_waypoints
    real_tolls = preamble.real_tolls
    effective_departure_at = preamble.effective_departure_at
    effective_arrival_at = preamble.effective_arrival_at

    # ---- Rest stops (with Overpass amenity flags) -------------------
    rest_stops_domain = preamble.rest_stops_domain
    try:
        from app.services.rest_stops_enrichment import enrich_rest_stops
        rest_stops_domain = tuple(
            await enrich_rest_stops(rest_stops_domain, profile=profile)
        )
    except Exception as exc:  # noqa: BLE001
        _log.warning("rest-stop enrichment failed: %r", exc)

    rest_stops_out = [
        RestStopOut(
            distance_from_origin_km=s.distance_from_origin_km,
            cumulative_driving_hours=s.cumulative_driving_hours,
            recommended_break_minutes=s.recommended_break_minutes,
            lat=s.coordinate.lat,
            lon=s.coordinate.lon,
            kid_friendly=s.kid_friendly,
            pet_friendly=s.pet_friendly,
            rv_friendly=s.rv_friendly,
            name=s.name,
            stop_type=s.stop_type.value if s.stop_type else "unknown",
            reason=_reason_for_rest_stop(s, profile),
        )
        for s in rest_stops_domain
    ]

    # ---- Effective hotel detour ------------------------------------
    effective_hotel_detour = payload.hotel_max_detour_minutes
    scope_reqs_overnight = False
    if profile is not None:
        try:
            _scope = derive_style_scope(
                profile=profile,
                route=route,
                desired_departure_at=payload.desired_departure_at,
            )
            scope_reqs_overnight = _scope.requires_overnight
        except Exception:  # noqa: BLE001
            scope_reqs_overnight = False
    if (not effective_hotel_detour or effective_hotel_detour <= 0) and \
            scope_reqs_overnight:
        effective_hotel_detour = 25

    # ---- Parallel provider fan-out ---------------------------------
    #
    # Every enrich provider that doesn't depend on another's result is
    # fired concurrently here. Post-gather we still do the sequential
    # bits that need the alt route or the hotel/restaurant pool.
    #
    # Every leaf coroutine below is wrapped in `_bounded_provider` so
    # a single slow / hung provider can never block the whole gather
    # past its own budget. On timeout the provider degrades to its
    # empty fallback and the plan ships with partial enrichment
    # instead of returning 500 or blocking the mobile client past
    # its 120 s cap. Numbers tuned so the sum of individual budgets
    # comfortably fits inside the client timeout even in pathological
    # cases where every provider hits its ceiling in parallel.

    # Per-provider wall-clock budgets. Hotels + restaurants get the
    # largest slice because they fan out over corridor chunks
    # (Geoapify's own internal budget is 45 s after 2026-09-28 fix
    # for multi-country trips; give the outer wrapper a small buffer
    # so it fires AFTER the inner one and we return partial data
    # instead of nothing). Fuel is `HybridFuelProvider` (gov feeds
    # for ES/FR/IT + HERE fallback in series) so it needs the same
    # headroom on trips that touch several country boundaries.
    _HOTELS_BUDGET_S = 50.0
    _RESTAURANTS_BUDGET_S = 50.0
    _FUEL_BUDGET_S = 50.0  # Hybrid: gov + HERE + Nominatim in series
    _ADVERSE_BUDGET_S = 15.0
    _WEATHER_BUDGET_S = 15.0
    _ALT_ROUTE_BUDGET_S = 20.0
    _PARKING_BUDGET_S = 10.0
    _VARIANTS_BUDGET_S = 25.0

    async def _bounded_provider(coro, *, budget_s: float, label: str, fallback):
        try:
            return await asyncio.wait_for(coro, timeout=budget_s)
        except asyncio.TimeoutError:
            _log.warning(
                "%s exceeded %.0fs budget; degrading to empty",
                label, budget_s,
            )
            return fallback

    async def _fetch_hotels_along() -> tuple:
        if not effective_hotel_detour or effective_hotel_detour <= 0:
            return ()
        kwargs: dict = {}
        if payload.hotel_include_other:
            kwargs["include_other"] = True
        if payload.hotel_conditions:
            kwargs["conditions"] = payload.hotel_conditions
        try:
            try:
                return await providers.hotels.hotels_along(route, **kwargs)
            except TypeError:
                return await providers.hotels.hotels_along(route)
        except Exception as exc:  # noqa: BLE001
            _log.warning("hotels_along failed: %r", exc)
            return ()

    async def _fetch_restaurants_along() -> tuple:
        if not (
            payload.restaurant_max_detour_minutes
            and payload.restaurant_max_detour_minutes > 0
        ):
            return ()
        kwargs: dict = {}
        if payload.restaurant_conditions:
            kwargs["conditions"] = payload.restaurant_conditions
        try:
            try:
                return await providers.restaurants.restaurants_along(
                    route, **kwargs,
                )
            except TypeError:
                return await providers.restaurants.restaurants_along(route)
        except Exception as exc:  # noqa: BLE001
            _log.warning("restaurants_along failed: %r", exc)
            return ()

    async def _fetch_fuel_along() -> tuple:
        try:
            return await providers.fuel.prices_along(
                route, fuel_type=_fuel_type_value(profile),
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("fuel prices_along failed: %r", exc)
            return ()

    async def _fetch_adverse() -> tuple:
        if not payload.include_adverse_events:
            return ()
        try:
            now = datetime.now(timezone.utc)
            return await providers.adverse_events.events_along(route, now=now)
        except Exception as exc:  # noqa: BLE001
            _log.warning("adverse events_along failed: %r", exc)
            return ()

    async def _fetch_weather() -> tuple:
        from app.services.weather_summary import weather_along_route
        try:
            return tuple(await weather_along_route(
                route, effective_departure_at,
            ))
        except Exception:  # noqa: BLE001
            return ()

    async def _fetch_alt_route():
        if not (
            payload.include_toll_alternative
            or payload.include_hourly_toll_analysis
        ) or route.toll_cost_eur <= 0:
            return None
        try:
            return await providers.routing.route(
                origin, destination, route.countries_crossed,
                avoid_tolls=True,
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("toll_alternative routing failed: %r", exc)
            return None

    async def _fetch_parking() -> list:
        if not payload.include_parking:
            return []
        try:
            from app.providers.parking import GeoapifyParkingProvider
            parking_provider = GeoapifyParkingProvider()
            dest_coord = Coordinate(
                lat=payload.destination.lat,
                lon=payload.destination.lon,
            )
            hits = await parking_provider.parking_near(
                dest_coord, radius_km=2.5,
            )
            return list(hits)[:10]
        except Exception as exc:  # noqa: BLE001
            _log.warning("Parking search failed: %r", exc)
            return []

    async def _fetch_variants() -> tuple:
        if not payload.include_route_comparison:
            return ()
        try:
            return tuple(await compute_variants(
                provider=providers.routing, primary=route,
                origin=origin, destination=destination,
                countries=route.countries_crossed,
            ))
        except Exception as exc:  # noqa: BLE001
            _log.warning("route_variants failed: %r", exc)
            return ()

    (
        hotels_raw,
        restaurants_raw,
        fuel_raw,
        adverse_raw,
        weather_raw,
        alt_route_domain,
        parkings_raw,
        variants_raw,
    ) = await asyncio.gather(
        _bounded_provider(
            _fetch_hotels_along(),
            budget_s=_HOTELS_BUDGET_S, label="hotels_along", fallback=(),
        ),
        _bounded_provider(
            _fetch_restaurants_along(),
            budget_s=_RESTAURANTS_BUDGET_S,
            label="restaurants_along", fallback=(),
        ),
        _bounded_provider(
            _fetch_fuel_along(),
            budget_s=_FUEL_BUDGET_S, label="fuel prices_along", fallback=(),
        ),
        _bounded_provider(
            _fetch_adverse(),
            budget_s=_ADVERSE_BUDGET_S, label="adverse events_along",
            fallback=(),
        ),
        _bounded_provider(
            _fetch_weather(),
            budget_s=_WEATHER_BUDGET_S, label="weather_along_route",
            fallback=(),
        ),
        _bounded_provider(
            _fetch_alt_route(),
            budget_s=_ALT_ROUTE_BUDGET_S, label="toll_alternative routing",
            fallback=None,
        ),
        _bounded_provider(
            _fetch_parking(),
            budget_s=_PARKING_BUDGET_S, label="parking_near", fallback=[],
        ),
        _bounded_provider(
            _fetch_variants(),
            budget_s=_VARIANTS_BUDGET_S, label="route_variants", fallback=(),
        ),
    )

    fuel: tuple = tuple(fuel_raw)

    # ---- Hotel filter + Google/HERE enrichment ---------------------
    hotels_out: list[HotelOut] = []
    all_hotels_cache = hotels_raw
    if effective_hotel_detour and effective_hotel_detour > 0 and hotels_raw:
        filtered = filter_hotels(
            all_hotels_cache,
            max_detour_minutes=float(effective_hotel_detour),
            price_band=payload.hotel_price_band or PriceBand.ANY,
            price_bands=payload.hotel_price_bands,
            profile=profile,
            min_stars=payload.hotel_min_stars,
        )
        try:
            _h_enricher = GooglePlacesEnricher()
            _h_head, _h_tail = filtered[:30], filtered[30:]
            _h_enriched = await _h_enricher.enrich_hotels(tuple(_h_head))
            filtered = tuple(_h_enriched) + tuple(_h_tail)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Google Places hotel enrichment failed: %r", exc)
        try:
            _here_enricher = HerePlacesEnricher()
            _h_head, _h_tail = filtered[:30], filtered[30:]
            _h_enriched = await _here_enricher.enrich_hotels(tuple(_h_head))
            filtered = tuple(_h_enriched) + tuple(_h_tail)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE Places hotel enrichment failed: %r", exc)
        hotels_out = [
            HotelOut(
                name=h.name,
                country=h.country,
                price_eur_per_night=h.price_eur_per_night,
                price_band=h.price_band,
                detour_minutes=h.detour_minutes,
                distance_from_route_km=h.distance_from_route_km,
                lat=h.coordinate.lat,
                lon=h.coordinate.lon,
                attributes=dict(h.attributes),
            )
            for h in filtered
        ]

    # ---- Restaurant filter + Google enrichment ---------------------
    restaurants_out: list[RestaurantOut] = []
    all_restaurants_cache = restaurants_raw
    if (
        payload.restaurant_max_detour_minutes
        and payload.restaurant_max_detour_minutes > 0
        and restaurants_raw
    ):
        filtered_r = filter_restaurants(
            all_restaurants_cache,
            max_detour_minutes=float(payload.restaurant_max_detour_minutes),
            price_band=payload.restaurant_price_band or PriceBand.ANY,
            price_bands=payload.restaurant_price_bands,
            cuisines=payload.restaurant_cuisines,
            origin=origin,
            exclude_origin_radius_km=payload.restaurant_exclude_origin_radius_km,
            profile=profile,
        )
        try:
            enricher = GooglePlacesEnricher()
            head, tail = filtered_r[:30], filtered_r[30:]
            enriched_head = await enricher.enrich_restaurants(tuple(head))
            filtered_r = tuple(enriched_head) + tuple(tail)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Google Places enrichment failed: %r", exc)
        restaurants_out = [
            RestaurantOut(
                name=r.name,
                country=r.country,
                price_eur_per_meal=r.price_eur_per_meal,
                price_band=r.price_band,
                detour_minutes=r.detour_minutes,
                distance_from_route_km=r.distance_from_route_km,
                lat=r.coordinate.lat,
                lon=r.coordinate.lon,
                attributes=dict(r.attributes),
                open_meal_slots=list(r.open_meal_slots),
            )
            for r in filtered_r
        ]

    # ---- Toll alternative + partial/intra skips + hourly report ----
    toll_alternative_out: TollAlternativeOut | None = None
    partial_skips_out: list[PartialTollSkipOut] = []
    if payload.include_toll_alternative and route.toll_cost_eur > 0:
        raw_skips = compute_partial_skips(route, real_tolls=real_tolls)
        # Upgrade the heuristic penalty / extra_km numbers to REAL
        # figures from HERE Routing v8 (avoid=tollRoad) and attach
        # the alternative polyline so the mobile day map can draw
        # the detour. Silently degrades to the heuristic values
        # when the HERE key is missing or a request fails.
        try:
            from app.providers.here_toll_alternatives import (
                enrich_skips_with_alternatives,
            )
            raw_skips = await asyncio.wait_for(
                enrich_skips_with_alternatives(route, raw_skips),
                timeout=30.0,
            )
        except asyncio.TimeoutError:
            _log.warning("here_toll_alternatives budget exceeded — heuristics only")
        except Exception as exc:  # noqa: BLE001
            _log.warning("here_toll_alternatives failed: %r", exc)
        for skip in raw_skips:
            partial_skips_out.append(
                PartialTollSkipOut(
                    label=skip.label,
                    kind=skip.kind,
                    index=skip.index,
                    total=skip.total,
                    distance_from_origin_km=skip.distance_from_origin_km,
                    savings_eur=skip.savings_eur,
                    time_penalty_minutes=skip.time_penalty_minutes,
                    extra_distance_km=skip.extra_distance_km,
                    worth_it=skip.worth_it,
                    lat=skip.coordinate.lat,
                    lon=skip.coordinate.lon,
                    detour_geometry=[
                        [c.lon, c.lat] for c in skip.alternative_geometry
                    ],
                )
            )

    intra_skips_out: list[IntraSectionSkipOut] = []
    if (
        payload.include_toll_alternative
        and real_tolls
        and isinstance(providers.tollguru, _HereTollsProvider)
    ):
        try:
            _raw_skips = await asyncio.wait_for(
                compute_intra_section_skips(
                    real_tolls, providers.osm_gates, providers.tollguru,
                ),
                timeout=20.0,
            )
        except asyncio.TimeoutError:
            _log.warning("intra_section_skips timed out after 20s — skipping")
            _raw_skips = []
        for s in _raw_skips:
            intra_skips_out.append(IntraSectionSkipOut(
                section_name=s.section_name,
                exit_gate_name=s.exit_gate_name,
                exit_lat=s.exit_lat,
                exit_lon=s.exit_lon,
                reentry_gate_name=s.reentry_gate_name,
                reentry_lat=s.reentry_lat,
                reentry_lon=s.reentry_lon,
                full_section_eur=s.full_section_eur,
                bypass_eur=s.bypass_eur,
                savings_eur=s.savings_eur,
                free_road_km=s.free_road_km,
                time_penalty_minutes=s.time_penalty_minutes,
                worth_it=s.worth_it,
            ))

    if payload.include_toll_alternative and alt_route_domain is not None:
        alt = compare_toll(route, alt_route_domain)
        toll_alternative_out = TollAlternativeOut(
            distance_km=alt.distance_km,
            duration_minutes=alt.duration_minutes,
            toll_cost_eur=alt.toll_cost_eur,
            savings_eur=alt.savings_eur,
            time_penalty_minutes=alt.time_penalty_minutes,
            extra_distance_km=alt.extra_distance_km,
            worth_it=alt.worth_it,
            geometry=[
                [c.lon, c.lat]
                for c in simplify_polyline(alt.geometry, epsilon_km=0.2)
            ],
        )

    hourly_toll_out: HourlyTollReportOut | None = None
    if payload.include_hourly_toll_analysis and alt_route_domain is not None:
        report = await hourly_toll_analyze(
            reference_day=payload.desired_departure_at,
            main_route=route,
            toll_free_route=alt_route_domain,
            traffic=providers.traffic,
        )
        hourly_toll_out = HourlyTollReportOut(
            verdicts=[
                HourlyTollVerdictOut(
                    hour=v.hour,
                    toll_route_minutes=v.toll_route_minutes,
                    toll_free_route_minutes=v.toll_free_route_minutes,
                    savings_eur=v.savings_eur,
                    recommendation=v.recommendation,
                )
                for v in report.verdicts
            ],
            best_hours_to_skip=list(report.best_hours_to_skip),
            worst_hours_to_skip=list(report.worst_hours_to_skip),
        )

    # ---- Optimizations (real POIs) + densification -----------------
    optimizations_out: OptimizationsOut | None = None
    opt_domain = None
    fuel_cost_domain = None
    fuel_prices_domain: tuple = ()
    _origin_label: str | None = None
    _dest_label: str | None = None
    _meal_hint_by_km: dict[float, str | None] = {}
    if profile is not None:
        restaurants_requested = bool(
            payload.restaurant_max_detour_minutes
            and payload.restaurant_max_detour_minutes > 0
        )
        hotels_requested = bool(
            payload.hotel_max_detour_minutes
            and payload.hotel_max_detour_minutes > 0
        )
        if hotels_requested:
            opti_hotels = (
                all_hotels_cache
                or await providers.hotels.hotels_along(route)
            )
        else:
            opti_hotels = ()
        if restaurants_requested:
            opti_restaurants = (
                all_restaurants_cache
                or await providers.restaurants.restaurants_along(route)
            )
            restaurants_by_slot: dict[MealSlot, tuple[Restaurant, ...]] = {
                slot: filter_restaurants(
                    opti_restaurants,
                    max_detour_minutes=15.0,
                    price_band=PriceBand.ANY,
                    profile=profile,
                    slot=slot,
                    limit=15,
                )
                for slot in (MealSlot.BREAKFAST, MealSlot.LUNCH, MealSlot.DINNER)
            }
        else:
            restaurants_by_slot = {}
        filtered_hotels_for_sleep = filter_hotels(
            opti_hotels,
            max_detour_minutes=45.0,
            price_band=PriceBand.ANY,
            profile=profile,
            limit=25,
        )
        opt = compute_optimizations(
            departure_at=effective_departure_at,
            trip_duration_hours=route.free_flow_duration.total_seconds() / 3600.0,
            rest_stops=rest_stops_domain,
            restaurants_by_slot=restaurants_by_slot,
            hotels=filtered_hotels_for_sleep,
            profile=profile,
            include_meal_stops=restaurants_requested,
            day_overrides=_day_overrides_map(payload),
        )
        # ---- Densification (meal restaurants + per-day hotels) ------
        # Fanned out in parallel after 2026-09-28 dogfood report:
        # long trips (Toledo → Turda, ~2800 km / 6 days = 18 meal
        # stops) would serialize `restaurants_near` calls at ~2 s
        # each, blowing the enrich budget and leaving middle days
        # empty on the wire. Gathering brings the total for the
        # meal-densification phase back to ~2-3 s regardless of trip
        # length. Widened radius fallback (25 → 60 km) so a sparse
        # region (rural Balkans, Alpine transits) still yields a
        # pick instead of silently dropping the meal.
        near_restaurants = getattr(
            providers.restaurants, "restaurants_near", None,
        )
        densified_restaurants: list = []
        if near_restaurants is not None:
            missing_meals = [
                (idx, m) for idx, m in enumerate(opt.meal_stops)
                if m.restaurant is None
            ]

            async def _hits_for(coord: Coordinate) -> tuple:
                """25 km first; widen to 60 km if the tight ring is empty."""
                try:
                    tight = await near_restaurants(coord, 25.0)
                except Exception as exc:  # noqa: BLE001
                    _log.warning(
                        "restaurants_near tight ring failed: %r", exc,
                    )
                    tight = ()
                if tight:
                    return tight
                try:
                    wide = await near_restaurants(coord, 60.0)
                except Exception as exc:  # noqa: BLE001
                    _log.warning(
                        "restaurants_near wide ring failed: %r", exc,
                    )
                    wide = ()
                return wide

            fan = await asyncio.gather(
                *[_hits_for(m.rest_stop.coordinate) for _, m in missing_meals],
                return_exceptions=True,
            )
            per_meal_hits: dict[int, tuple] = {}
            for (idx, _m), hits in zip(missing_meals, fan):
                per_meal_hits[idx] = () if isinstance(hits, Exception) else hits
                if not isinstance(hits, Exception):
                    densified_restaurants.extend(hits)

            patched_meals: list = []
            used_meal_names: set[str] = {
                m.restaurant.name
                for m in opt.meal_stops if m.restaurant is not None
            }
            for idx, m in enumerate(opt.meal_stops):
                if m.restaurant is None:
                    hits = per_meal_hits.get(idx, ())
                    pick = next(
                        (h for h in hits if h.name not in used_meal_names),
                        None,
                    )
                    if pick is not None:
                        used_meal_names.add(pick.name)
                        patched_meals.append(replace(m, restaurant=pick))
                        continue
                patched_meals.append(m)
            opt = replace(opt, meal_stops=tuple(patched_meals))
        near_hotels = getattr(providers.hotels, "hotels_near", None)
        densified_hotels: list = []
        _middle_day_hits: dict[tuple[float, float], list] = {}
        if near_hotels is not None and hotels_requested:
            # Same rationale as the meal densification above:
            # serialized per-sleep-stop calls made long trips'
            # middle-day hotels vanish because the enrich budget
            # ran out. Fan out with a widened-radius fallback so
            # rural sleep coords still yield a hit.
            async def _hotels_hits_for(
                coord: Coordinate, tight: float = 40.0, wide: float = 80.0,
            ) -> tuple:
                try:
                    t = await near_hotels(coord, tight)
                except Exception as exc:  # noqa: BLE001
                    _log.warning("hotels_near tight failed: %r", exc)
                    t = ()
                if t:
                    return t
                try:
                    return await near_hotels(coord, wide)
                except Exception as exc:  # noqa: BLE001
                    _log.warning("hotels_near wide failed: %r", exc)
                    return ()

            missing_sleeps = [
                (i, s) for i, s in enumerate(opt.sleep_stops)
                if s.hotel is None
            ]
            fan_sleep = await asyncio.gather(
                *[_hotels_hits_for(s.rest_stop.coordinate) for _, s in missing_sleeps],
                return_exceptions=True,
            )
            per_sleep_hits: dict[int, tuple] = {}
            for (i, _s), hits in zip(missing_sleeps, fan_sleep):
                per_sleep_hits[i] = () if isinstance(hits, Exception) else hits
                if not isinstance(hits, Exception):
                    densified_hotels.extend(hits)

            for i, s in enumerate(opt.sleep_stops):
                if s.hotel is not None:
                    continue
                hits = per_sleep_hits.get(i, ())
                if not hits:
                    continue
                new_sleeps = list(opt.sleep_stops)
                new_sleeps[i] = replace(s, hotel=hits[0])
                opt = replace(opt, sleep_stops=tuple(new_sleeps))
                if opt.sleep_stop is not None and \
                        opt.sleep_stop.rest_stop.coordinate == \
                        s.rest_stop.coordinate:
                    opt = replace(
                        opt,
                        sleep_stop=replace(opt.sleep_stop, hotel=hits[0]),
                    )
            seen_coords: set[tuple[float, float]] = set()
            dest_coord = Coordinate(
                lat=payload.destination.lat,
                lon=payload.destination.lon,
            )
            dest_key = (
                round(dest_coord.lat, 3),
                round(dest_coord.lon, 3),
            )
            seen_coords.add(dest_key)
            dest_radius = (
                payload.hotel_destination_radius_km
                if payload.hotel_destination_radius_km is not None
                else 40.0
            )
            # Also parallelize the "extra hotels per sleep coord for
            # the picker" pass so a 6-day trip doesn't serialize 6
            # more `hotels_near` calls back-to-back.
            extra_sleep_coords: list[Coordinate] = []
            for s in opt.sleep_stops:
                key = (
                    round(s.rest_stop.coordinate.lat, 3),
                    round(s.rest_stop.coordinate.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                extra_sleep_coords.append(s.rest_stop.coordinate)

            extra_fan = await asyncio.gather(
                _hotels_hits_for(dest_coord, tight=dest_radius, wide=dest_radius * 2),
                *[_hotels_hits_for(c) for c in extra_sleep_coords],
                return_exceptions=True,
            )
            for hits in extra_fan:
                if not isinstance(hits, Exception):
                    densified_hotels.extend(hits)
            _preview_multiday = compute_day_plan(
                departure_at=effective_departure_at,
                trip_duration_hours=(
                    route.free_flow_duration.total_seconds() / 3600.0
                ),
                profile=profile,
                optimizations=opt,
                rest_stops=rest_stops_domain,
                route_distance_km=route.distance_km,
                route=route,
                day_overrides=_day_overrides_map(payload),
            )
            _preview_days = (
                _preview_multiday.days if _preview_multiday else ()
            )
            for wp in dwell_waypoints:
                if wp.dwell_nights < 1:
                    continue
                key = (
                    round(wp.coordinate.lat, 3),
                    round(wp.coordinate.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                hits = await near_hotels(wp.coordinate, 30.0)
                if not hits:
                    hits = await near_hotels(wp.coordinate, 60.0)
                densified_hotels.extend(hits)
            for _d in _preview_days:
                if _d.sleep_coord is None:
                    continue
                key = (
                    round(_d.sleep_coord.lat, 3),
                    round(_d.sleep_coord.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                hits = await near_hotels(_d.sleep_coord, 60.0)
                if not hits:
                    hits = await near_hotels(_d.sleep_coord, 90.0)
                _log.info(
                    "densify day %d sleep_coord=%.3f,%.3f raw_hits=%d",
                    _d.day_index, _d.sleep_coord.lat,
                    _d.sleep_coord.lon, len(hits),
                )
                _middle_day_hits[key] = list(hits)
                densified_hotels.extend(hits)
            for m in opt.meal_stops:
                key = (
                    round(m.rest_stop.coordinate.lat, 3),
                    round(m.rest_stop.coordinate.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                hits = await near_hotels(m.rest_stop.coordinate, 40.0)
                densified_hotels.extend(hits)
        opt_domain = opt
        _seen_hotels = {
            (h.name, round(h.lat, 4), round(h.lon, 4))
            for h in hotels_out
        }
        _densified_filtered = filter_hotels(
            tuple(densified_hotels),
            max_detour_minutes=1e9,
            price_band=payload.hotel_price_band or PriceBand.ANY,
            price_bands=payload.hotel_price_bands,
            profile=profile,
            min_stars=payload.hotel_min_stars,
        )
        try:
            _kept_coords = {
                (round(h.coordinate.lat, 2), round(h.coordinate.lon, 2))
                for h in _densified_filtered
            }
            _extra_middle: list = []
            for key, raw in _middle_day_hits.items():
                nearby = any(
                    abs(kc[0] - key[0]) < 1.0 and abs(kc[1] - key[1]) < 1.0
                    for kc in _kept_coords
                )
                if nearby:
                    continue
                _log.info(
                    "safety-net inject %d unfiltered hotels for "
                    "sleep_coord %.3f,%.3f", len(raw[:5]), key[0], key[1],
                )
                _extra_middle.extend(raw[:5])
            if _extra_middle:
                _densified_filtered = tuple(
                    list(_densified_filtered) + _extra_middle,
                )
        except Exception as exc:  # noqa: BLE001
            _log.warning("middle-day safety net failed: %r", exc)
        for h in _densified_filtered:
            key = (h.name, round(h.coordinate.lat, 4),
                   round(h.coordinate.lon, 4))
            if key in _seen_hotels:
                continue
            _seen_hotels.add(key)
            hotels_out.append(HotelOut(
                name=h.name,
                country=h.country,
                price_eur_per_night=h.price_eur_per_night,
                price_band=h.price_band,
                detour_minutes=h.detour_minutes,
                distance_from_route_km=h.distance_from_route_km,
                lat=h.coordinate.lat,
                lon=h.coordinate.lon,
                attributes=dict(h.attributes),
            ))
        _seen_rest = {
            (r.name, round(r.lat, 4), round(r.lon, 4))
            for r in restaurants_out
        }
        for r in densified_restaurants:
            key = (r.name, round(r.coordinate.lat, 4), round(r.coordinate.lon, 4))
            if key in _seen_rest:
                continue
            _seen_rest.add(key)
            restaurants_out.append(RestaurantOut(
                name=r.name,
                country=r.country,
                price_eur_per_meal=r.price_eur_per_meal,
                price_band=r.price_band,
                detour_minutes=r.detour_minutes,
                distance_from_route_km=r.distance_from_route_km,
                lat=r.coordinate.lat,
                lon=r.coordinate.lon,
                attributes=dict(r.attributes),
            ))
        # ---- Real fuel cost + savings stamping ---------------------
        cost = estimate_fuel(route, profile.vehicle, fuel)
        fuel_cost_domain = cost
        fuel_prices_domain = fuel

        # ---- Reverse-geocode meal + sleep + origin/dest ------------
        async def _city(coord) -> str | None:
            """Cheap best-effort city hint for a coord.

            Prefers the shortest first token of the display name
            ("Toledo, Toledo, Castilla-La Mancha, España" → "Toledo").
            Silently returns None when the provider has no reverse
            method (mock in tests) or errors out.
            """

            reverse = getattr(providers.geocoding, "reverse", None)
            if reverse is None or coord is None:
                return None
            try:
                r = await reverse(coord.lat, coord.lon)
                if r is None:
                    return None
                return r.display_name.split(",")[0].strip() or None
            except Exception:  # noqa: BLE001
                return None

        meal_city_hints = await asyncio.gather(*(
            _city(m.rest_stop.coordinate) for m in opt.meal_stops
        ))
        _meal_hint_by_km = {
            m.rest_stop.distance_from_origin_km: meal_city_hints[i]
            for i, m in enumerate(opt.meal_stops)
        }
        sleep_city_hint = await _city(
            opt.sleep_stop.rest_stop.coordinate
            if opt.sleep_stop is not None else None
        )
        _origin_coord = Coordinate(lat=payload.origin.lat, lon=payload.origin.lon)
        _dest_coord = Coordinate(lat=payload.destination.lat, lon=payload.destination.lon)
        _origin_label, _dest_label = await asyncio.gather(
            _city(_origin_coord),
            _city(_dest_coord),
        )
        optimizations_out = OptimizationsOut(
            meal_stops=[
                MealStopOut(
                    slot=m.slot,
                    at=m.at,
                    distance_from_origin_km=m.rest_stop.distance_from_origin_km,
                    restaurant_name=m.restaurant.name if m.restaurant else None,
                    restaurant_price_eur_per_meal=(
                        m.restaurant.price_eur_per_meal if m.restaurant else None
                    ),
                    restaurant_lat=(
                        m.restaurant.coordinate.lat if m.restaurant else None
                    ),
                    restaurant_lon=(
                        m.restaurant.coordinate.lon if m.restaurant else None
                    ),
                    city_hint=meal_city_hints[i],
                    lat=(
                        m.restaurant.coordinate.lat if m.restaurant
                        else m.rest_stop.coordinate.lat
                    ),
                    lon=(
                        m.restaurant.coordinate.lon if m.restaurant
                        else m.rest_stop.coordinate.lon
                    ),
                )
                for i, m in enumerate(opt.meal_stops)
            ],
            sleep_stop=(
                SleepStopOut(
                    at=opt.sleep_stop.at,
                    distance_from_origin_km=opt.sleep_stop.rest_stop.distance_from_origin_km,
                    hotel_name=(
                        opt.sleep_stop.hotel.name if opt.sleep_stop.hotel else None
                    ),
                    hotel_price_eur_per_night=(
                        opt.sleep_stop.hotel.price_eur_per_night
                        if opt.sleep_stop.hotel else None
                    ),
                    hotel_lat=(
                        opt.sleep_stop.hotel.coordinate.lat
                        if opt.sleep_stop.hotel else None
                    ),
                    hotel_lon=(
                        opt.sleep_stop.hotel.coordinate.lon
                        if opt.sleep_stop.hotel else None
                    ),
                    city_hint=sleep_city_hint,
                    lat=(
                        opt.sleep_stop.hotel.coordinate.lat
                        if opt.sleep_stop.hotel
                        else opt.sleep_stop.rest_stop.coordinate.lat
                    ),
                    lon=(
                        opt.sleep_stop.hotel.coordinate.lon
                        if opt.sleep_stop.hotel
                        else opt.sleep_stop.rest_stop.coordinate.lon
                    ),
                )
                if opt.sleep_stop is not None else None
            ),
            fuel_cost=FuelCostOut(
                total_cost_eur=cost.total_cost_eur,
                average_unit_price_eur=cost.average_unit_price_eur,
                fuel_type=cost.fuel_type,
                fuel_units=cost.fuel_units,
                unit_label=cost.unit_label,
                range_ok=cost.range_ok,
                notes=list(cost.notes),
            ),
        )

    # ---- Destination densification WITHOUT a profile ---------------
    if (
        profile is None
        and effective_hotel_detour
        and effective_hotel_detour > 0
    ):
        near_hotels_fn = getattr(providers.hotels, "hotels_near", None)
        if near_hotels_fn is not None:
            dest_coord = Coordinate(
                lat=payload.destination.lat,
                lon=payload.destination.lon,
            )
            dest_hits = await near_hotels_fn(dest_coord, 40.0)
            dest_hits = filter_hotels(
                tuple(dest_hits),
                max_detour_minutes=1e9,
                price_band=payload.hotel_price_band or PriceBand.ANY,
                price_bands=payload.hotel_price_bands,
                profile=None,
                min_stars=payload.hotel_min_stars,
            )
            _seen = {(h.name, round(h.lat, 4), round(h.lon, 4))
                     for h in hotels_out}
            for h in dest_hits:
                key = (h.name, round(h.coordinate.lat, 4),
                       round(h.coordinate.lon, 4))
                if key in _seen:
                    continue
                _seen.add(key)
                hotels_out.append(HotelOut(
                    name=h.name,
                    country=h.country,
                    price_eur_per_night=h.price_eur_per_night,
                    price_band=h.price_band,
                    detour_minutes=h.detour_minutes,
                    distance_from_route_km=h.distance_from_route_km,
                    lat=h.coordinate.lat,
                    lon=h.coordinate.lon,
                    attributes=dict(h.attributes),
                ))

    # ---- Adverse events (near-route filter + serious types) --------
    _SERIOUS_EVENT_TYPES = {
        AdverseEventType.FIRE,
        AdverseEventType.WEATHER,
        AdverseEventType.FLOOD,
        AdverseEventType.SNOW,
        AdverseEventType.EARTHQUAKE,
        AdverseEventType.LANDSLIDE,
        AdverseEventType.AVALANCHE,
        AdverseEventType.HEATWAVE,
        AdverseEventType.ACCIDENT,
        AdverseEventType.CLOSURE,
    }
    adverse_events_out: list[AdverseEventOut] = []
    if payload.include_adverse_events and adverse_raw:
        near = filter_events_near_route(
            adverse_raw, route,
            max_distance_km=payload.adverse_events_max_distance_km,
        )
        adverse_events_out = [
            AdverseEventOut(
                id=e.id,
                type=e.type,
                severity=e.severity,
                source=e.source.value,
                description=e.description,
                reported_at=e.reported_at,
                expires_at=e.expires_at,
                lat=e.coordinate.lat,
                lon=e.coordinate.lon,
                country=e.country,
            )
            for e in near
            if e.type in _SERIOUS_EVENT_TYPES
            and e.severity != AdverseEventSeverity.INFO
        ]

    variants_out: list[RouteVariantOut] = [
        RouteVariantOut(
            key=v.key, label=v.label,
            distance_km=v.route.distance_km,
            free_flow_minutes=_minutes(v.route.free_flow_duration),
            toll_cost_eur=v.route.toll_cost_eur,
        )
        for v in variants_raw
    ]

    # ---- Fuel savings analysis -------------------------------------
    vehicle_for_savings = profile.vehicle if profile is not None else None
    arbitrage_domain = compute_fuel_arbitrage(
        fuel, vehicle=vehicle_for_savings,
    )
    fuel_curated = curate_fuel_stations(
        stamp_fuel_savings(fuel, vehicle=vehicle_for_savings),
    )
    fuel_curated = tuple(_bucketed_top_cheapest(
        list(fuel_curated), route_km=route.distance_km,
    ))
    arbitrage_out = None if arbitrage_domain is None else FuelArbitrageOut(
        cheaper_country=arbitrage_domain.cheaper_country,
        cheaper_median_eur_per_l=arbitrage_domain.cheaper_median_eur_per_l,
        pricier_country=arbitrage_domain.pricier_country,
        pricier_median_eur_per_l=arbitrage_domain.pricier_median_eur_per_l,
        delta_eur_per_l=arbitrage_domain.delta_eur_per_l,
        estimated_tank_saving_eur=arbitrage_domain.estimated_tank_saving_eur,
    )

    # ---- Multi-day breakdown with enriched hints -------------------
    days_out: list[DayPlanOut] = []
    if profile is not None:
        _log.info(
            "day_plan IN: n=%d dwell=%s labels=%s duration_h=%.2f",
            len(dwell_waypoints),
            [w.dwell_nights for w in dwell_waypoints],
            [w.label for w in dwell_waypoints],
            route.free_flow_duration.total_seconds() / 3600.0,
        )
        multiday = compute_day_plan(
            departure_at=effective_departure_at,
            trip_duration_hours=(
                route.free_flow_duration.total_seconds() / 3600.0
            ),
            profile=profile,
            optimizations=opt_domain,
            rest_stops=rest_stops_domain,
            route_distance_km=route.distance_km,
            route=route,
            waypoints=dwell_waypoints,
            origin_label=_origin_label,
            destination_label=_dest_label,
            day_overrides=_day_overrides_map(payload),
        )
        _log.info(
            "day_plan OUT: is_multiday=%s days=%d per_day_labels=%s",
            multiday is not None,
            0 if multiday is None else len(multiday.days),
            [] if multiday is None else [
                list(d.waypoint_labels) for d in multiday.days
            ],
        )
        if multiday is not None:
            _n = len(multiday.days)
            _sleep_city: list[str | None] = [None] * _n
            _missing = [
                (i, d) for i, d in enumerate(multiday.days)
                if d.sleep_at is not None
                and d.to_name is None
                and d.sleep_coord is not None
            ]
            if _missing:
                async def _city_local(coord) -> str | None:
                    reverse = getattr(providers.geocoding, "reverse", None)
                    if reverse is None or coord is None:
                        return None
                    try:
                        r = await reverse(coord.lat, coord.lon)
                        if r is None:
                            return None
                        return r.display_name.split(",")[0].strip() or None
                    except Exception:  # noqa: BLE001
                        return None
                _geocoded = await asyncio.gather(*(
                    _city_local(d.sleep_coord) for _, d in _missing
                ))
                for (i, _), city in zip(_missing, _geocoded):
                    _sleep_city[i] = city
            for d in multiday.days:
                _i = d.day_index - 1
                _to_name = d.to_name or (
                    _sleep_city[_i] if d.sleep_at is not None else None
                )
                _from_name = d.from_name or (
                    _sleep_city[_i - 1] if _i > 0 else None
                )
                days_out.append(
                    DayPlanOut(
                        day_index=d.day_index,
                        start_at=d.start_at,
                        end_at=d.end_at,
                        from_km=d.from_km,
                        to_km=d.to_km,
                        meal_stops=[
                            MealStopOut(
                                slot=m.slot,
                                at=m.at,
                                distance_from_origin_km=(
                                    m.rest_stop.distance_from_origin_km
                                ),
                                restaurant_name=(
                                    m.restaurant.name if m.restaurant else None
                                ),
                                restaurant_price_eur_per_meal=(
                                    m.restaurant.price_eur_per_meal
                                    if m.restaurant else None
                                ),
                                restaurant_lat=(
                                    m.restaurant.coordinate.lat
                                    if m.restaurant else None
                                ),
                                restaurant_lon=(
                                    m.restaurant.coordinate.lon
                                    if m.restaurant else None
                                ),
                                city_hint=_meal_hint_by_km.get(
                                    m.rest_stop.distance_from_origin_km
                                ),
                                lat=(
                                    m.restaurant.coordinate.lat
                                    if m.restaurant
                                    else m.rest_stop.coordinate.lat
                                ),
                                lon=(
                                    m.restaurant.coordinate.lon
                                    if m.restaurant
                                    else m.rest_stop.coordinate.lon
                                ),
                            )
                            for m in d.meal_stops
                        ],
                        rest_stops=[
                            RestStopOut(
                                distance_from_origin_km=s.distance_from_origin_km,
                                cumulative_driving_hours=s.cumulative_driving_hours,
                                recommended_break_minutes=s.recommended_break_minutes,
                                lat=s.coordinate.lat,
                                lon=s.coordinate.lon,
                                kid_friendly=s.kid_friendly,
                                pet_friendly=s.pet_friendly,
                                rv_friendly=s.rv_friendly,
                                name=s.name,
                                stop_type=(
                                    s.stop_type.value if s.stop_type else "unknown"
                                ),
                                reason=_reason_for_rest_stop(s, profile),
                            )
                            for s in d.rest_stops
                        ],
                        sleep_at=d.sleep_at,
                        sleep_lat=d.sleep_coord.lat if d.sleep_coord else None,
                        sleep_lon=d.sleep_coord.lon if d.sleep_coord else None,
                        dwell_label=d.dwell_label,
                        from_name=_from_name,
                        to_name=_to_name,
                        waypoint_labels=list(d.waypoint_labels),
                        waypoint_anchors=[
                            WaypointAnchorOut(
                                label=a.label, km=a.km,
                                lat=a.lat, lon=a.lon,
                            )
                            for a in d.waypoint_anchors
                        ],
                    )
                )

    # ---- Refuel window --------------------------------------------
    refuel_out: RefuelWindowOut | None = None
    resolved_model_id: str | None = None
    resolved_tank_pct: int | None = None
    if payload.garage_vehicle_id and user is not None:
        from app.api.v1.profile import resolve_garage_vehicle
        garage_entry = await resolve_garage_vehicle(
            user.id, payload.garage_vehicle_id,
        )
        if garage_entry is not None:
            resolved_model_id = str(garage_entry.get("model_id") or "")
            if (
                payload.trip_profile is not None
                and payload.trip_profile.current_tank_level_percent is not None
            ):
                resolved_tank_pct = (
                    payload.trip_profile.current_tank_level_percent
                )
            else:
                raw = garage_entry.get("default_tank_percent")
                if isinstance(raw, (int, float)):
                    resolved_tank_pct = int(raw)
    if resolved_model_id is None and payload.trip_profile is not None:
        resolved_model_id = payload.trip_profile.vehicle_model_id
        resolved_tank_pct = payload.trip_profile.current_tank_level_percent
    if (
        resolved_model_id
        and resolved_tank_pct is not None
        and profile is not None
        and profile.vehicle.fuel_type != FuelType.ELECTRIC
    ):
        from app.data.vehicle_models import find as _find_vehicle
        from app.services.fuel_planning import (
            refuel_window as _refuel_window,
            pick_cheapest_in_window as _pick_cheapest_in_window,
            estimate_fuel_savings as _estimate_fuel_savings,
            route_median_price as _route_median_price,
            liters_needed_for_refuel as _liters_needed_for_refuel,
        )
        hit = _find_vehicle(resolved_model_id)
        if hit is not None:
            rw = _refuel_window(
                route_distance_km=route.distance_km,
                tank_level_frac=resolved_tank_pct / 100.0,
                tank_liters=hit.tank_liters,
                consumption_l100km=hit.consumption_l100km,
            )
            suggested_out: FuelPriceOut | None = None
            suggested_savings: float | None = None
            if not rw.reaches_destination and fuel_curated:
                picked = _pick_cheapest_in_window(
                    fuel_curated, from_km=0.0, to_km=rw.must_by_km,
                )
                median = _route_median_price(fuel_curated)
                if picked is not None and median is not None:
                    liters_needed = _liters_needed_for_refuel(
                        tank_liters=hit.tank_liters,
                        current_tank_frac=resolved_tank_pct / 100.0,
                    )
                    suggested_savings = round(
                        _estimate_fuel_savings(
                            picked_price=picked.price_eur_per_l,
                            median_price=median,
                            liters_needed=liters_needed,
                        ),
                        2,
                    )
                    suggested_out = FuelPriceOut(
                        station_name=picked.station_name,
                        country=picked.country,
                        price_eur_per_l=picked.price_eur_per_l,
                        price_available=picked.price_available,
                        savings_vs_country_median_eur_per_l=(
                            picked.savings_vs_country_median_eur_per_l
                        ),
                        distance_from_origin_km=(
                            picked.distance_from_origin_km
                        ),
                        lat=(
                            picked.coordinate.lat
                            if picked.coordinate is not None else None
                        ),
                        lon=(
                            picked.coordinate.lon
                            if picked.coordinate is not None else None
                        ),
                        attributes=dict(picked.attributes),
                        unit_label=picked.unit_label,
                        is_charging_station=picked.is_charging_station,
                    )
            refuel_out = RefuelWindowOut(
                usable_range_km=rw.usable_range_km,
                comfortable_by_km=rw.comfortable_by_km,
                must_by_km=rw.must_by_km,
                reaches_destination=rw.reaches_destination,
                suggested_station=suggested_out,
                suggested_savings_eur=suggested_savings,
            )

    parkings_out: list[ParkingOutTrip] = []
    for p in parkings_raw:
        parkings_out.append(ParkingOutTrip(
            name=p.name,
            lat=p.coordinate.lat,
            lon=p.coordinate.lon,
            country=p.country.value,
            distance_from_destination_km=round(
                p.distance_from_query_km, 3,
            ),
            price_eur_per_hour=p.price_eur_per_hour,
            covered=p.covered,
            capacity=p.capacity,
            kind=p.kind,
            kid_friendly=p.kid_friendly,
            dogs_allowed=p.dogs_allowed,
            toilets=p.toilets,
            food_nearby=p.food_nearby,
            ev_charging=p.ev_charging,
            rv_friendly=p.rv_friendly,
        ))

    # Re-run consistency with the real fuel_cost + fuel_prices tuple.
    # For /plan/enrich HTTP we drop this on the wire (core owns it),
    # but the merged /plan payload uses it when core's list is empty.
    consistency_out = [
        _issue_to_out(i, days_out)
        for i in check_trip_consistency(
            departure_at=effective_departure_at,
            arrival_at=effective_arrival_at,
            optimizations=opt_domain,
            route=route,
            fuel_cost=fuel_cost_domain,
            fuel_prices=fuel_prices_domain,
        )
    ]

    savings = SavingsSummaryOut(
        time_saved_minutes_vs_desired=0.0,
        money_saved_eur_vs_tolls=(
            toll_alternative_out.savings_eur
            if toll_alternative_out is not None and toll_alternative_out.worth_it
            else 0.0
        ),
    )

    return TripPlanResponse(
        route=_empty_route(),
        time_windows=[],
        fuel_prices=[
            FuelPriceOut(
                station_name=fp.station_name,
                country=fp.country,
                price_eur_per_l=fp.price_eur_per_l,
                price_available=fp.price_available,
                savings_vs_country_median_eur_per_l=(
                    fp.savings_vs_country_median_eur_per_l
                ),
                distance_from_origin_km=fp.distance_from_origin_km,
                lat=fp.coordinate.lat if fp.coordinate is not None else None,
                lon=fp.coordinate.lon if fp.coordinate is not None else None,
                attributes=dict(fp.attributes),
                unit_label=fp.unit_label,
                is_charging_station=fp.is_charging_station,
            )
            for fp in fuel_curated
            if fp.price_available or fp.is_charging_station
        ],
        hotels=hotels_out,
        restaurants=restaurants_out,
        parkings=parkings_out,
        rest_stops=rest_stops_out,
        adverse_events=adverse_events_out,
        toll_alternative=toll_alternative_out,
        partial_toll_skips=partial_skips_out,
        intra_section_skips=intra_skips_out,
        optimizations=optimizations_out,
        hourly_toll_report=hourly_toll_out,
        savings=savings,
        route_variants=variants_out,
        recommendation_scope=None,
        consistency_issues=consistency_out,
        fuel_arbitrage=arbitrage_out,
        days=days_out,
        weather_segments=[
            WeatherSegmentOut(
                from_km=s.from_km,
                to_km=s.to_km,
                label=s.label,
                icon=s.icon,
                temperature_c=s.temperature_c,
                lat=s.coordinate.lat,
                lon=s.coordinate.lon,
            )
            for s in weather_raw
        ],
        refuel_window=refuel_out,
    )


def _merge_full(
    core: TripPlanResponse,
    enrich: TripPlanResponse,
) -> TripPlanResponse:
    """Reassemble a full-payload TripPlanResponse from the two slices.

    The legacy ``POST /plan`` endpoint returns this so pre-progressive
    clients keep seeing everything at once. Enrich's day plan +
    optimizations + consistency issues win (they use real POIs and
    real fuel costs); core keeps the route + time_windows + scope
    metadata it owns. Savings blend both — time from core, money
    from enrich.
    """

    return core.model_copy(update={
        "hotels": enrich.hotels,
        "restaurants": enrich.restaurants,
        "parkings": enrich.parkings,
        "fuel_prices": enrich.fuel_prices,
        "rest_stops": enrich.rest_stops,
        "adverse_events": enrich.adverse_events,
        "toll_alternative": enrich.toll_alternative,
        "partial_toll_skips": enrich.partial_toll_skips,
        "intra_section_skips": enrich.intra_section_skips,
        "hourly_toll_report": enrich.hourly_toll_report,
        "fuel_arbitrage": enrich.fuel_arbitrage,
        "weather_segments": enrich.weather_segments,
        "refuel_window": enrich.refuel_window,
        "route_variants": enrich.route_variants,
        "days": enrich.days if enrich.days else core.days,
        "optimizations": enrich.optimizations or core.optimizations,
        "consistency_issues": (
            enrich.consistency_issues
            if enrich.consistency_issues else core.consistency_issues
        ),
        "savings": SavingsSummaryOut(
            time_saved_minutes_vs_desired=core.savings.time_saved_minutes_vs_desired,
            money_saved_eur_vs_tolls=enrich.savings.money_saved_eur_vs_tolls,
        ),
    })


# --- Public routes -------------------------------------------------
#
# Three progressive endpoints. ``/plan/core`` and ``/plan/enrich`` run
# independent compute paths; ``/plan`` fans out both concurrently and
# merges. Each has its own cache slot so back-to-back calls on the
# same trip stay cheap without the three shapes ever colliding.


@router.post("/plan", response_model=TripPlanResponse)
async def plan_trip(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
    premium: bool = Depends(is_premium),
    user: AuthUser | None = Depends(current_user_optional),
) -> TripPlanResponse:
    """Monolithic /plan — backwards compat with pre-progressive clients.

    Runs the shared preamble once, then fans out core + enrich
    concurrently and merges the two into the full-shaped response.
    """

    _enforce_premium_gates(payload, premium)
    cache = get_plan_cache()
    key = cache.key_for(payload, PlanCacheSlot.FULL)
    hit = await cache.get(key)
    if hit is not None:
        _log.info("plan_cache HIT slot=full key=%s", key[:8])
        return hit
    _log.info("plan_cache MISS slot=full key=%s", key[:8])

    preamble = await _plan_shared_preamble(payload, providers)
    core_resp, enrich_resp = await asyncio.gather(
        _plan_core_impl(payload, providers, premium, user, preamble),
        _plan_enrich_impl(payload, providers, premium, user, preamble),
    )
    merged = _merge_full(core_resp, enrich_resp)
    await cache.set(key, merged)
    return merged


@router.post("/plan/core", response_model=TripPlanResponse)
async def plan_trip_core(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
    premium: bool = Depends(is_premium),
    user: AuthUser | None = Depends(current_user_optional),
) -> TripPlanResponse:
    """Fast phase — returns route + days + savings + windows.

    Runs only the shared preamble and the core compute path — no
    hotel, restaurant, fuel, weather, or adverse-event fan-out. The
    mobile ResultScreen renders the map + hero + day cards from this
    payload while ``/plan/enrich`` is still in flight.
    """

    _enforce_premium_gates(payload, premium)
    cache = get_plan_cache()
    key = cache.key_for(payload, PlanCacheSlot.CORE)
    hit = await cache.get(key)
    if hit is not None:
        _log.info("plan_cache HIT slot=core key=%s", key[:8])
        return hit
    _log.info("plan_cache MISS slot=core key=%s", key[:8])

    preamble = await _plan_shared_preamble(payload, providers)
    resp = await _plan_core_impl(payload, providers, premium, user, preamble)
    await cache.set(key, resp)
    return resp


@router.post("/plan/enrich", response_model=TripPlanResponse)
async def plan_trip_enrich(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
    premium: bool = Depends(is_premium),
    user: AuthUser | None = Depends(current_user_optional),
) -> TripPlanResponse:
    """Slow phase — hotels, restaurants, fuel, weather, adverse
    events, toll alternative, parking, route variants.

    Core-owned fields (route, time_windows, days, optimizations,
    recommendation_scope, consistency_issues) are cleared before the
    response leaves the endpoint — the client already has them from
    the earlier ``/plan/core`` call, so re-shipping wastes bytes and
    parse cycles. Enrich still computes ``days`` internally because
    the legacy ``/plan`` merge needs the enriched version.
    """

    _enforce_premium_gates(payload, premium)
    cache = get_plan_cache()
    key = cache.key_for(payload, PlanCacheSlot.ENRICH)
    hit = await cache.get(key)
    if hit is not None:
        _log.info("plan_cache HIT slot=enrich key=%s", key[:8])
        return hit
    _log.info("plan_cache MISS slot=enrich key=%s", key[:8])

    preamble = await _plan_shared_preamble(payload, providers)
    resp = await _plan_enrich_impl(payload, providers, premium, user, preamble)
    # Strip core-owned fields on the wire. Days STAY on the response
    # because their per-day `rest_stops` carry the Overpass-enriched
    # POI names / types / reasons — clearing them (as the earlier
    # version did) meant the mobile client, whose progressive merge
    # takes days from /plan/core, kept rendering empty per-day
    # rest_stop rows until the driver forced a full re-plan.
    resp = resp.model_copy(update={
        "route": _empty_route(),
        "time_windows": [],
        "optimizations": None,
        "recommendation_scope": None,
        "consistency_issues": [],
        "savings": SavingsSummaryOut(
            time_saved_minutes_vs_desired=0.0,
            money_saved_eur_vs_tolls=resp.savings.money_saved_eur_vs_tolls,
        ),
    })
    # Enrich TTL is 5 min — POI prices and weather turn over faster
    # than the core route.
    await cache.set(key, resp, ttl_seconds=300)
    return resp




class AdverseRefreshCoordinate(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


class AdverseRefreshRequest(BaseModel):
    """Companion-mode live re-scan of adverse events ahead of the driver.

    The plan response is a snapshot at planning time — a fire alert or
    thunderstorm developing mid-drive doesn't propagate back to the
    driver. Companion polls this endpoint every 15 min with its current
    km-along-route so we re-run the same feeds (EFFIS fires, Open-Meteo
    weather, USGS quakes, heatwave) against just the corridor slice the
    driver is about to cross.
    """
    geometry: list[AdverseRefreshCoordinate] = Field(
        min_length=2,
        description="Full route polyline (from the plan response).",
    )
    current_km: float = Field(
        ge=0.0,
        description=(
            "Driver's current position measured as km-from-origin along "
            "the polyline. Client computes this by snapping its GPS "
            "fix to `geometry`."
        ),
    )
    look_ahead_km: float = Field(
        default=200.0,
        gt=0.0,
        le=1000.0,
        description=(
            "How far along the polyline to look. 200 km fits ~2 h of "
            "highway driving — long enough that the driver has time "
            "to react, short enough to keep the query cheap."
        ),
    )
    countries: list[Country] | None = Field(
        default=None,
        description=(
            "Optional country hints for country-scoped feeds "
            "(e.g. national weather advisories)."
        ),
    )
    max_distance_km: float = Field(
        default=12.0,
        gt=0.0,
        le=200.0,
        description=(
            "Corridor half-width for near-route filtering. Default matches "
            "the /plan endpoint (12 km, tuned for FIRMS smoke plume)."
        ),
    )


class AdverseRefreshResponse(BaseModel):
    events: list[AdverseEventOut]
    sliced_from_km: float
    sliced_to_km: float
    sliced_distance_km: float


def _haversine_km_pair(a: Coordinate, b: Coordinate) -> float:
    """Cheap haversine — inline copy of `_haversine_km` from
    `providers.routing`. Kept local to avoid an extra import layer
    when this file is already at 2 000+ lines."""
    from math import radians, cos, sin, asin, sqrt
    lat1, lon1, lat2, lon2 = map(radians, (a.lat, a.lon, b.lat, b.lon))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * 6371.0 * asin(sqrt(h))


def _slice_polyline_by_km(
    geometry: list[Coordinate],
    current_km: float,
    look_ahead_km: float,
) -> tuple[list[Coordinate], float, float, float]:
    """Return the slice of `geometry` whose cumulative-km-from-start
    falls in (current_km, current_km + look_ahead_km].

    Returns (sliced_points, actual_from_km, actual_to_km, distance_km).
    Points at cumulative_km <= current_km are dropped; the first
    surviving point is prepended with the interpolated location at
    exactly current_km if the boundary lands mid-segment (so the
    downstream Route.origin is anchored precisely where the driver
    is, not at the next raw vertex which may be up to 5 km further
    on for OSRM-simplified corridors).
    """
    if len(geometry) < 2:
        return ([], current_km, current_km, 0.0)
    end_km = current_km + look_ahead_km
    sliced: list[Coordinate] = []
    cum = 0.0
    first_idx: int | None = None
    for i in range(len(geometry)):
        if i > 0:
            cum += _haversine_km_pair(geometry[i - 1], geometry[i])
        # Strict less-than at the near edge: when `current_km == 0` we
        # want to keep the origin vertex (its cum is 0). For any other
        # `current_km > 0` the interpolation below anchors the slice
        # start at the exact km, so we drop vertices strictly behind.
        if cum < current_km:
            continue
        if cum > end_km:
            break
        if first_idx is None:
            first_idx = i
        sliced.append(geometry[i])
    if not sliced:
        return ([], current_km, current_km, 0.0)
    # Anchor the first point EXACTLY at current_km so downstream Route
    # objects (which use origin as one of the near-route reference
    # points) don't drift by up to a segment length. Interpolate
    # between the vertex before the slice and the first surviving one.
    if first_idx is not None and first_idx > 0:
        prev = geometry[first_idx - 1]
        nxt = geometry[first_idx]
        # cum after this segment (already accumulated by the loop) is
        # the km at `nxt`; back-compute km at `prev`.
        seg_len = _haversine_km_pair(prev, nxt)
        cum_at_prev = 0.0
        _c = 0.0
        for j in range(1, first_idx + 1):
            step = _haversine_km_pair(geometry[j - 1], geometry[j])
            if j == first_idx:
                cum_at_prev = _c
            _c += step
        overshoot = current_km - cum_at_prev
        if seg_len > 0.0 and 0 < overshoot < seg_len:
            frac = overshoot / seg_len
            interp = Coordinate(
                lat=prev.lat + (nxt.lat - prev.lat) * frac,
                lon=prev.lon + (nxt.lon - prev.lon) * frac,
            )
            sliced.insert(0, interp)
    dist = 0.0
    for i in range(1, len(sliced)):
        dist += _haversine_km_pair(sliced[i - 1], sliced[i])
    return (sliced, current_km, current_km + dist, dist)


@router.post("/adverse-refresh", response_model=AdverseRefreshResponse)
async def refresh_adverse_events(
    payload: AdverseRefreshRequest,
    providers: Providers = Depends(_providers),
) -> AdverseRefreshResponse:
    """Live re-scan of adverse events for the corridor slice ahead of
    the driver. Companion polls this every ~15 min so new fires /
    thunderstorms / quakes that develop mid-drive surface as fresh
    notifications instead of the frozen plan-time snapshot.

    Cheap by design: sliced route (~200 km) keeps FIRMS / Open-Meteo
    bounding boxes small, and no POI / hotel / fuel fetching runs.
    """
    geometry = [
        Coordinate(lat=p.lat, lon=p.lon) for p in payload.geometry
    ]
    sliced, from_km, to_km, dist_km = _slice_polyline_by_km(
        geometry, payload.current_km, payload.look_ahead_km,
    )
    if len(sliced) < 2 or dist_km <= 0.0:
        return AdverseRefreshResponse(
            events=[],
            sliced_from_km=from_km,
            sliced_to_km=to_km,
            sliced_distance_km=dist_km,
        )
    # Synthesise a Route object the existing providers understand.
    # Free-flow duration is a rough 100 km/h floor — enough for the
    # Open-Meteo weather provider to pick a valid arrival time and
    # for other providers that check `route.free_flow_duration > 0`.
    slice_route = Route(
        origin=sliced[0],
        destination=sliced[-1],
        distance_km=dist_km,
        free_flow_duration=timedelta(hours=max(dist_km / 100.0, 0.1)),
        polyline="",
        toll_cost_eur=0.0,
        countries_crossed=tuple(payload.countries or ()),
        waypoints=tuple(sliced[1:-1]),
        geometry=tuple(sliced),
    )
    now = datetime.now(timezone.utc)
    try:
        raw = await asyncio.wait_for(
            providers.adverse_events.events_along(slice_route, now=now),
            timeout=8.0,
        )
    except (asyncio.TimeoutError, Exception) as exc:  # noqa: BLE001
        _log.warning("adverse-refresh providers failed: %r", exc)
        raw = ()
    near = filter_events_near_route(
        raw, slice_route, max_distance_km=payload.max_distance_km,
    )
    # Same "serious hazards only" filter as /plan — keep the two
    # endpoints consistent so the driver never sees a mid-drive
    # notification for an event type the plan screen would have
    # hidden.
    _SERIOUS = {
        AdverseEventType.FIRE,
        AdverseEventType.WEATHER,
        AdverseEventType.FLOOD,
        AdverseEventType.SNOW,
        AdverseEventType.EARTHQUAKE,
        AdverseEventType.LANDSLIDE,
        AdverseEventType.AVALANCHE,
        AdverseEventType.HEATWAVE,
        AdverseEventType.ACCIDENT,
        AdverseEventType.CLOSURE,
    }
    events_out = [
        AdverseEventOut(
            id=e.id,
            type=e.type,
            severity=e.severity,
            source=e.source.value,
            description=e.description,
            reported_at=e.reported_at,
            expires_at=e.expires_at,
            lat=e.coordinate.lat,
            lon=e.coordinate.lon,
            country=e.country,
        )
        for e in near
        if e.type in _SERIOUS
        and e.severity != AdverseEventSeverity.INFO
    ]
    return AdverseRefreshResponse(
        events=events_out,
        sliced_from_km=from_km,
        sliced_to_km=to_km,
        sliced_distance_km=dist_km,
    )


class WeatherHazardsCoord(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)
    km_ahead: float | None = Field(
        default=None, ge=0.0,
        description="Optional km-ahead-of-driver label for UI ETA.",
    )


class WeatherHazardsRequest(BaseModel):
    """Companion-mode live weather-hazards probe.

    Given 5-10 sample coords along the driver's next ~200 km, returns
    a typed list of imminent weather hazards (heavy rain, thunder,
    snow, hail, high wind, dense fog, freezing rain). Combines two
    signals — Open-Meteo hourly forecast for typing + RainViewer
    live radar for real-time confirmation of precipitation types.

    Called on the same 15-min poll as `/adverse-refresh`; the two
    feed the Companion drive screen with complementary alerts.
    """
    coords: list[WeatherHazardsCoord] = Field(
        min_length=1, max_length=10,
        description="Sample points along the next 200 km of the route.",
    )


class WeatherHazardOut(BaseModel):
    """One typed hazard forecast (or radar-confirmed observation).

    `type` mirrors backend `AdverseEventType` snake_case values
    (heavy_rain, hail, thunderstorm, high_wind, dense_fog,
    freezing_rain, snow).
    """
    type: str
    severity: str
    lat: float
    lon: float
    eta_km_ahead: float | None = None
    description: str
    radar_confirmed: bool


class WeatherHazardsResponse(BaseModel):
    hazards: list[WeatherHazardOut]


@router.post(
    "/weather-hazards-check", response_model=WeatherHazardsResponse,
)
async def weather_hazards_check(
    payload: WeatherHazardsRequest,
) -> WeatherHazardsResponse:
    """Live probe for weather hazards ahead of the driver.

    Best-effort: any provider failure returns an empty list so the
    client never surfaces a false positive. Coverage caveat —
    RainViewer only covers Europe + North America; outside that
    footprint we still return Open-Meteo-only alerts (radar
    `radar_confirmed=False`).
    """
    # Local import — pulls Pillow lazily so a missing wheel does not
    # break the app boot; the radar module itself falls back to a
    # size-heuristic if PIL is not importable.
    from app.services.weather_hazards import check as check_hazards

    coords = [(c.lat, c.lon) for c in payload.coords]
    km_ahead = [c.km_ahead if c.km_ahead is not None else 0.0 for c in payload.coords]
    try:
        hazards = await asyncio.wait_for(
            check_hazards(coords, km_ahead=km_ahead), timeout=10.0,
        )
    except (asyncio.TimeoutError, Exception) as exc:  # noqa: BLE001
        _log.warning("weather-hazards-check failed: %r", exc)
        return WeatherHazardsResponse(hazards=[])
    return WeatherHazardsResponse(
        hazards=[
            WeatherHazardOut(
                type=h.type,
                severity=h.severity,
                lat=h.lat,
                lon=h.lon,
                eta_km_ahead=h.eta_km_ahead,
                description=h.description,
                radar_confirmed=h.radar_confirmed,
            )
            for h in hazards
        ]
    )


def _minutes(delta: timedelta) -> float:
    return round(delta.total_seconds() / 60.0, 1)


def _coord_at_km_route(route: Route, km: float) -> Coordinate | None:
    """Interpolate a coordinate along the route's polyline at
    approximately `km` from origin. Cheap linear pick — matches
    what `day_plan._coord_at_km` does client-side and downstream.
    Used by the hotel-densification pass to seed nearby hotels
    around each middle-day sleep boundary the day plan will
    interpolate at.
    """
    if not route.geometry or route.distance_km <= 0:
        return None
    fraction = max(0.0, min(1.0, km / route.distance_km))
    idx = int(fraction * (len(route.geometry) - 1))
    return route.geometry[idx]

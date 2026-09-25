from __future__ import annotations

import asyncio
import logging
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.api.premium import is_premium

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
    TravelPace,
    Trip,
    TripProfile,
    Vehicle,
    VehicleType,
    Waypoint,
)
from app.domain.entities import Route
from app.providers import get_providers
from app.providers.factory import Providers
from app.providers.google_places import GooglePlacesEnricher
from app.providers.here_places import HerePlacesEnricher
from app.services.adverse_events_filter import filter_events_near_route
from app.services.day_plan import compute as compute_day_plan
from app.services.fuel_cost import FuelCostEstimate, estimate as estimate_fuel
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
from app.services.trip_optimizations import compute as compute_optimizations
from app.services.trip_style import derive_scope as derive_style_scope

router = APIRouter(prefix="/trips", tags=["trips"])


class CoordinateIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


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
    break_style: BreakStyle = BreakStyle.SCENIC

    def to_domain(self) -> TripProfile:
        return TripProfile(
            travellers=self.travellers,
            has_kids=self.has_kids,
            has_pets=self.has_pets,
            vehicle=Vehicle(
                type=self.vehicle.type,
                fuel_type=self.vehicle.fuel_type,
                consumption_l_per_100km=self.vehicle.consumption_l_per_100km,
                consumption_kwh_per_100km=self.vehicle.consumption_kwh_per_100km,
                fuel_tank_l=self.vehicle.fuel_tank_l,
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


class ConsistencyIssueOut(BaseModel):
    code: str
    severity: str
    message: str


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


def _providers() -> Providers:
    return get_providers()


@router.post("/plan", response_model=TripPlanResponse)
async def plan_trip(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
    premium: bool = Depends(is_premium),
) -> TripPlanResponse:
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
    origin = Coordinate(lat=payload.origin.lat, lon=payload.origin.lon)
    destination = Coordinate(lat=payload.destination.lat, lon=payload.destination.lon)
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
    countries_override = tuple(payload.countries) if payload.countries else None
    profile = payload.trip_profile.to_domain() if payload.trip_profile else None
    route = await providers.routing.route(
        origin, destination, countries_override,
        waypoints=waypoints,
        avoid_motorways=payload.avoid_motorways,
        prefer_scenic=payload.prefer_scenic,
    )

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

    # Fuel type from profile (used in the parallel fetch below).
    _fuel_type = None
    if profile is not None and profile.vehicle is not None:
        ft = getattr(profile.vehicle, "fuel_type", None)
        _fuel_type = ft.value if ft is not None else None

    # Toll pricing, time windows, and fuel fetch are all independent
    # after route computation — run them in parallel.
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
    _fuel_coro = providers.fuel.prices_along(route, fuel_type=_fuel_type)
    _quote, windows, fuel = await asyncio.gather(
        _tolls_coro, _windows_coro, _fuel_coro,
    )
    real_tolls = None
    if _quote is not None:
        real_tolls = _quote.tolls
        route = _dc_replace(route, toll_cost_eur=round(_quote.total_eur, 2))
    trip = Trip(
        origin=origin,
        destination=destination,
        desired_departure_at=payload.desired_departure_at,
        countries=route.countries_crossed,
    )
    # Effective departure: the recommended window when we have one,
    # else the user's original desired time. This anchor drives BOTH
    # `compute_optimizations` (meal / sleep clocks) AND the
    # consistency check (arrival timestamp). They MUST match — an
    # earlier version used the recommended anchor for opts but the
    # desired anchor for the consistency check, producing a spurious
    # "breakfast at 07:03 but trip ends at 03:37" error on
    # multi-day trips where windows[0] shifted by hours.
    effective_departure_at = (
        windows[0].departure_at if windows else payload.desired_departure_at
    )
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
    _trip_hours = route.free_flow_duration.total_seconds() / 3600.0
    _cap_hours = float(
        getattr(profile, "daily_driving_cap_hours", 8) or 8,
    ) if profile is not None else 24.0
    _wake_hour = (
        getattr(profile, "wake_hour", 8) if profile is not None else 0
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

    all_hotels_cache = None  # avoid re-hitting provider for optimizations
    hotels_out: list[HotelOut] = []
    # Effective hotel filter: the caller's explicit value wins. When
    # `requires_overnight` is true and no explicit filter was set, we
    # auto-populate with a 25 min detour / any band default — the user
    # asked us to plan an overnight, so quietly forcing a fetch is the
    # helpful move.
    effective_hotel_detour = payload.hotel_max_detour_minutes
    if (not effective_hotel_detour or effective_hotel_detour <= 0) and \
            scope_out is not None and scope_out.requires_overnight:
        effective_hotel_detour = 25
    if effective_hotel_detour and effective_hotel_detour > 0:
        _hotel_kwargs: dict = {}
        if payload.hotel_include_other:
            _hotel_kwargs["include_other"] = True
        if payload.hotel_conditions:
            _hotel_kwargs["conditions"] = payload.hotel_conditions
        try:
            all_hotels_cache = await providers.hotels.hotels_along(
                route, **_hotel_kwargs,
            )
        except TypeError:
            all_hotels_cache = await providers.hotels.hotels_along(route)
        filtered = filter_hotels(
            all_hotels_cache,
            max_detour_minutes=float(effective_hotel_detour),
            price_band=payload.hotel_price_band or PriceBand.ANY,
            price_bands=payload.hotel_price_bands,
            profile=profile,
            min_stars=payload.hotel_min_stars,
        )
        # Enrich the top 30 hotels with Google Places data — adds
        # `rating`, `rating_count` and `google_maps_url` so the
        # mobile "Open in Maps" button lands on the exact Google
        # Place page. Silent no-op if the key is missing or the
        # API errors — filtered list ships unchanged.
        try:
            _h_enricher = GooglePlacesEnricher()
            _h_head, _h_tail = filtered[:30], filtered[30:]
            _h_enriched = await _h_enricher.enrich_hotels(tuple(_h_head))
            filtered = tuple(_h_enriched) + tuple(_h_tail)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Google Places hotel enrichment failed: %r", exc)
        # HERE Places: canonical name + verified address on top of
        # the Google rating we just added. Improves Booking /
        # Google Maps deep-link accuracy for the top hotels. Same
        # 30-hotel cap — HERE's free tier easily covers it.
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

    all_restaurants_cache = None
    restaurants_out: list[RestaurantOut] = []
    if (
        payload.restaurant_max_detour_minutes
        and payload.restaurant_max_detour_minutes > 0
    ):
        _rest_kwargs: dict = {}
        if payload.restaurant_conditions:
            _rest_kwargs["conditions"] = payload.restaurant_conditions
        try:
            all_restaurants_cache = await providers.restaurants.restaurants_along(
                route, **_rest_kwargs,
            )
        except TypeError:
            all_restaurants_cache = await providers.restaurants.restaurants_along(route)
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
        # Enrich with Google Places rating + review count. Cap at
        # the top 30 to keep the free-tier ($200/mo credit) safe
        # even under heavy beta usage. Silent no-op if the key is
        # missing (local dev) or the API errors — the response
        # still ships without the rating chip.
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

    rest_stops_out = [
        RestStopOut(
            distance_from_origin_km=s.distance_from_origin_km,
            cumulative_driving_hours=s.cumulative_driving_hours,
            recommended_break_minutes=s.recommended_break_minutes,
            lat=s.coordinate.lat,
            lon=s.coordinate.lon,
        )
        for s in compute_rest_stops(route)
    ]

    toll_alternative_out: TollAlternativeOut | None = None
    alt_route_domain = None
    if (
        payload.include_toll_alternative or payload.include_hourly_toll_analysis
    ) and route.toll_cost_eur > 0:
        alt_route_domain = await providers.routing.route(
            origin, destination, route.countries_crossed, avoid_tolls=True,
        )
    partial_skips_out: list[PartialTollSkipOut] = []
    if payload.include_toll_alternative and route.toll_cost_eur > 0:
        for skip in compute_partial_skips(route, real_tolls=real_tolls):
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

    # Trip optimizations — always computed when a profile is provided (the
    # user opted-in by sharing the profile). Cheap; no external calls.
    optimizations_out: OptimizationsOut | None = None
    opt_domain = None
    fuel_cost_domain = None
    fuel_prices_domain: tuple = ()
    _origin_label: str | None = None
    _dest_label: str | None = None
    if profile is not None:
        # Meal stops (with or without a picked restaurant) live
        # under the "Añadir restaurantes en la ruta" toggle — the
        # driver who explicitly opted OUT of restaurant search
        # doesn't expect a "próxima parada · comida" recommendation.
        # Gate the whole meal-stop computation on that toggle so
        # the response is consistent with the request scope.
        restaurants_requested = bool(
            payload.restaurant_max_detour_minutes
            and payload.restaurant_max_detour_minutes > 0
        )
        # Same gating for hotels — if the user didn't tick
        # "Añadir hoteles en la ruta", skip the fetch entirely.
        # The sleep_stop selection still runs but with an empty
        # hotel pool (surfaces the rest area + time without a
        # hotel name), and the day-view hotel sections stay
        # collapsed on the frontend via `showHotelSections`.
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
        # Widened from 25 → 45 min (2026-08-25): overnight is
        # high-stakes and drivers accept a bigger off-corridor
        # detour to sleep in a real hotel. The narrow 25 min window
        # returned an empty hotel pool for long trips where hotels
        # cluster in cities a bit off the direct road, so the
        # promoted "Dormirás en X" card was rendering with
        # hotel_name = null even when good options existed.
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
            rest_stops=compute_rest_stops(route),
            restaurants_by_slot=restaurants_by_slot,
            hotels=filtered_hotels_for_sleep,
            profile=profile,
            include_meal_stops=restaurants_requested,
        )
        # Targeted densification: when the corridor-wide POI pass
        # gave us a meal stop with no restaurant within 25 km
        # (`_closest_restaurant` returned None), the pool is sparse
        # in that specific area — likely because a big-city cluster
        # elsewhere in the chunk filled Nominatim's `limit=40`.
        # Fire a tiny point-radius search around the picked stop
        # so a lunch at km 365 gets a real local option instead of
        # falling back to a Zurich café or no name at all. Same
        # for the sleep-stop hotel. Both are opt-in via
        # `getattr(..., None)` so mock providers (used in tests)
        # keep working without adding the method.
        near_restaurants = getattr(
            providers.restaurants, "restaurants_near", None,
        )
        densified_restaurants: list = []
        if near_restaurants is not None:
            patched_meals: list = []
            # Names already assigned so back-to-back snapped meals
            # at the same hotel spot get different densified hits.
            used_meal_names: set[str] = {
                m.restaurant.name
                for m in opt.meal_stops if m.restaurant is not None
            }
            for m in opt.meal_stops:
                if m.restaurant is None:
                    hits = await near_restaurants(
                        m.rest_stop.coordinate, 25.0,
                    )
                    densified_restaurants.extend(hits)
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
        # Only densify when the user actually asked for hotels;
        # otherwise even a densification pass would leak hotel
        # names into a response the driver didn't request.
        if near_hotels is not None and hotels_requested:
            # Fill EVERY overnight's hotel when the corridor pass
            # returned nothing. Historically only `sleep_stop`
            # (=first-day only) was densified, so middle days of a
            # 3+-day trip lost their hotel candidates. Now we walk
            # `sleep_stops` and query around each one; the first-
            # day fill is a special case that also patches the
            # legacy `sleep_stop` field so downstream schema code
            # still sees the same value.
            for i, s in enumerate(opt.sleep_stops):
                if s.hotel is not None:
                    continue
                hits = await near_hotels(s.rest_stop.coordinate, 40.0)
                if not hits:
                    continue
                densified_hotels.extend(hits)
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
            # Densify around EVERY distinct sleep/meal spot in the
            # plan so per-day "HOTELES CERCA DEL PUNTO DE
            # PERNOCTA" lists always have local candidates —
            # even when the corridor pass returned plenty but
            # they cluster at the destination city. Dedup coords
            # to avoid firing the same query for lunch + dinner
            # + next-day breakfast that all share the day-sleep
            # rest_stop.
            seen_coords: set[tuple[float, float]] = set()
            # Always densify around the DESTINATION so single-day
            # trips and the last day of multi-day trips have
            # nearby hotel candidates even when the corridor-wide
            # search is skewed to the origin.
            dest_coord = Coordinate(
                lat=payload.destination.lat,
                lon=payload.destination.lon,
            )
            dest_key = (
                round(dest_coord.lat, 3),
                round(dest_coord.lon, 3),
            )
            seen_coords.add(dest_key)
            # User can widen the destination pool via
            # `hotel_destination_radius_km` — helpful in rural
            # destinations where 40 km returns only a handful.
            dest_radius = (
                payload.hotel_destination_radius_km
                if payload.hotel_destination_radius_km is not None
                else 40.0
            )
            dest_hits = await near_hotels(dest_coord, dest_radius)
            densified_hotels.extend(dest_hits)
            # Always seed nearby hotels around EVERY overnight so
            # the day-view "Hotels near your stop" scroller for
            # day 2 / day 3 has local options. Corridor pass may
            # miss middle-day sleep towns entirely.
            for s in opt.sleep_stops:
                key = (
                    round(s.rest_stop.coordinate.lat, 3),
                    round(s.rest_stop.coordinate.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                hits = await near_hotels(s.rest_stop.coordinate, 40.0)
                densified_hotels.extend(hits)
            # Densify around EVERY middle-day sleep coord that the
            # mobile day-plan renderer will actually filter by.
            # Precompute the multi-day plan here (same call the
            # response uses further down) so the coords are the
            # canonical ones — not a re-projection that drifts by
            # ~40 km once day 1 consumes an opt_sleep at a real
            # rest area instead of the raw cap-boundary.
            if profile is not None:
                _preview_multiday = compute_day_plan(
                    departure_at=effective_departure_at,
                    trip_duration_hours=(
                        route.free_flow_duration.total_seconds() / 3600.0
                    ),
                    profile=profile,
                    optimizations=opt,
                    rest_stops=compute_rest_stops(route),
                    route_distance_km=route.distance_km,
                    route=route,
                )
                _preview_days = (
                    _preview_multiday.days if _preview_multiday
                    else ()
                )
            else:
                _preview_days = ()
            # Densify around user-specified dwell waypoints — the
            # driver has committed to sleeping N nights here, so we
            # push harder (30 km radius, always fire) than the
            # middle-day heuristic below.
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
            # Track raw hits per middle-day sleep coord so we can
            # safety-net after the strict filter_hotels pass below.
            _middle_day_hits: dict[tuple[float, float], list] = {}
            for _d in _preview_days:
                # Last day sleeps at destination (already densified
                # above with `dest_radius`) — skip. Only middle-day
                # overnights need this extra pass.
                if _d.sleep_coord is None:
                    continue
                key = (
                    round(_d.sleep_coord.lat, 3),
                    round(_d.sleep_coord.lon, 3),
                )
                if key in seen_coords:
                    continue
                seen_coords.add(key)
                # 60 km matches the mobile-side `_hotelsNear` cap so
                # any hit surfaced here is guaranteed to pass the
                # client filter. Zones like interior Iberia return
                # < 5 hotels at 40 km — a wider probe keeps middle-
                # day cards populated. Try 60 first, expand to 90
                # if empty.
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
        # Merge densified POIs into the flat output lists so the
        # day-view sections and hotel/restaurant scrollers surface
        # them even when the corridor pass returned empty (typical
        # under Nominatim 429). Dedup by name+lat since the pool
        # might have overlap with the corridor pass.
        _seen_hotels = {(h.name, round(h.lat, 4), round(h.lon, 4))
                        for h in hotels_out}
        # Reuse `filter_hotels` on the densified pool so the same
        # min_stars / price_bands / detour cap that gated the
        # corridor list also gates the point-radius additions.
        # Testers reported hostels + 2-star places sneaking into
        # a "4+ stars" result because this merge bypassed the
        # filter. Detour cap unbounded here since the densifier's
        # radius already scoped the results geographically.
        _densified_filtered = filter_hotels(
            tuple(densified_hotels),
            max_detour_minutes=1e9,
            price_band=payload.hotel_price_band or PriceBand.ANY,
            price_bands=payload.hotel_price_bands,
            profile=profile,
            min_stars=payload.hotel_min_stars,
        )
        # Safety-net for middle-day sleep coords: if the strict
        # filter (min_stars / price_bands) erased everything for a
        # given overnight, re-inject up to 5 raw hits from that
        # sleep area so the day card doesn't render empty. Better
        # to show a hostel outside the user's stars filter than an
        # empty section — testers pointed this out repeatedly for
        # multi-day trips through rural regions.
        try:
            _kept_coords = {
                (round(h.coordinate.lat, 2), round(h.coordinate.lon, 2))
                for h in _densified_filtered
            }
            _extra_middle: list = []
            for key, raw in _middle_day_hits.items():
                # Check if any filtered hotel is within ~1° of the
                # sleep_coord (very loose — we just want to know if
                # SOMETHING landed nearby). If not, inject raw.
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
        _seen_rest = {(r.name, round(r.lat, 4), round(r.lon, 4))
                      for r in restaurants_out}
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
        # Route to charging stations for electric vehicles (same
        # rationale as the earlier `prices_along` call at the top
        # of the endpoint).
        _fuel_type_inner = None
        if profile.vehicle is not None:
            ft = getattr(profile.vehicle, "fuel_type", None)
            _fuel_type_inner = ft.value if ft is not None else None
        fuel = await providers.fuel.prices_along(
            route, fuel_type=_fuel_type_inner,
        )
        cost = estimate_fuel(route, profile.vehicle, fuel)
        fuel_cost_domain = cost
        fuel_prices_domain = fuel
        # Reverse-geocode every meal + sleep coord to a city hint
        # so the mobile can render "Cerca de X" per row. Concurrent
        # gather bounded by asyncio; cache TTL lives inside the
        # geocoding provider so re-plans on the same corridor cost
        # nothing. Silent no-op when the geocoder has no `reverse`
        # method (mock provider in some tests).
        async def _city(coord) -> str | None:
            reverse = getattr(providers.geocoding, "reverse", None)
            if reverse is None or coord is None:
                return None
            try:
                r = await reverse(coord.lat, coord.lon)
                if r is None:
                    return None
                # Prefer the shortest first token of the display name
                # ("Toledo, Toledo, Castilla-La Mancha, España" →
                # "Toledo").
                return r.display_name.split(",")[0].strip() or None
            except Exception:  # noqa: BLE001
                return None

        meal_city_hints = await asyncio.gather(*(
            _city(m.rest_stop.coordinate) for m in opt.meal_stops
        ))
        # Lookup dict keyed by distance so day-plan meal stops (which
        # are the same stops, just sliced per day) can reuse hints
        # without a second round of reverse-geocode calls.
        _meal_hint_by_km: dict[float, str | None] = {
            m.rest_stop.distance_from_origin_km: meal_city_hints[i]
            for i, m in enumerate(opt.meal_stops)
        }
        sleep_city_hint = await _city(
            opt.sleep_stop.rest_stop.coordinate
            if opt.sleep_stop is not None else None
        )
        # Reverse-geocode origin + destination for day-plan headers.
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

    # Destination densification for trips WITHOUT a profile — the
    # profile-gated block above already does this, but users who
    # skip profile creation and just toggle "hotels" on still need
    # hotels near their destination. Without this the corridor pass
    # clusters results near the origin and the destination section
    # renders empty.
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
            # Same filter guard as the profile-branch densifier
            # above — otherwise `hotel_min_stars=4` still leaks
            # 2-star places at the destination.
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

    # Only surface genuine safety hazards — roadworks, strikes and
    # protests are inconvenient but not dangerous; INFO-level events
    # are informational noise that clutters the alert card.
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
    if payload.include_adverse_events:
        now = datetime.now(timezone.utc)
        all_events = await providers.adverse_events.events_along(route, now=now)
        near = filter_events_near_route(
            all_events, route, max_distance_km=payload.adverse_events_max_distance_km,
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

    variants_out: list[RouteVariantOut] = []
    if payload.include_route_comparison:
        variants = await compute_variants(
            provider=providers.routing, primary=route,
            origin=origin, destination=destination,
            countries=route.countries_crossed,
        )
        variants_out = [
            RouteVariantOut(
                key=v.key, label=v.label,
                distance_km=v.route.distance_km,
                free_flow_minutes=_minutes(v.route.free_flow_duration),
                toll_cost_eur=v.route.toll_cost_eur,
            )
            for v in variants
        ]

    simplified = simplify_polyline(route.geometry, epsilon_km=0.2)
    savings = SavingsSummaryOut(
        time_saved_minutes_vs_desired=minutes_saved_vs_desired(
            windows, payload.desired_departure_at,
        ),
        money_saved_eur_vs_tolls=(
            toll_alternative_out.savings_eur
            if toll_alternative_out is not None and toll_alternative_out.worth_it
            else 0.0
        ),
    )
    consistency_out = [
        ConsistencyIssueOut(
            code=i.code, severity=i.severity.value, message=i.message,
        )
        for i in check_trip_consistency(
            departure_at=effective_departure_at,
            arrival_at=effective_arrival_at,
            optimizations=opt_domain,
            route=route,
            fuel_cost=fuel_cost_domain,
            fuel_prices=fuel_prices_domain,
        )
    ]

    # --- Fuel savings analysis ---
    # Stamp per-station savings on the FuelPrice objects, then curate
    # the list (dedupe near-duplicates, keep at-or-below median only,
    # cap per country + overall). Arbitrage looks at the ORIGINAL raw
    # list so per-country medians aren't skewed by our filter.
    vehicle_for_savings = profile.vehicle if profile is not None else None
    arbitrage_domain = compute_fuel_arbitrage(
        fuel, vehicle=vehicle_for_savings,
    )
    fuel = curate_fuel_stations(
        stamp_fuel_savings(fuel, vehicle=vehicle_for_savings),
    )
    arbitrage_out = None if arbitrage_domain is None else FuelArbitrageOut(
        cheaper_country=arbitrage_domain.cheaper_country,
        cheaper_median_eur_per_l=arbitrage_domain.cheaper_median_eur_per_l,
        pricier_country=arbitrage_domain.pricier_country,
        pricier_median_eur_per_l=arbitrage_domain.pricier_median_eur_per_l,
        delta_eur_per_l=arbitrage_domain.delta_eur_per_l,
        estimated_tank_saving_eur=arbitrage_domain.estimated_tank_saving_eur,
    )

    # --- Multi-day breakdown ---
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
            # Same anchor as `compute_optimizations` above — anything
            # else desynchronises day boundaries from meal times.
            departure_at=effective_departure_at,
            trip_duration_hours=(
                route.free_flow_duration.total_seconds() / 3600.0
            ),
            profile=profile,
            optimizations=opt_domain,
            rest_stops=compute_rest_stops(route),
            route_distance_km=route.distance_km,
            route=route,
            waypoints=dwell_waypoints,
            origin_label=_origin_label,
            destination_label=_dest_label,
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
            # Reverse-geocode overnight sleep coords for intermediate
            # days that lack a label (regular algorithm stops, not user
            # waypoints). Fills the "Día 1 → <sleep city>" header gap.
            _n = len(multiday.days)
            _sleep_city: list[str | None] = [None] * _n
            _missing = [
                (i, d) for i, d in enumerate(multiday.days)
                if d.sleep_at is not None
                and d.to_name is None
                and d.sleep_coord is not None
            ]
            if _missing:
                _geocoded = await asyncio.gather(*(
                    _city(d.sleep_coord) for _, d in _missing
                ))
                for (i, _), city in zip(_missing, _geocoded):
                    _sleep_city[i] = city
            for d in multiday.days:
                _i = d.day_index - 1  # 0-based
                # Fill to_name from sleep geocode when not already set
                _to_name = d.to_name or (
                    _sleep_city[_i] if d.sleep_at is not None else None
                )
                # Fill from_name from previous day's sleep geocode
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

    # Weather summary — Open-Meteo forecast at 5 points along the
    # route for the expected arrival time at each point. Free, no
    # key, adds ~1-2s. Fires regardless of profile (everyone wants
    # to know if it'll rain).
    from app.services.weather_summary import weather_along_route
    try:
        weather_raw = await weather_along_route(
            route, effective_departure_at,
        )
    except Exception:
        weather_raw = ()

    parkings_out: list[ParkingOutTrip] = []
    if payload.include_parking:
        try:
            from app.providers.parking import GeoapifyParkingProvider
            parking_provider = GeoapifyParkingProvider()
            dest_coord = Coordinate(
                lat=payload.destination.lat,
                lon=payload.destination.lon,
            )
            parkings_found = await parking_provider.parking_near(
                dest_coord, radius_km=2.5,
            )
            for p in list(parkings_found)[:10]:
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
        except Exception as exc:  # noqa: BLE001
            _log.warning("Parking search failed: %r", exc)

    return TripPlanResponse(
        route=RouteOut(
            distance_km=route.distance_km,
            free_flow_minutes=_minutes(route.free_flow_duration),
            polyline=route.polyline,
            toll_cost_eur=route.toll_cost_eur,
            countries_crossed=list(route.countries_crossed),
            geometry=[[c.lon, c.lat] for c in simplified],
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
            # Drop stations without a live price — tester feedback:
            # empty rows with "€ ?" read as noise and dilute the
            # trustworthy list. EV charging stations always ship
            # regardless (they may not have per-kWh price yet).
            for fp in fuel
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
        recommendation_scope=scope_out,
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

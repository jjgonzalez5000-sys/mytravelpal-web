from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.api.premium import is_premium

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
)
from app.providers import get_providers
from app.providers.factory import Providers
from app.services.adverse_events_filter import filter_events_near_route
from app.services.fuel_cost import FuelCostEstimate, estimate as estimate_fuel
from app.services.hotel_search import filter_hotels
from app.services.hourly_toll_analysis import analyze as hourly_toll_analyze
from app.services.polyline_simplify import simplify as simplify_polyline
from app.services.rest_stops import compute_rest_stops
from app.services.restaurant_search import filter_restaurants
from app.services.time_window import compute_time_windows, minutes_saved_vs_desired
from app.services.partial_toll_skips import compute as compute_partial_skips
from app.services.route_variants import compute_variants
from app.services.toll_savings import compare as compare_toll
from dataclasses import replace as _dc_replace
from app.services.trip_optimizations import compute as compute_optimizations
from app.services.trip_style import derive_scope as derive_style_scope

router = APIRouter(prefix="/trips", tags=["trips"])


class CoordinateIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


class VehicleIn(BaseModel):
    type: VehicleType = VehicleType.CAR
    fuel_type: FuelType = FuelType.PETROL
    consumption_l_per_100km: float = Field(default=6.5, gt=0, le=40)
    consumption_kwh_per_100km: float = Field(default=18.0, gt=0, le=80)
    fuel_tank_l: float = Field(default=50.0, gt=0, le=200)
    ev_range_km: float = Field(default=350.0, gt=0, le=1200)


class MealPreferencesIn(BaseModel):
    breakfast_hour: int = Field(default=8, ge=4, le=12)
    lunch_hour: int = Field(default=13, ge=11, le=16)
    dinner_hour: int = Field(default=20, ge=17, le=23)
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
                lunch_hour=self.meals.lunch_hour,
                dinner_hour=self.meals.dinner_hour,
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
            "hotel_max_detour_minutes > 0."
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
            "Filter restaurants by price band (per person, per meal). "
            "Only applied when restaurant_max_detour_minutes > 0."
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
        default=25.0,
        gt=0.0,
        le=200.0,
        description=(
            "Maximum great-circle distance from the route for an event to "
            "be included. Only meaningful when include_adverse_events=true."
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
    avoid_motorways: bool = Field(default=False)
    prefer_scenic: bool = Field(default=False)
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
    distance_from_origin_km: float
    savings_eur: float
    time_penalty_minutes: float
    extra_distance_km: float
    worth_it: bool
    lat: float
    lon: float


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


class SleepStopOut(BaseModel):
    at: datetime
    distance_from_origin_km: float
    hotel_name: str | None
    hotel_price_eur_per_night: float | None
    hotel_lat: float | None
    hotel_lon: float | None


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
    distance_from_origin_km: float
    lat: float | None = None
    lon: float | None = None
    attributes: dict[str, str] = Field(default_factory=dict)


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


class TripPlanResponse(BaseModel):
    route: RouteOut
    time_windows: list[TimeWindowOut]
    fuel_prices: list[FuelPriceOut]
    hotels: list[HotelOut]
    restaurants: list[RestaurantOut]
    rest_stops: list[RestStopOut]
    adverse_events: list[AdverseEventOut]
    toll_alternative: TollAlternativeOut | None = None
    partial_toll_skips: list[PartialTollSkipOut] = Field(default_factory=list)
    optimizations: OptimizationsOut | None = None
    hourly_toll_report: HourlyTollReportOut | None = None
    savings: SavingsSummaryOut = Field(default_factory=lambda: SavingsSummaryOut(
        time_saved_minutes_vs_desired=0.0, money_saved_eur_vs_tolls=0.0,
    ))
    route_variants: list[RouteVariantOut] = Field(default_factory=list)
    recommendation_scope: RecommendationScopeOut | None = None


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
    countries_override = tuple(payload.countries) if payload.countries else None
    profile = payload.trip_profile.to_domain() if payload.trip_profile else None
    route = await providers.routing.route(
        origin, destination, countries_override,
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

    # Real toll pricing via TollGuru when a key is set + we have real
    # geometry to send. Replaces the heuristic toll_cost_eur and feeds
    # per-booth data into partial_toll_skips below.
    real_tolls = None
    if providers.tollguru is not None and route.geometry:
        quote = await providers.tollguru.quote(route)
        if quote is not None:
            real_tolls = quote.tolls
            route = _dc_replace(route, toll_cost_eur=round(quote.total_eur, 2))
    trip = Trip(
        origin=origin,
        destination=destination,
        desired_departure_at=payload.desired_departure_at,
        countries=route.countries_crossed,
    )
    windows = await compute_time_windows(
        route=route,
        desired_departure_at=trip.desired_departure_at,
        traffic=providers.traffic,
    )
    fuel = await providers.fuel.prices_along(route)

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
        all_hotels_cache = await providers.hotels.hotels_along(route)
        filtered = filter_hotels(
            all_hotels_cache,
            max_detour_minutes=float(effective_hotel_detour),
            price_band=payload.hotel_price_band or PriceBand.ANY,
            profile=profile,
        )
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
        all_restaurants_cache = await providers.restaurants.restaurants_along(route)
        filtered_r = filter_restaurants(
            all_restaurants_cache,
            max_detour_minutes=float(payload.restaurant_max_detour_minutes),
            price_band=payload.restaurant_price_band or PriceBand.ANY,
            profile=profile,
        )
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
                    distance_from_origin_km=skip.distance_from_origin_km,
                    savings_eur=skip.savings_eur,
                    time_penalty_minutes=skip.time_penalty_minutes,
                    extra_distance_km=skip.extra_distance_km,
                    worth_it=skip.worth_it,
                    lat=skip.coordinate.lat,
                    lon=skip.coordinate.lon,
                )
            )

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
    if profile is not None:
        # Ensure we have hotels + restaurants to draw from.
        opti_hotels = all_hotels_cache or await providers.hotels.hotels_along(route)
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
        filtered_hotels_for_sleep = filter_hotels(
            opti_hotels,
            max_detour_minutes=25.0,
            price_band=PriceBand.ANY,
            profile=profile,
            limit=15,
        )
        opt = compute_optimizations(
            departure_at=payload.desired_departure_at,
            trip_duration_hours=route.free_flow_duration.total_seconds() / 3600.0,
            rest_stops=compute_rest_stops(route),
            restaurants_by_slot=restaurants_by_slot,
            hotels=filtered_hotels_for_sleep,
            profile=profile,
        )
        fuel = await providers.fuel.prices_along(route)
        cost = estimate_fuel(route, profile.vehicle, fuel)
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
                )
                for m in opt.meal_stops
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
                distance_from_origin_km=fp.distance_from_origin_km,
                lat=fp.coordinate.lat if fp.coordinate is not None else None,
                lon=fp.coordinate.lon if fp.coordinate is not None else None,
                attributes=dict(fp.attributes),
            )
            for fp in fuel
        ],
        hotels=hotels_out,
        restaurants=restaurants_out,
        rest_stops=rest_stops_out,
        adverse_events=adverse_events_out,
        toll_alternative=toll_alternative_out,
        partial_toll_skips=partial_skips_out,
        optimizations=optimizations_out,
        hourly_toll_report=hourly_toll_out,
        savings=savings,
        route_variants=variants_out,
        recommendation_scope=scope_out,
    )


def _minutes(delta: timedelta) -> float:
    return round(delta.total_seconds() / 60.0, 1)

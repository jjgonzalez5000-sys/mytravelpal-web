from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.domain import (
    AdverseEventSeverity,
    AdverseEventType,
    Coordinate,
    Country,
    FuelType,
    MealPreferences,
    MealSlot,
    PriceBand,
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
from app.services.time_window import compute_time_windows
from app.services.toll_savings import compare as compare_toll
from app.services.trip_optimizations import compute as compute_optimizations

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


class HotelOut(BaseModel):
    name: str
    country: Country
    price_eur_per_night: float
    price_band: PriceBand
    detour_minutes: float
    distance_from_route_km: float
    lat: float
    lon: float


class RestaurantOut(BaseModel):
    name: str
    country: Country
    price_eur_per_meal: float
    price_band: PriceBand
    detour_minutes: float
    distance_from_route_km: float
    lat: float
    lon: float


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


class TripPlanResponse(BaseModel):
    route: RouteOut
    time_windows: list[TimeWindowOut]
    fuel_prices: list[FuelPriceOut]
    hotels: list[HotelOut]
    restaurants: list[RestaurantOut]
    rest_stops: list[RestStopOut]
    adverse_events: list[AdverseEventOut]
    toll_alternative: TollAlternativeOut | None = None
    optimizations: OptimizationsOut | None = None
    hourly_toll_report: HourlyTollReportOut | None = None


def _providers() -> Providers:
    return get_providers()


@router.post("/plan", response_model=TripPlanResponse)
async def plan_trip(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
) -> TripPlanResponse:
    origin = Coordinate(lat=payload.origin.lat, lon=payload.origin.lon)
    destination = Coordinate(lat=payload.destination.lat, lon=payload.destination.lon)
    countries_override = tuple(payload.countries) if payload.countries else None
    profile = payload.trip_profile.to_domain() if payload.trip_profile else None
    route = await providers.routing.route(
        origin, destination, countries_override,
        avoid_motorways=payload.avoid_motorways,
        prefer_scenic=payload.prefer_scenic,
    )
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
    if payload.hotel_max_detour_minutes and payload.hotel_max_detour_minutes > 0:
        all_hotels_cache = await providers.hotels.hotels_along(route)
        filtered = filter_hotels(
            all_hotels_cache,
            max_detour_minutes=float(payload.hotel_max_detour_minutes),
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

    simplified = simplify_polyline(route.geometry, epsilon_km=0.2)
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
            )
            for fp in fuel
        ],
        hotels=hotels_out,
        restaurants=restaurants_out,
        rest_stops=rest_stops_out,
        adverse_events=adverse_events_out,
        toll_alternative=toll_alternative_out,
        optimizations=optimizations_out,
        hourly_toll_report=hourly_toll_out,
    )


def _minutes(delta: timedelta) -> float:
    return round(delta.total_seconds() / 60.0, 1)

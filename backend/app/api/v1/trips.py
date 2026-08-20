from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.domain import (
    AdverseEventSeverity,
    AdverseEventType,
    Coordinate,
    Country,
    PriceBand,
    Trip,
)
from app.providers import get_providers
from app.providers.factory import Providers
from app.services.adverse_events_filter import filter_events_near_route
from app.services.hotel_search import filter_hotels
from app.services.rest_stops import compute_rest_stops
from app.services.restaurant_search import filter_restaurants
from app.services.time_window import compute_time_windows

router = APIRouter(prefix="/trips", tags=["trips"])


class CoordinateIn(BaseModel):
    lat: float = Field(ge=-90.0, le=90.0)
    lon: float = Field(ge=-180.0, le=180.0)


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


class RouteOut(BaseModel):
    distance_km: float
    free_flow_minutes: float
    polyline: str
    toll_cost_eur: float
    countries_crossed: list[Country]


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
    route = await providers.routing.route(origin, destination, countries_override)
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

    hotels_out: list[HotelOut] = []
    if payload.hotel_max_detour_minutes and payload.hotel_max_detour_minutes > 0:
        all_hotels = await providers.hotels.hotels_along(route)
        filtered = filter_hotels(
            all_hotels,
            max_detour_minutes=float(payload.hotel_max_detour_minutes),
            price_band=payload.hotel_price_band or PriceBand.ANY,
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

    restaurants_out: list[RestaurantOut] = []
    if (
        payload.restaurant_max_detour_minutes
        and payload.restaurant_max_detour_minutes > 0
    ):
        all_restaurants = await providers.restaurants.restaurants_along(route)
        filtered_r = filter_restaurants(
            all_restaurants,
            max_detour_minutes=float(payload.restaurant_max_detour_minutes),
            price_band=payload.restaurant_price_band or PriceBand.ANY,
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

    return TripPlanResponse(
        route=RouteOut(
            distance_km=route.distance_km,
            free_flow_minutes=_minutes(route.free_flow_duration),
            polyline=route.polyline,
            toll_cost_eur=route.toll_cost_eur,
            countries_crossed=list(route.countries_crossed),
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
    )


def _minutes(delta: timedelta) -> float:
    return round(delta.total_seconds() / 60.0, 1)

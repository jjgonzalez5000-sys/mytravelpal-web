from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.domain import Coordinate, Country, Trip
from app.providers import get_providers
from app.providers.factory import Providers
from app.services.country_detection import infer_countries_crossed
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


class TripPlanResponse(BaseModel):
    route: RouteOut
    time_windows: list[TimeWindowOut]
    fuel_prices: list[FuelPriceOut]


def _providers() -> Providers:
    return get_providers()


@router.post("/plan", response_model=TripPlanResponse)
async def plan_trip(
    payload: TripPlanRequest,
    providers: Providers = Depends(_providers),
) -> TripPlanResponse:
    origin = Coordinate(lat=payload.origin.lat, lon=payload.origin.lon)
    destination = Coordinate(lat=payload.destination.lat, lon=payload.destination.lon)
    if payload.countries:
        countries = tuple(payload.countries)
    else:
        countries = infer_countries_crossed((origin, destination))
    trip = Trip(
        origin=origin,
        destination=destination,
        desired_departure_at=payload.desired_departure_at,
        countries=countries,
    )
    route = await providers.routing.route(trip.origin, trip.destination, trip.countries)
    windows = await compute_time_windows(
        route=route,
        desired_departure_at=trip.desired_departure_at,
        traffic=providers.traffic,
    )
    fuel = await providers.fuel.prices_along(route)

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
    )


def _minutes(delta: timedelta) -> float:
    return round(delta.total_seconds() / 60.0, 1)

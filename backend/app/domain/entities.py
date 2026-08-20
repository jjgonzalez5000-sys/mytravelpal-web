from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum


class Country(str, Enum):
    CH = "CH"
    FR = "FR"
    IT = "IT"
    ES = "ES"


@dataclass(frozen=True, slots=True)
class Coordinate:
    lat: float
    lon: float

    def __post_init__(self) -> None:
        if not -90.0 <= self.lat <= 90.0:
            raise ValueError(f"lat out of range: {self.lat}")
        if not -180.0 <= self.lon <= 180.0:
            raise ValueError(f"lon out of range: {self.lon}")


@dataclass(frozen=True, slots=True)
class Route:
    origin: Coordinate
    destination: Coordinate
    distance_km: float
    free_flow_duration: timedelta
    polyline: str
    toll_cost_eur: float
    countries_crossed: tuple[Country, ...]


@dataclass(frozen=True, slots=True)
class TimeWindow:
    departure_at: datetime
    estimated_duration: timedelta
    traffic_factor: float
    recommended: bool = False

    @property
    def arrival_at(self) -> datetime:
        return self.departure_at + self.estimated_duration


@dataclass(frozen=True, slots=True)
class Trip:
    origin: Coordinate
    destination: Coordinate
    desired_departure_at: datetime
    countries: tuple[Country, ...]


@dataclass(frozen=True, slots=True)
class TripPlan:
    trip: Trip
    route: Route
    time_windows: tuple[TimeWindow, ...]

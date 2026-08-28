from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum


class Country(str, Enum):
    # Launch four
    CH = "CH"
    FR = "FR"
    IT = "IT"
    ES = "ES"
    # Nordics
    NO = "NO"
    SE = "SE"
    DK = "DK"
    FI = "FI"
    IS = "IS"
    # Western
    DE = "DE"
    AT = "AT"
    BE = "BE"
    NL = "NL"
    LU = "LU"
    IE = "IE"
    GB = "GB"
    # Southern
    PT = "PT"
    GR = "GR"
    MT = "MT"
    CY = "CY"
    # Central / Eastern
    PL = "PL"
    CZ = "CZ"
    SK = "SK"
    HU = "HU"
    SI = "SI"
    HR = "HR"
    RO = "RO"
    BG = "BG"
    EE = "EE"
    LV = "LV"
    LT = "LT"


class VehicleType(str, Enum):
    CAR = "car"
    MOTORBIKE = "motorbike"
    VAN = "van"
    CAMPER = "camper"


class FuelType(str, Enum):
    PETROL = "petrol"
    DIESEL = "diesel"
    HYBRID = "hybrid"
    ELECTRIC = "electric"
    LPG = "lpg"


class TravelPace(str, Enum):
    """How aggressively the driver wants to eat kilometres.

    - `push` — long stretches with minimal breaks. No overnight unless
      absolutely required.
    - `steady` (default) — the natural cadence. Break if the trip
      crosses bedtime or exceeds the daily driving cap.
    - `savour` — frequent stops; viewpoints and food matter as much as
      arrival time.
    """

    PUSH = "push"
    STEADY = "steady"
    SAVOUR = "savour"


class OvernightPolicy(str, Enum):
    """When to suggest a hotel mid-trip.

    - `never` — surface hotels only when the user explicitly asks.
    - `if_needed` (default) — hotel is suggested when the trip crosses
      bedtime OR would exceed `daily_driving_cap_hours`.
    - `always_if_long` — split trips > 6 h into 2 days even when a
      single push is technically possible.
    """

    NEVER = "never"
    IF_NEEDED = "if_needed"
    ALWAYS_IF_LONG = "always_if_long"


class BreakStyle(str, Enum):
    """Flavour of rest-stop / restaurant suggestions to surface.

    - `minimal` — only when strictly necessary; service areas over
      curated stops.
    - `scenic` (default) — viewpoints, parks, small historic detours.
    - `foodie` — bias restaurant picks toward good food that aligns
      with configured meal hours.
    """

    MINIMAL = "minimal"
    SCENIC = "scenic"
    FOODIE = "foodie"


class MealSlot(str, Enum):
    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"


class AdverseEventType(str, Enum):
    FIRE = "fire"
    STRIKE = "strike"
    WEATHER = "weather"
    ACCIDENT = "accident"
    ROADWORK = "roadwork"
    FLOOD = "flood"
    SNOW = "snow"
    PROTEST = "protest"
    # Added 2026-08-28 (tester ask). Providers wire-up phased:
    # - EARTHQUAKE: USGS Earthquake Hazards feed (public, JSON).
    # - LANDSLIDE / AVALANCHE: Copernicus EMS Rapid Mapping (public
    #   but low-frequency); interim → user-marked only.
    # - CLOSURE: road closures unrelated to roadworks — feeds via
    #   national road authorities (Autopistas ES, DIRIF FR, ANAS
    #   IT). MVP: user-marked only.
    # - HEATWAVE: derived from Open-Meteo when max temp > 38 °C
    #   for ≥ 2 consecutive days on any route segment.
    EARTHQUAKE = "earthquake"
    LANDSLIDE = "landslide"
    AVALANCHE = "avalanche"
    CLOSURE = "closure"
    HEATWAVE = "heatwave"
    OTHER = "other"


class AdverseEventSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class AdverseEventSource(str, Enum):
    USER = "user"
    WEATHER = "weather"
    MOCK = "mock"
    OFFICIAL = "official"


class PriceBand(str, Enum):
    BUDGET = "budget"  # roughly < 80 €/night
    MID = "mid"        # 80 – 160 €/night
    LUX = "lux"        # > 160 €/night
    ANY = "any"        # request-side wildcard; a Hotel never carries ANY

    @classmethod
    def from_price_eur(cls, price: float) -> PriceBand:
        if price < 80:
            return cls.BUDGET
        if price <= 160:
            return cls.MID
        return cls.LUX


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
    waypoints: tuple[Coordinate, ...] = ()
    """Ordered interpolated points from origin to destination.

    In the MVP these come from the mock routing provider's great-circle
    interpolation; a real HERE/TomTom integration will return actual
    polyline vertices along the road. Used by country-detection to spot
    intermediate countries the endpoints alone would miss.
    """
    geometry: tuple[Coordinate, ...] = ()
    """Dense polyline that follows real roads, populated by OSRM / HERE /
    TomTom providers. Empty when only the mock provider ran — in that
    case the mobile client should draw a straight-line fallback.
    """
    avoid_tolls: bool = False
    """Whether this route was computed with tolls avoided. Used by the
    toll-savings comparison to label the alternative correctly.
    """


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
class Hotel:
    name: str
    coordinate: Coordinate
    country: Country
    price_eur_per_night: float
    price_band: PriceBand
    distance_from_route_km: float
    detour_minutes: float
    kid_friendly: bool = False
    pet_friendly: bool = False
    has_parking: bool = True
    attributes: tuple[tuple[str, str], ...] = ()
    """Curated OSM tags — stars, phone, website, opening_hours,
    wheelchair, wifi, air_conditioning, breakfast, brand. Empty for
    mock entries. Stored as a tuple of pairs (rather than a dict) so
    the dataclass stays hashable / frozen.
    """


@dataclass(frozen=True, slots=True)
class Restaurant:
    name: str
    coordinate: Coordinate
    country: Country
    price_eur_per_meal: float
    price_band: PriceBand
    distance_from_route_km: float
    detour_minutes: float
    kid_friendly: bool = False
    pet_friendly: bool = False
    open_meal_slots: tuple[MealSlot, ...] = ()  # empty = we don't know
    attributes: tuple[tuple[str, str], ...] = ()
    """Curated OSM tags — cuisine, phone, website, opening_hours,
    outdoor_seating, takeaway, delivery, wheelchair, dog, brand.
    Empty for mock entries.
    """


@dataclass(frozen=True, slots=True)
class Vehicle:
    """A vehicle description used to estimate trip fuel cost and to hint
    routing / hotel-parking requirements downstream.
    """
    type: VehicleType = VehicleType.CAR
    fuel_type: FuelType = FuelType.PETROL
    consumption_l_per_100km: float = 6.5
    consumption_kwh_per_100km: float = 18.0  # for electric only
    fuel_tank_l: float = 50.0
    ev_range_km: float = 350.0


@dataclass(frozen=True, slots=True)
class MealPreferences:
    breakfast_hour: int = 8
    breakfast_minute: int = 0
    lunch_hour: int = 13
    lunch_minute: int = 0
    dinner_hour: int = 20
    dinner_minute: int = 0
    typical_stop_minutes: int = 45


@dataclass(frozen=True, slots=True)
class TripProfile:
    travellers: int = 1
    has_kids: bool = False
    has_pets: bool = False
    vehicle: Vehicle = field(default_factory=Vehicle)
    meals: MealPreferences = field(default_factory=MealPreferences)

    # -- Travel style (Sprint 22) --
    travel_pace: TravelPace = TravelPace.STEADY
    overnight_policy: OvernightPolicy = OvernightPolicy.IF_NEEDED
    daily_driving_cap_hours: int = 8
    """Hard ceiling on driving hours before the planner requires an
    overnight break. Ignored when `overnight_policy == NEVER`.
    """
    bedtime_hour: int = 22
    wake_hour: int = 8
    break_style: BreakStyle = BreakStyle.SCENIC


@dataclass(frozen=True, slots=True)
class RestStop:
    coordinate: Coordinate
    distance_from_origin_km: float
    cumulative_driving_hours: float
    recommended_break_minutes: int


@dataclass(frozen=True, slots=True)
class AdverseEvent:
    id: str
    type: AdverseEventType
    severity: AdverseEventSeverity
    source: AdverseEventSource
    coordinate: Coordinate
    description: str
    reported_at: datetime
    expires_at: datetime
    country: Country | None = None

    def is_active_at(self, when: datetime) -> bool:
        return self.reported_at <= when <= self.expires_at


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

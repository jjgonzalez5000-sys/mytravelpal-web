from __future__ import annotations

from dataclasses import dataclass

import os

from app.providers.adverse_events import (
    AdverseEventsProvider,
    CompositeAdverseEventsProvider,
    MockAdverseEventsProvider,
    UserMarkedAdverseEventsProvider,
)
from app.providers.firms import FirmsFireProvider
from app.providers.national_weather import (
    AemetWeatherProvider,
    DwdWeatherProvider,
    MetOfficeWeatherProvider,
    MeteoFranceWeatherProvider,
)
from app.providers.overpass import (
    FallbackFuelProvider,
    FallbackHotelsProvider,
    FallbackRestaurantsProvider,
    OverpassFuelProvider,
    OverpassHotelsProvider,
    OverpassRestaurantsProvider,
)
from app.providers.tollguru import TollGuruProvider, TollProvider
from app.providers.weather import OpenMeteoWeatherProvider
from app.providers.fuel import FuelProvider, MockFuelProvider
from app.providers.geocoding import (
    GeocodingProvider,
    HybridGeocodingProvider,
    MockGeocodingProvider,
    NominatimGeocodingProvider,
)
from app.providers.hotels import HotelsProvider, MockHotelsProvider
from app.providers.llm import LlmProvider, default_llm_provider
from app.providers.restaurants import MockRestaurantsProvider, RestaurantsProvider
from app.providers.routing import RoutingProvider, default_routing_provider
from app.providers.tolls import MockTollsProvider, TollsProvider
from app.providers.traffic import MockTrafficProvider, TrafficProvider


@dataclass(frozen=True, slots=True)
class Providers:
    routing: RoutingProvider
    traffic: TrafficProvider
    tolls: TollsProvider
    fuel: FuelProvider
    geocoding: GeocodingProvider
    hotels: HotelsProvider
    restaurants: RestaurantsProvider
    adverse_events: AdverseEventsProvider
    user_marked_events: UserMarkedAdverseEventsProvider
    llm: LlmProvider
    tollguru: TollProvider | None


def get_providers() -> Providers:
    """DI factory. Returns mock implementations for the MVP.

    Geocoding is hybrid: the small in-memory city catalogue handles the
    well-known launch cities instantly; anything else falls through to
    the real Nominatim service so the user can find e.g. small Swiss
    villages without us having to hand-curate every place name.
    """
    return Providers(
        routing=_ROUTING,
        traffic=MockTrafficProvider(),
        tolls=MockTollsProvider(),
        fuel=_fuel_provider(),
        geocoding=HybridGeocodingProvider(
            primary=MockGeocodingProvider(),
            fallback=NominatimGeocodingProvider(),
        ),
        hotels=_hotels_provider(),
        restaurants=_restaurants_provider(),
        adverse_events=_ADVERSE,
        user_marked_events=_USER_MARKED,
        llm=_LLM,
        tollguru=_tollguru_provider(),
    )


def _tollguru_provider() -> TollProvider | None:
    # Only expose a live client when a key is present — otherwise the
    # endpoint continues on with its heuristic pricing.
    if os.environ.get("TOLLGURU_API_KEY"):
        return TollGuruProvider()
    return None


def _hotels_provider():
    # Default: try Overpass first (real OSM data), fall back to mock
    # on empty response or timeout. Opt-out with
    # `MYTRAVELPAL_HOTELS=mock` to skip the outbound call (CI, tests).
    if os.environ.get("MYTRAVELPAL_HOTELS", "overpass").lower() == "mock":
        return MockHotelsProvider()
    return FallbackHotelsProvider(
        OverpassHotelsProvider(), MockHotelsProvider(),
    )


def _fuel_provider():
    if os.environ.get("MYTRAVELPAL_FUEL", "overpass").lower() == "mock":
        return MockFuelProvider()
    return FallbackFuelProvider(
        OverpassFuelProvider(), MockFuelProvider(),
    )


def _restaurants_provider():
    if os.environ.get("MYTRAVELPAL_RESTAURANTS", "overpass").lower() == "mock":
        return MockRestaurantsProvider()
    return FallbackRestaurantsProvider(
        OverpassRestaurantsProvider(), MockRestaurantsProvider(),
    )


# Shared singletons — user-marked events must persist across requests, and
# the composite must reference the same in-memory registry every call.
_ROUTING = default_routing_provider()
_USER_MARKED = UserMarkedAdverseEventsProvider()


def _adverse_providers() -> tuple[AdverseEventsProvider, ...]:
    # Every external provider is opt-in via env var. Off by default in
    # tests and CI (avoids network); production docker-compose enables
    # the ones we've integrated.
    providers: list[AdverseEventsProvider] = [
        MockAdverseEventsProvider(),
        _USER_MARKED,
    ]
    if os.environ.get("MYTRAVELPAL_WEATHER", "").lower() == "openmeteo":
        providers.append(OpenMeteoWeatherProvider())
    # Fires: default-on now that we're wired to a stable service
    # (NASA FIRMS via ArcGIS Living Atlas). Opt-out with
    # `MYTRAVELPAL_FIRES=off` to suppress the outbound call (CI, tests).
    if os.environ.get("MYTRAVELPAL_FIRES", "firms").lower() not in {"off", "0", "false"}:
        providers.append(FirmsFireProvider())
    # National advisory feeds — only add when their key is set.
    for cls in (AemetWeatherProvider, MeteoFranceWeatherProvider,
                DwdWeatherProvider, MetOfficeWeatherProvider):
        instance = cls()
        if instance.configured:
            providers.append(instance)
    return tuple(providers)


_ADVERSE = CompositeAdverseEventsProvider(providers=_adverse_providers())
_LLM: LlmProvider = default_llm_provider()

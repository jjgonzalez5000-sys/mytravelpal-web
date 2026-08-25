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
from app.providers.fuel_gov import GovFuelProvider
from app.providers.fuel_hybrid import HybridFuelProvider
from app.providers.nominatim_poi import (
    NominatimFuelProvider,
    NominatimHotelsProvider,
    NominatimRestaurantsProvider,
)
from app.providers.overpass import (
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
    """DI factory. Returns the shared singleton bundle so every request
    reuses the same `httpx.AsyncClient` pools.

    Previous versions instantiated a fresh set of clients per call —
    that was a socket / connection-pool leak: after ~100 /plan
    requests the process had thousands of half-open connections and
    the event loop stopped answering (Fly health checks then killed
    the machine as "unresponsive").
    """
    return _PROVIDERS_SINGLETON


def _tollguru_provider() -> TollProvider | None:
    # Only expose a live client when a key is present — otherwise the
    # endpoint continues on with its heuristic pricing.
    if os.environ.get("TOLLGURU_API_KEY"):
        return TollGuruProvider()
    return None


def _hotels_provider():
    # Default: Nominatim POI search. Overpass proved unreachable from
    # Fly (ConnectError / ReadTimeout on every public mirror) and
    # Nominatim reuses the same OSM upstream via an endpoint that IS
    # reachable from the same Fly machine. Opt-outs:
    # - `MYTRAVELPAL_HOTELS=mock` for CI / offline tests.
    # - `MYTRAVELPAL_HOTELS=overpass` if you're running against a
    #   private Overpass instance where the network path works.
    mode = os.environ.get("MYTRAVELPAL_HOTELS", "nominatim").lower()
    if mode == "mock":
        return MockHotelsProvider()
    if mode == "overpass":
        return OverpassHotelsProvider()
    return NominatimHotelsProvider()


def _fuel_provider():
    # Default: `hybrid` = government feeds for ES/FR/IT with real
    # prices, Nominatim OSM stations tagged `price_available=False` for
    # every other country the route crosses. Same behaviour on the
    # covered slice as pure `gov`.
    mode = os.environ.get("MYTRAVELPAL_FUEL", "hybrid").lower()
    if mode == "mock":
        return MockFuelProvider()
    if mode == "overpass":
        return OverpassFuelProvider()
    if mode == "nominatim":
        return NominatimFuelProvider()
    if mode == "gov":
        return GovFuelProvider()
    return HybridFuelProvider()


def _restaurants_provider():
    mode = os.environ.get("MYTRAVELPAL_RESTAURANTS", "nominatim").lower()
    if mode == "mock":
        return MockRestaurantsProvider()
    if mode == "overpass":
        return OverpassRestaurantsProvider()
    return NominatimRestaurantsProvider()


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


# Build the whole Providers bundle exactly once at import time so
# every request reuses the same httpx connection pools. See
# `get_providers()` for why this matters.
_PROVIDERS_SINGLETON: Providers = Providers(
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

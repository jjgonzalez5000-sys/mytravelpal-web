from __future__ import annotations

from dataclasses import dataclass

import os

from app.providers.adverse_events import (
    AdverseEventsProvider,
    CompositeAdverseEventsProvider,
    MockAdverseEventsProvider,
    UserMarkedAdverseEventsProvider,
)
from app.providers.copernicus_ems import CopernicusEmsProvider
from app.providers.meteoalarm import MeteoAlarmProvider
from app.providers.firms import FirmsFireProvider
from app.providers.heatwave import HeatwaveProvider
from app.providers.road_closures import RoadClosureProvider
from app.providers.usgs_earthquakes import UsgsEarthquakeProvider
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
from app.providers.geoapify_poi import (
    GeoapifyFuelProvider,
    GeoapifyHotelsProvider,
    GeoapifyRestaurantsProvider,
)
from app.providers.overpass import (
    OverpassFuelProvider,
    OverpassHotelsProvider,
    OverpassRestaurantsProvider,
)
from app.providers.osm_toll_gates import OsmTollGateProvider
from app.providers.tollguru import TollGuruProvider, TollProvider
from app.providers.tolls_here import HereTollsProvider
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
    osm_gates: OsmTollGateProvider


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
    """Booth-level toll provider. HERE Routing v8 is preferred — it's
    free within our subscription and returns per-gate coordinates and
    vignette flags. TollGuru ($80/mo minimum) is no longer the default;
    set MYTRAVELPAL_USE_TOLLGURU=1 to force it if needed.
    """
    # HERE Tolls first — free, per-section with real gate coordinates.
    if os.environ.get("MYTRAVELPAL_HERE_API_KEY"):
        return HereTollsProvider()
    # TollGuru as explicit opt-in (paid, $80/mo minimum).
    if os.environ.get("TOLLGURU_API_KEY") and os.environ.get("MYTRAVELPAL_USE_TOLLGURU"):
        return TollGuruProvider()
    return None


def _hotels_provider():
    # Default: Geoapify when `MYTRAVELPAL_GEOAPIFY_KEY` is set,
    # else Nominatim. Nominatim's public demo started banning our
    # Fly IP under normal load; Geoapify's free tier (3 000 req/day,
    # 5 req/s) covers a beta cohort without ops fires.
    # Opt-outs:
    # - `MYTRAVELPAL_HOTELS=mock` for CI / offline tests.
    # - `MYTRAVELPAL_HOTELS=overpass` for a private Overpass box.
    # - `MYTRAVELPAL_HOTELS=nominatim` forces the old provider.
    mode = os.environ.get("MYTRAVELPAL_HOTELS", "").lower()
    if mode == "mock":
        return MockHotelsProvider()
    if mode == "overpass":
        return OverpassHotelsProvider()
    if mode == "nominatim":
        return NominatimHotelsProvider()
    if os.environ.get("MYTRAVELPAL_GEOAPIFY_KEY"):
        return GeoapifyHotelsProvider()
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
    mode = os.environ.get("MYTRAVELPAL_RESTAURANTS", "").lower()
    if mode == "mock":
        return MockRestaurantsProvider()
    if mode == "overpass":
        return OverpassRestaurantsProvider()
    if mode == "nominatim":
        return NominatimRestaurantsProvider()
    if os.environ.get("MYTRAVELPAL_GEOAPIFY_KEY"):
        return GeoapifyRestaurantsProvider()
    return NominatimRestaurantsProvider()


# Shared singletons — user-marked events must persist across requests, and
# the composite must reference the same in-memory registry every call.
_ROUTING = default_routing_provider()
_USER_MARKED = UserMarkedAdverseEventsProvider()


def _adverse_providers() -> tuple[AdverseEventsProvider, ...]:
    # Every external provider is opt-in via env var. Off by default in
    # tests and CI (avoids network); production docker-compose enables
    # the ones we've integrated.
    # MockAdverseEventsProvider gated by explicit env var — should
    # NEVER appear in production. Set MYTRAVELPAL_MOCK_ADVERSE=on in
    # local docker-compose or dev .env only.
    providers: list[AdverseEventsProvider] = [_USER_MARKED]
    if os.environ.get("MYTRAVELPAL_MOCK_ADVERSE", "").lower() in {"on", "1", "true"}:
        providers.append(MockAdverseEventsProvider())
    if os.environ.get("MYTRAVELPAL_WEATHER", "").lower() == "openmeteo":
        providers.append(OpenMeteoWeatherProvider())
    # Fires: default-on now that we're wired to a stable service
    # (NASA FIRMS via ArcGIS Living Atlas). Opt-out with
    # `MYTRAVELPAL_FIRES=off` to suppress the outbound call (CI, tests).
    if os.environ.get("MYTRAVELPAL_FIRES", "firms").lower() not in {"off", "0", "false"}:
        providers.append(FirmsFireProvider())
    # Earthquakes: USGS FDSN, free + keyless. Default-off so unit
    # tests stay hermetic; production docker sets MYTRAVELPAL_QUAKES=usgs.
    if os.environ.get("MYTRAVELPAL_QUAKES", "").lower() in {"usgs", "on", "1", "true"}:
        providers.append(UsgsEarthquakeProvider())
    # Heatwaves: Open-Meteo daily max, keyless. Off by default to
    # avoid an extra API call per /plan; production docker turns
    # it on via MYTRAVELPAL_HEATWAVE=on.
    if os.environ.get("MYTRAVELPAL_HEATWAVE", "").lower() in {"on", "1", "true"}:
        providers.append(HeatwaveProvider())
    # MeteoAlarm: pan-European severe weather warnings (thunderstorms,
    # heavy rain, snow, wind, fog, heatwave, floods) from official NMS.
    # Keyless, default-on. Opt-out with MYTRAVELPAL_METEOALARM=off.
    if os.environ.get("MYTRAVELPAL_METEOALARM", "on").lower() not in {"off", "0", "false"}:
        providers.append(MeteoAlarmProvider())
    # Landslides / avalanches: Copernicus EMS stub (returns () today).
    # Wired unconditionally so the log line appears once at startup
    # and so real activations flow through the moment we ship the
    # RSS/webhook adapter — no code changes elsewhere needed.
    providers.append(CopernicusEmsProvider())
    # Road closures: stub for DGT/DIRIF/ANAS/DATEX II adapters.
    providers.append(RoadClosureProvider())
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
    osm_gates=OsmTollGateProvider(),
)

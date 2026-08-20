from __future__ import annotations

from dataclasses import dataclass

from app.providers.adverse_events import (
    AdverseEventsProvider,
    CompositeAdverseEventsProvider,
    MockAdverseEventsProvider,
    UserMarkedAdverseEventsProvider,
)
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
from app.providers.routing import MockRoutingProvider, RoutingProvider
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


def get_providers() -> Providers:
    """DI factory. Returns mock implementations for the MVP.

    Geocoding is hybrid: the small in-memory city catalogue handles the
    well-known launch cities instantly; anything else falls through to
    the real Nominatim service so the user can find e.g. small Swiss
    villages without us having to hand-curate every place name.
    """
    return Providers(
        routing=MockRoutingProvider(),
        traffic=MockTrafficProvider(),
        tolls=MockTollsProvider(),
        fuel=MockFuelProvider(),
        geocoding=HybridGeocodingProvider(
            primary=MockGeocodingProvider(),
            fallback=NominatimGeocodingProvider(),
        ),
        hotels=MockHotelsProvider(),
        restaurants=MockRestaurantsProvider(),
        adverse_events=_ADVERSE,
        user_marked_events=_USER_MARKED,
        llm=_LLM,
    )


# Shared singletons — user-marked events must persist across requests, and
# the composite must reference the same in-memory registry every call.
_USER_MARKED = UserMarkedAdverseEventsProvider()
_ADVERSE = CompositeAdverseEventsProvider(
    providers=(MockAdverseEventsProvider(), _USER_MARKED),
)
_LLM: LlmProvider = default_llm_provider()

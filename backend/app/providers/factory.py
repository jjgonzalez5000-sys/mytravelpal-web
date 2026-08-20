from __future__ import annotations

from dataclasses import dataclass

from app.providers.fuel import FuelProvider, MockFuelProvider
from app.providers.geocoding import GeocodingProvider, MockGeocodingProvider
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


def get_providers() -> Providers:
    """DI factory. Returns mock implementations for the MVP.

    Swap here (per country / per feature flag) when a real provider ships.
    """
    return Providers(
        routing=MockRoutingProvider(),
        traffic=MockTrafficProvider(),
        tolls=MockTollsProvider(),
        fuel=MockFuelProvider(),
        geocoding=MockGeocodingProvider(),
    )

"""Sprint 11: EU expansion + partial toll skips + Open-Meteo weather +
Premium gating.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import httpx
import pytest
from fastapi.testclient import TestClient

from app.data.countries import COUNTRIES, all_nominatim_codes
from app.domain import Coordinate, Country, Route
from app.main import app
from app.providers import MockRoutingProvider, OpenMeteoWeatherProvider
from app.services.country_detection import detect_country
from app.services.partial_toll_skips import compute as compute_partial_skips

client = TestClient(app)

_PARIS = Coordinate(48.8566, 2.3522)
_MADRID = Coordinate(40.4168, -3.7038)


# --- EU expansion -------------------------------------------------------

class TestCountriesTable:
    def test_all_supported_countries_have_data(self) -> None:
        for code in Country:
            assert code.value in COUNTRIES, f"missing data row for {code}"

    def test_nominatim_codes_are_two_letter_lowercase(self) -> None:
        for data in COUNTRIES.values():
            assert len(data.nominatim_code) == 2
            assert data.nominatim_code == data.nominatim_code.lower()

    def test_all_nominatim_codes_joined(self) -> None:
        joined = all_nominatim_codes()
        assert "fr" in joined and "de" in joined and "pl" in joined
        assert len(joined.split(",")) == len(COUNTRIES)


class TestCountryDetection:
    def test_vienna_is_austria(self) -> None:
        assert detect_country(Coordinate(48.21, 16.37)) is Country.AT

    def test_luxembourg_beats_neighbours(self) -> None:
        assert detect_country(Coordinate(49.61, 6.13)) is Country.LU

    def test_athens_is_greece(self) -> None:
        assert detect_country(Coordinate(37.98, 23.73)) is Country.GR

    def test_dublin_is_ireland(self) -> None:
        assert detect_country(Coordinate(53.35, -6.26)) is Country.IE


class TestGeocodingCatalogue:
    def test_catalogue_covers_multiple_countries(self) -> None:
        response = client.get("/v1/geocode", params={"q": "berlin"})
        assert response.status_code == 200
        results = response.json()["results"]
        assert any(r["country"] == "DE" for r in results)


# --- Partial toll skips ---------------------------------------------------

def _route_with_tolls(*, toll: float = 100.0, km: float = 1000.0) -> Route:
    return Route(
        origin=_PARIS, destination=_MADRID,
        distance_km=km,
        free_flow_duration=timedelta(hours=km / 90.0),
        polyline="p", toll_cost_eur=toll,
        countries_crossed=(Country.FR, Country.ES),
        waypoints=tuple(
            Coordinate(48 - i * 0.5, 2 - i * 0.5) for i in range(1, 11)
        ),
    )


class TestPartialTollSkips:
    def test_returns_no_skips_when_no_tolls(self) -> None:
        route = _route_with_tolls(toll=0)
        assert compute_partial_skips(route) == ()

    def test_returns_up_to_five_skips(self) -> None:
        skips = compute_partial_skips(_route_with_tolls())
        assert 1 <= len(skips) <= 5

    def test_savings_sum_roughly_matches_total_tolls(self) -> None:
        route = _route_with_tolls(toll=100.0)
        skips = compute_partial_skips(route)
        total = sum(s.savings_eur for s in skips)
        # Middle-weighted heuristic ≠ perfect split, but should stay in a
        # plausible band of the whole toll cost.
        assert 60.0 <= total <= 140.0


class TestPlanEndpointPartialTollSkips:
    def test_plan_has_no_invented_skips_without_booth_level_data(self) -> None:
        response = client.post("/v1/trips/plan", json={
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            "include_toll_alternative": True,
        })
        assert response.status_code == 200, response.text
        # No booth-level quote in the mock stack: the old "Toll stretch n/5"
        # even split was a made-up figure and must not be offered.
        assert response.json()["partial_toll_skips"] == []

    def test_plan_omits_partial_toll_skips_when_alt_off(self) -> None:
        response = client.post("/v1/trips/plan", json={
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
        })
        assert response.json()["partial_toll_skips"] == []


# --- Premium gating -----------------------------------------------------

class TestPremiumGating:
    def _plan(self, headers: dict[str, str] | None = None, **extra):
        payload = {
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
            **extra,
        }
        return client.post("/v1/trips/plan", json=payload, headers=headers or {})

    def test_hourly_toll_is_dropped_for_free_not_rejected(self) -> None:
        response = self._plan(include_hourly_toll_analysis=True)
        assert response.status_code == 200
        assert response.json()["hourly_toll_report"] is None

    def test_hourly_toll_allowed_with_premium_header(self) -> None:
        response = self._plan(
            headers={"X-MyTravelPal-Premium": "true"},
            include_hourly_toll_analysis=True,
        )
        assert response.status_code == 200
        assert response.json()["hourly_toll_report"] is not None

    def test_plan_without_premium_still_works_for_free_features(self) -> None:
        response = self._plan(include_toll_alternative=True)
        assert response.status_code == 200


# --- Open-Meteo weather -------------------------------------------------

class TestOpenMeteoProvider:
    def _fake_client(
        self, weathercode: int, first_time: datetime | None = None,
    ) -> httpx.AsyncClient:
        base = first_time or datetime(2026, 8, 24, tzinfo=timezone.utc)

        async def handler(request: httpx.Request) -> httpx.Response:
            times = [
                (base + timedelta(hours=i)).strftime("%Y-%m-%dT%H:%M")
                for i in range(48)
            ]
            body = {
                "hourly": {
                    "time": times,
                    "weathercode": [weathercode] * len(times),
                },
            }
            return httpx.Response(200, text=json.dumps(body))

        return httpx.AsyncClient(transport=httpx.MockTransport(handler))

    @pytest.mark.asyncio
    async def test_maps_thunderstorm_to_critical_weather_event(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        # Feed 5 explicit waypoints so `_sample_points` picks something.
        from dataclasses import replace as _replace

        route = _replace(
            route,
            waypoints=tuple(
                Coordinate(48 - i, 2 - i) for i in range(1, 6)
            ),
        )
        client_ = self._fake_client(95)  # thunderstorm
        provider = OpenMeteoWeatherProvider(http_client=client_)
        events = await provider.events_along(
            route, now=datetime(2026, 8, 24, tzinfo=timezone.utc),
        )
        assert events
        assert all(e.severity.value == "critical" for e in events)
        assert all(e.source.value == "weather" for e in events)

    @pytest.mark.asyncio
    async def test_ignores_benign_weather_codes(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        client_ = self._fake_client(1)  # mainly clear — no event
        provider = OpenMeteoWeatherProvider(http_client=client_)
        events = await provider.events_along(
            route, now=datetime(2026, 8, 24, tzinfo=timezone.utc),
        )
        assert events == ()

    @pytest.mark.asyncio
    async def test_gracefully_returns_empty_on_http_error(self) -> None:
        async def failing(request):
            raise httpx.ConnectError("down")

        client_ = httpx.AsyncClient(transport=httpx.MockTransport(failing))
        provider = OpenMeteoWeatherProvider(http_client=client_)
        routing = MockRoutingProvider()
        route = await routing.route(_PARIS, _MADRID)
        events = await provider.events_along(
            route, now=datetime(2026, 8, 24, tzinfo=timezone.utc),
        )
        assert events == ()

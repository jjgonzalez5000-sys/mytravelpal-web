from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.domain import (
    AdverseEvent,
    AdverseEventSeverity,
    AdverseEventSource,
    AdverseEventType,
    Coordinate,
    Country,
    Hotel,
    PriceBand,
    Restaurant,
    RestStop,
    Route,
    TimeWindow,
)
from app.main import app
from app.providers.llm import ClaudeLlmProvider, MockLlmProvider, default_llm_provider
from app.services.trip_narrative import build_prompt, generate_trip_narrative

client = TestClient(app)


def _route() -> Route:
    return Route(
        origin=Coordinate(48.8566, 2.3522),
        destination=Coordinate(40.4168, -3.7038),
        distance_km=1316.1,
        free_flow_duration=timedelta(hours=13, minutes=51),
        polyline="p",
        toll_cost_eur=210.58,
        countries_crossed=(Country.FR, Country.ES),
    )


def _recommended() -> TimeWindow:
    return TimeWindow(
        departure_at=datetime(2026, 8, 24, 5, 30, tzinfo=timezone.utc),
        estimated_duration=timedelta(hours=14, minutes=30),
        traffic_factor=1.05,
        recommended=True,
    )


class TestBuildPrompt:
    def test_mentions_cities_route_and_time(self) -> None:
        prompt = build_prompt(
            origin_name="Paris",
            destination_name="Madrid",
            desired_departure_at=datetime(2026, 8, 24, 8, tzinfo=timezone.utc),
            route=_route(),
            recommended=_recommended(),
            rest_stops=(),
            hotels=(),
            restaurants=(),
            adverse_events=(),
        )
        assert "Paris" in prompt
        assert "Madrid" in prompt
        assert "1316 km" in prompt
        assert "France" in prompt
        assert "Spain" in prompt
        assert "Best departure window" in prompt
        assert "2026-08-24T05:30" in prompt

    def test_omits_empty_sections(self) -> None:
        prompt = build_prompt(
            origin_name="Paris",
            destination_name="Madrid",
            desired_departure_at=datetime(2026, 8, 24, 8, tzinfo=timezone.utc),
            route=_route(),
            recommended=None,
            rest_stops=(),
            hotels=(),
            restaurants=(),
            adverse_events=(),
        )
        assert "Hotels" not in prompt
        assert "Restaurants" not in prompt
        assert "Best departure" not in prompt
        assert "adverse" not in prompt.lower()

    def test_includes_adverse_event_severity_uppercase(self) -> None:
        event = AdverseEvent(
            id="e1",
            type=AdverseEventType.FIRE,
            severity=AdverseEventSeverity.CRITICAL,
            source=AdverseEventSource.MOCK,
            coordinate=Coordinate(44, -1),
            description="Wildfire",
            reported_at=datetime(2026, 8, 24, 6, tzinfo=timezone.utc),
            expires_at=datetime(2026, 8, 25, 6, tzinfo=timezone.utc),
        )
        prompt = build_prompt(
            origin_name="Paris", destination_name="Madrid",
            desired_departure_at=datetime(2026, 8, 24, 8, tzinfo=timezone.utc),
            route=_route(), recommended=None,
            rest_stops=(), hotels=(), restaurants=(),
            adverse_events=(event,),
        )
        assert "[CRITICAL] fire" in prompt


class TestDefaultProviderSelection:
    def test_no_api_key_returns_mock(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        assert isinstance(default_llm_provider(), MockLlmProvider)

    def test_with_api_key_returns_claude(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-fake")
        assert isinstance(default_llm_provider(), ClaudeLlmProvider)


class TestMockNarrative:
    @pytest.mark.asyncio
    async def test_generates_placeholder(self) -> None:
        text = await generate_trip_narrative(
            llm=MockLlmProvider(),
            origin_name="Paris", destination_name="Madrid",
            desired_departure_at=datetime(2026, 8, 24, 8, tzinfo=timezone.utc),
            route=_route(),
            recommended=_recommended(),
            rest_stops=(RestStop(
                coordinate=Coordinate(45, 0), distance_from_origin_km=200,
                cumulative_driving_hours=2.0, recommended_break_minutes=15,
            ),),
            hotels=(Hotel(
                name="H", coordinate=Coordinate(45, 0), country=Country.FR,
                price_eur_per_night=100, price_band=PriceBand.MID,
                distance_from_route_km=1, detour_minutes=5,
            ),),
            restaurants=(Restaurant(
                name="R", coordinate=Coordinate(45, 0), country=Country.FR,
                price_eur_per_meal=25, price_band=PriceBand.MID,
                distance_from_route_km=1, detour_minutes=5,
            ),),
            adverse_events=(),
        )
        assert "placeholder narrative" in text
        # The mock echoes the leading prompt text (system intro comes first).
        assert "MyTravelPal" in text


class TestNarrativeEndpoint:
    # Narrative now requires both premium + a valid JWT (project
    # ai_cost_defense — layer 2 blocks anonymous LLM calls even
    # when the app key alone is present). Mint one demo token at
    # import time; a plain user id is fine for the quota bump.
    from app.auth.jwt import AuthUser as _AuthUser
    from app.auth.jwt import issue_token as _issue_token
    _TOKEN = _issue_token(_AuthUser(
        id="test-user", email="test@example.com",
        display_name="Test User", provider="test",
    ))
    _PREMIUM_HEADER = {
        "X-MyTravelPal-Premium": "true",
        "Authorization": f"Bearer {_TOKEN}",
    }

    def test_returns_narrative_when_mock_provider_active(self) -> None:
        # Override the DI-injected Providers so the narrative endpoint
        # always gets a MockLlmProvider regardless of whether the real
        # ANTHROPIC_API_KEY happens to be present in the environment at
        # test time (the factory builds its singleton at import, so
        # monkeypatch.delenv is too late to affect it).
        from dataclasses import replace as dc_replace

        from app.providers.factory import get_providers
        from app.providers.llm import MockLlmProvider

        real_providers = get_providers()
        mock_providers = dc_replace(real_providers, llm=MockLlmProvider())
        app.dependency_overrides[get_providers] = lambda: mock_providers
        try:
            response = client.post(
                "/v1/trips/narrative",
                headers=self._PREMIUM_HEADER,
                json={
                    "plan_request": {
                        "origin": {"lat": 48.8566, "lon": 2.3522},
                        "destination": {"lat": 40.4168, "lon": -3.7038},
                        "desired_departure_at": "2026-08-24T08:00:00",
                    },
                    "origin_name": "Paris",
                    "destination_name": "Madrid",
                },
            )
            assert response.status_code == 200, response.text
            body = response.json()
            assert body["origin_name"] == "Paris"
            assert body["destination_name"] == "Madrid"
            assert "narrative" in body
            assert body["narrative"]
        finally:
            app.dependency_overrides.pop(get_providers, None)

    def test_rejects_invalid_plan_request(self) -> None:
        response = client.post(
            "/v1/trips/narrative",
            headers=self._PREMIUM_HEADER,
            json={
                "plan_request": {
                    "origin": {"lat": 999, "lon": 0},
                    "destination": {"lat": 40, "lon": -3},
                    "desired_departure_at": "2026-08-24T08:00:00",
                },
            },
        )
        assert response.status_code == 422

    def test_rejects_without_premium_header(self) -> None:
        response = client.post("/v1/trips/narrative", json={
            "plan_request": {
                "origin": {"lat": 48.8566, "lon": 2.3522},
                "destination": {"lat": 40.4168, "lon": -3.7038},
                "desired_departure_at": "2026-08-24T08:00:00",
            },
            "origin_name": "Paris",
            "destination_name": "Madrid",
        })
        assert response.status_code == 402
        assert response.json()["detail"]["error"] == "premium_required"

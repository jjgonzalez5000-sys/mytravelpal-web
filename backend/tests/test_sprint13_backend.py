"""Sprint 13: Apple sign-in + TollGuru wired into /trips/plan +
real-booth partial skips.
"""

from __future__ import annotations

import json
from datetime import timedelta

import httpx
import pytest
from fastapi.testclient import TestClient

from app.auth.providers import (
    AppleOAuthProvider,
    OAuthPayload,
    OAuthVerificationError,
    get_provider,
)
from app.domain import Coordinate, Country, Route
from app.main import app
from app.providers.tollguru import TollBooth, TollProvider, TollQuote
from app.services.partial_toll_skips import compute as compute_skips

client = TestClient(app)


# --- Apple auth ------------------------------------------------------------

class TestAppleProvider:
    def test_registered_in_factory(self) -> None:
        provider = get_provider("apple")
        assert isinstance(provider, AppleOAuthProvider)

    @pytest.mark.asyncio
    async def test_missing_app_id_rejects(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.delenv("APPLE_APP_ID", raising=False)
        provider = AppleOAuthProvider()
        with pytest.raises(OAuthVerificationError, match="APPLE_APP_ID"):
            await provider.verify(OAuthPayload(id_token="doesnt-matter"))

    @pytest.mark.asyncio
    async def test_endpoint_returns_401_for_apple_without_app_id(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.delenv("APPLE_APP_ID", raising=False)
        response = client.post("/v1/auth/session", json={
            "provider": "apple",
            "id_token": "token",
        })
        assert response.status_code == 401


# --- Partial toll skips with real booth data ------------------------------

class TestRealBoothSkips:
    def _route(self) -> Route:
        return Route(
            origin=Coordinate(48.8566, 2.3522),
            destination=Coordinate(40.4168, -3.7038),
            distance_km=1300,
            free_flow_duration=timedelta(hours=13),
            polyline="p", toll_cost_eur=210,
            countries_crossed=(Country.FR, Country.ES),
            geometry=tuple(
                Coordinate(48 - i * 0.2, 2 - i * 0.15) for i in range(20)
            ),
        )

    def test_returns_one_skip_per_booth(self) -> None:
        booths = (
            TollBooth("Fleury", 12.5, 47.5, 1.5),
            TollBooth("Bordeaux Nord", 18.0, 45.0, -0.5),
            TollBooth("Biriatou", 25.0, 43.4, -1.7),
        )
        skips = compute_skips(self._route(), real_tolls=booths)
        assert len(skips) == 3
        assert {s.label for s in skips} == {
            "Fleury", "Bordeaux Nord", "Biriatou",
        }

    def test_worth_it_flag_uses_savings_and_low_penalty(self) -> None:
        booths = (
            TollBooth("Tiny", 1.0, 47.5, 1.5),
            TollBooth("Big", 20.0, 45.0, -0.5),
        )
        skips = compute_skips(self._route(), real_tolls=booths)
        by_label = {s.label: s for s in skips}
        assert by_label["Big"].worth_it is True
        assert by_label["Tiny"].worth_it is False

    def test_penalty_is_much_smaller_than_the_heuristic(self) -> None:
        # Real booth skips = ~5 min per booth. Heuristic = ~6-10 min per
        # segment. This is why we prefer real data when available.
        booths = (TollBooth("Big", 15.0, 45.0, 0.0),)
        skips = compute_skips(self._route(), real_tolls=booths)
        assert skips[0].time_penalty_minutes < 10


# --- TollGuru wire into /trips/plan ---------------------------------------

class _FakeTollProvider:
    """Test double for `TollProvider` — returns a canned quote."""

    def __init__(self, quote: TollQuote | None) -> None:
        self._quote = quote

    async def quote(self, route: Route, *, vehicle_class: str = "2AxlesAuto"):
        return self._quote


class TestPlanEndpointWithTollGuru:
    def test_partial_toll_skips_reflect_real_booths_when_available(self) -> None:
        # Route with real geometry + real quote → partial skips carry
        # booth names and toll_cost matches the TollGuru total.
        from app.api.v1.trips import _providers as _prov
        from app.providers.factory import Providers, get_providers

        class _Routing:
            async def route(self, origin, destination, countries=None, *,
                            avoid_tolls=False, avoid_motorways=False,
                            prefer_scenic=False):
                return Route(
                    origin=origin, destination=destination,
                    distance_km=1200,
                    free_flow_duration=timedelta(hours=12),
                    polyline="p", toll_cost_eur=200,
                    countries_crossed=(Country.FR, Country.ES),
                    geometry=tuple(
                        Coordinate(48 - i * 0.5, 2 - i * 0.5)
                        for i in range(10)
                    ),
                )

        real_quote = TollQuote(
            total_eur=95.5,
            tolls=(
                TollBooth("Fleury", 12.0, 47.5, 1.5),
                TollBooth("Poitiers", 28.0, 46.0, 0.0),
            ),
        )
        base = get_providers()
        patched = Providers(
            routing=_Routing(), traffic=base.traffic, tolls=base.tolls,
            fuel=base.fuel, geocoding=base.geocoding,
            hotels=base.hotels, restaurants=base.restaurants,
            adverse_events=base.adverse_events,
            user_marked_events=base.user_marked_events,
            llm=base.llm,
            tollguru=_FakeTollProvider(real_quote),
        )
        app.dependency_overrides[_prov] = lambda: patched
        try:
            response = client.post("/v1/trips/plan", json={
                "origin": {"lat": 48.8566, "lon": 2.3522},
                "destination": {"lat": 40.4168, "lon": -3.7038},
                "desired_departure_at": "2026-08-24T08:00:00",
                "include_toll_alternative": True,
            })
        finally:
            app.dependency_overrides.pop(_prov, None)

        assert response.status_code == 200
        body = response.json()
        assert body["route"]["toll_cost_eur"] == 95.5
        names = {s["label"] for s in body["partial_toll_skips"]}
        assert names == {"Fleury", "Poitiers"}

    def test_plan_still_works_without_tollguru(self) -> None:
        # No override → real config (tollguru=None in tests since no
        # TOLLGURU_API_KEY). Toll cost falls back to the heuristic.
        response = client.post("/v1/trips/plan", json={
            "origin": {"lat": 48.8566, "lon": 2.3522},
            "destination": {"lat": 40.4168, "lon": -3.7038},
            "desired_departure_at": "2026-08-24T08:00:00",
        })
        assert response.status_code == 200
        assert response.json()["route"]["toll_cost_eur"] > 0

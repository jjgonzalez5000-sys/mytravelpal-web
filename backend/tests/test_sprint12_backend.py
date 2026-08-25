"""Sprint 12: auth + fire provider + Overpass hotels/fuel + TollGuru.

Fire provider was originally EFFIS; switched to NASA FIRMS in Sprint 17
when EFFIS's public WFS deprecated the `ecmwf.hotspots.viirs.24h` layer
without a version bump. The provider class handles the same shape of
GeoJSON so these tests still exercise the parsing + severity logic.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import httpx
import jwt
import pytest
from fastapi.testclient import TestClient

from app.auth.jwt import AuthUser, decode_token, issue_token
from app.domain import Coordinate, Country, Route
from app.main import app
from app.providers import MockRoutingProvider
from app.providers.firms import FirmsFireProvider
from app.providers.overpass import (
    FallbackFuelProvider,
    FallbackHotelsProvider,
    OverpassFuelProvider,
    OverpassHotelsProvider,
)
from app.providers.tollguru import TollGuruProvider

client = TestClient(app)


# --- Auth ------------------------------------------------------------------

class TestJwtHelpers:
    def test_roundtrip(self) -> None:
        u = AuthUser(id="demo:x", email="a@b", display_name="A", provider="demo")
        token = issue_token(u)
        back = decode_token(token)
        assert back == u

    def test_bad_signature_rejected(self) -> None:
        with pytest.raises(jwt.PyJWTError):
            decode_token("not-a-real-token")


class TestAuthEndpoint:
    def test_demo_login_returns_token_and_user(self) -> None:
        response = client.post("/v1/auth/session", json={
            "provider": "demo",
            "id_token": "irrelevant",
            "demo_email": "jane@example.com",
            "demo_name": "Jane Traveller",
        })
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["user"]["email"] == "jane@example.com"
        assert body["user"]["provider"] == "demo"
        assert body["token"]

    def test_google_login_without_client_id_returns_401(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.delenv("GOOGLE_CLIENT_ID", raising=False)
        response = client.post("/v1/auth/session", json={
            "provider": "google",
            "id_token": "does-not-matter",
        })
        assert response.status_code == 401

    def test_me_requires_bearer(self) -> None:
        response = client.get("/v1/auth/me")
        assert response.status_code == 401

    def test_me_returns_user_with_valid_bearer(self) -> None:
        # First mint a demo session, then use its token.
        sess = client.post("/v1/auth/session", json={
            "provider": "demo",
            "id_token": "x",
            "demo_email": "bob@example.com",
            "demo_name": "Bob",
        }).json()
        token = sess["token"]
        response = client.get(
            "/v1/auth/me", headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert response.json()["email"] == "bob@example.com"


# --- EFFIS ----------------------------------------------------------------

class TestEffis:
    def _mock_client(self, features: list[dict]) -> httpx.AsyncClient:
        async def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(
                200,
                text=json.dumps(
                    {"type": "FeatureCollection", "features": features},
                ),
            )
        return httpx.AsyncClient(transport=httpx.MockTransport(handler))

    @pytest.mark.asyncio
    async def test_parses_features_into_events(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        feats = [
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [-1.5, 45.0]},
                "properties": {"id": "f1", "frp": 150.0, "country": "FRA"},
            },
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [-2.0, 43.5]},
                "properties": {"id": "f2", "frp": 15.0, "country": "ESP"},
            },
        ]
        provider = FirmsFireProvider(http_client=self._mock_client(feats))
        events = await provider.events_along(
            route, now=datetime(2026, 8, 24, tzinfo=timezone.utc),
        )
        assert [e.severity.value for e in events] == ["critical", "info"]
        assert all(e.type.value == "fire" for e in events)
        assert all(e.source.value == "official" for e in events)

    @pytest.mark.asyncio
    async def test_graceful_empty_on_http_error(self) -> None:
        async def failing(request):
            raise httpx.ConnectError("down")
        client_ = httpx.AsyncClient(transport=httpx.MockTransport(failing))
        provider = FirmsFireProvider(http_client=client_)
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        events = await provider.events_along(
            route, now=datetime(2026, 8, 24, tzinfo=timezone.utc),
        )
        assert events == ()


# --- Overpass -------------------------------------------------------------

def _overpass_client(elements: list[dict]) -> httpx.AsyncClient:
    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text=json.dumps({"elements": elements}))
    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


class TestOverpassHotels:
    @pytest.mark.asyncio
    async def test_parses_hotel_tags(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        elements = [
            {
                "type": "node",
                "lat": 44.85,
                "lon": -0.58,
                "tags": {
                    "tourism": "hotel",
                    "name": "Le Bordeaux",
                    "stars": "4",
                    "family_friendly": "yes",
                    "dog": "yes",
                    "parking": "yes",
                },
            },
        ]
        provider = OverpassHotelsProvider(http_client=_overpass_client(elements))
        hotels = await provider.hotels_along(route)
        assert hotels and hotels[0].name == "Le Bordeaux"
        assert hotels[0].kid_friendly and hotels[0].pet_friendly
        assert hotels[0].has_parking

    @pytest.mark.asyncio
    async def test_fallback_returns_mock_when_overpass_empty(self) -> None:
        from app.providers.hotels import MockHotelsProvider

        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        primary = OverpassHotelsProvider(http_client=_overpass_client([]))
        fallback = FallbackHotelsProvider(primary, MockHotelsProvider())
        hotels = await fallback.hotels_along(route)
        assert hotels  # mock provider produced entries


class TestOverpassFuel:
    @pytest.mark.asyncio
    async def test_parses_fuel_stations_and_sorts_by_distance(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        elements = [
            {
                "type": "node", "lat": 44.85, "lon": -0.58,
                "tags": {"amenity": "fuel", "brand": "TotalEnergies"},
            },
            {
                "type": "node", "lat": 47.20, "lon": -1.50,
                "tags": {"amenity": "fuel", "brand": "Repsol"},
            },
        ]
        provider = OverpassFuelProvider(
            http_client=_overpass_client(elements),
        )
        prices = await provider.prices_along(route)
        assert prices[0].station_name in {"Repsol", "TotalEnergies"}
        # Sorted by distance_from_origin_km ascending.
        assert prices == tuple(
            sorted(prices, key=lambda p: p.distance_from_origin_km),
        )


# --- TollGuru -------------------------------------------------------------

class TestTollGuru:
    @pytest.mark.asyncio
    async def test_returns_none_without_api_key(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.delenv("TOLLGURU_API_KEY", raising=False)
        provider = TollGuruProvider()
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        # Mock has no geometry either, so double-safe.
        assert await provider.quote(route) is None

    @pytest.mark.asyncio
    async def test_parses_response_with_key(
        self, monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setenv("TOLLGURU_API_KEY", "sk-fake")

        async def handler(request: httpx.Request) -> httpx.Response:
            assert "x-api-key" in {k.lower() for k in request.headers.keys()}
            body = {
                "routes": [
                    {
                        "costs": {"tag": 42.5, "cash": 45.0},
                        "tolls": [
                            {"name": "Booth A", "tagCost": 20.0,
                             "lat": 45.5, "lng": 4.5},
                            {"name": "Booth B", "cashCost": 22.5,
                             "lat": 46.0, "lng": 3.0},
                        ],
                    }
                ]
            }
            return httpx.Response(200, text=json.dumps(body))

        provider = TollGuruProvider(
            http_client=httpx.AsyncClient(
                transport=httpx.MockTransport(handler),
            ),
        )
        # Need geometry for the provider to send a request.
        route = Route(
            origin=Coordinate(48, 2), destination=Coordinate(40, -3),
            distance_km=1000, free_flow_duration=timedelta(hours=10),
            polyline="p", toll_cost_eur=0,
            countries_crossed=(Country.FR,),
            geometry=(Coordinate(48, 2), Coordinate(40, -3)),
        )
        quote = await provider.quote(route)
        assert quote is not None
        assert quote.total_eur == 42.5
        assert len(quote.tolls) == 2

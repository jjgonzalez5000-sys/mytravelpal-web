"""Google Places matching is strict: a wrong neighbour is never stamped."""

from __future__ import annotations

import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.api.v1 import places as places_api
from app.api.v1.suggest import SuggestionOut
from app.api.v1.trips import (
    HotelOut,
    MealStopOut,
    RestaurantOut,
    SleepStopOut,
)
from app.domain import Coordinate, Country, Hotel, PriceBand, Restaurant
from app.main import app
from app.providers import geoapify_poi as geo
from app.providers import google_places as gp

LAT, LON = 40.4168, -3.7038


def _offset(metres_north: float) -> dict:
    return {"latitude": LAT + metres_north / 111_320.0, "longitude": LON}


def _place(pid: str, name: str, metres: float, **extra) -> dict:
    return {
        "id": pid,
        "displayName": {"text": name, "languageCode": "es"},
        "location": _offset(metres),
        "googleMapsUri": f"https://maps.google.com/?cid={pid}",
        "formattedAddress": f"Calle Mayor 5, Madrid ({pid})",
        "rating": 4.46,
        "userRatingCount": 120,
        **extra,
    }


def _client(places: list[dict], status: int = 200, calls: list | None = None):
    def handler(request: httpx.Request) -> httpx.Response:
        if calls is not None:
            calls.append(json.loads(request.content))
        if status != 200:
            return httpx.Response(status, text="boom")
        return httpx.Response(200, json={"places": places})

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


def _hotel(name: str = "Hotel Ibis Madrid", attrs=()) -> Hotel:
    return Hotel(
        name=name, coordinate=Coordinate(lat=LAT, lon=LON), country=Country.ES,
        price_eur_per_night=90.0, price_band=PriceBand.MID,
        distance_from_route_km=1.0, detour_minutes=5.0, attributes=tuple(attrs),
    )


def _restaurant(name: str = "Casa Pepe") -> Restaurant:
    return Restaurant(
        name=name, coordinate=Coordinate(lat=LAT, lon=LON), country=Country.ES,
        price_eur_per_meal=20.0, price_band=PriceBand.MID,
        distance_from_route_km=1.0, detour_minutes=5.0,
    )


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setenv("MYTRAVELPAL_GOOGLE_PLACES_KEY", "k")
    gp._CACHE.clear()
    places_api._calls_by_day.clear()
    places_api._client_calls.clear()
    places_api._alerted.clear()
    yield
    gp._CACHE.clear()


class TestPickBest:
    def test_prefers_the_close_right_place_over_a_far_similar_one(self):
        places = [
            _place("far", "Casa Pepe", 400),
            _place("other", "Bar Manolo", 20),
            _place("right", "Casa Pepe", 40),
        ]
        assert gp._pick_best(places, "Casa Pepe", LAT, LON)["id"] == "right"

    def test_rejects_when_everything_is_too_far_or_unlike(self):
        places = [_place("a", "Casa Pepe", 400), _place("b", "Bar Manolo", 10)]
        assert gp._pick_best(places, "Casa Pepe", LAT, LON) is None

    def test_accent_insensitive_and_display_name_object(self):
        places = [_place("z", "Café Zürich", 30)]
        assert gp._pick_best(places, "Cafe Zurich", LAT, LON)["id"] == "z"

    def test_brand_prefix_still_matches_by_token_containment(self):
        places = [_place("i", "Ibis Madrid Centro Hotel", 30)]
        assert gp._pick_best(places, "Hotel Ibis", LAT, LON)["id"] == "i"

    def test_single_generic_token_does_not_match_everything(self):
        places = [_place("h", "Hotel Miramar", 20)]
        assert gp._pick_best(places, "Hotel", LAT, LON) is None

    def test_skips_results_without_location(self):
        bad = {"id": "x", "displayName": {"text": "Casa Pepe"}}
        assert gp._pick_best([bad], "Casa Pepe", LAT, LON) is None


class TestAddressHint:
    def test_precedence(self):
        assert gp.address_hint({
            "google_address": "G", "here_address": "H", "address_line1": "A",
        }) == "G"
        assert gp.address_hint({"here_address": "H", "address_line1": "A"}) == "H"
        assert gp.address_hint({"address_line1": "A"}) == "A"

    def test_osm_parts(self):
        assert gp.address_hint({
            "addr:street": "Calle Mayor", "addr:housenumber": "5",
            "addr:city": "Madrid",
        }) == "Calle Mayor 5, Madrid"
        assert gp.address_hint({}) is None


class TestEnricher:
    async def test_success_stamps_id_address_and_rating(self):
        calls: list = []
        enricher = gp.GooglePlacesEnricher(_client([_place("right", "Casa Pepe", 40)], calls=calls))
        (out,) = await enricher.enrich_restaurants((_restaurant(),))
        attrs = dict(out.attributes)
        assert attrs["google_place_id"] == "right"
        assert attrs["google_maps_url"] == "https://maps.google.com/?cid=right"
        assert attrs["google_address"].startswith("Calle Mayor 5")
        assert attrs["google_name"] == "Casa Pepe"
        assert attrs["rating"] == "4.5"
        assert attrs["rating_count"] == "120"
        assert calls[0]["maxResultCount"] == 5

    async def test_no_trustworthy_match_leaves_input_untouched(self):
        enricher = gp.GooglePlacesEnricher(_client([_place("far", "Casa Pepe", 500)]))
        r = _restaurant()
        (out,) = await enricher.enrich_restaurants((r,))
        assert out is r

    async def test_address_hint_goes_into_the_text_query(self):
        calls: list = []
        enricher = gp.GooglePlacesEnricher(_client([], calls=calls))
        h = _hotel(attrs=(("here_address", "Calle Mayor 5, Madrid"),))
        await enricher.enrich_hotels((h,))
        assert calls[0]["textQuery"] == "Hotel Ibis Madrid, Calle Mayor 5, Madrid"

    async def test_missing_key_or_no_candidates_makes_no_http_call(self, monkeypatch):
        calls: list = []
        enricher = gp.GooglePlacesEnricher(_client([], calls=calls))
        assert await enricher.enrich_hotels(()) == ()
        monkeypatch.delenv("MYTRAVELPAL_GOOGLE_PLACES_KEY")
        h = _hotel()
        assert await enricher.enrich_hotels((h,)) == (h,)
        assert calls == []

    @pytest.mark.parametrize("status", [429, 500])
    async def test_http_errors_are_silent_and_not_cached(self, status):
        enricher = gp.GooglePlacesEnricher(_client([], status=status))
        r = _restaurant()
        assert (await enricher.enrich_restaurants((r,))) == (r,)
        assert gp._CACHE == {}

    async def test_invalid_json_is_silent(self):
        client = httpx.AsyncClient(
            transport=httpx.MockTransport(lambda _: httpx.Response(200, text="<html>")),
        )
        r = _restaurant()
        assert (await gp.GooglePlacesEnricher(client).enrich_restaurants((r,))) == (r,)

    async def test_second_lookup_for_same_place_is_cached(self):
        calls: list = []
        enricher = gp.GooglePlacesEnricher(_client([_place("right", "Casa Pepe", 40)], calls=calls))
        await enricher.enrich_restaurants((_restaurant(),))
        await enricher.enrich_restaurants((_restaurant(),))
        assert len(calls) == 1

    async def test_misses_are_cached_too(self):
        calls: list = []
        enricher = gp.GooglePlacesEnricher(_client([], calls=calls))
        await enricher.enrich_restaurants((_restaurant(),))
        await enricher.enrich_restaurants((_restaurant(),))
        assert len(calls) == 1

    def test_cache_keys_are_versioned(self):
        assert gp._cache_key("A", 1.0, 2.0).startswith("v2|")


class TestResolveEndpoint:
    def _get(self, **params):
        base = {"name": "Casa Pepe", "lat": LAT, "lon": LON}
        return TestClient(app).get("/v1/places/resolve", params={**base, **params})

    def _patch(self, monkeypatch, places, calls=None):
        places_api._enricher = gp.GooglePlacesEnricher(_client(places, calls=calls))
        monkeypatch.setattr(places_api, "_enricher", places_api._enricher)

    def test_returns_the_matching_place(self, monkeypatch):
        self._patch(monkeypatch, [_place("right", "Casa Pepe", 30)])
        r = self._get(address="Calle Mayor 5")
        assert r.status_code == 200
        assert r.json()["google_place_id"] == "right"
        assert r.json()["google_maps_url"].endswith("cid=right")

    def test_synthetic_names_are_never_looked_up(self, monkeypatch):
        calls: list = []
        self._patch(monkeypatch, [_place("x", "Casa Pepe", 30)], calls)
        r = self._get(name="km 184")
        assert r.status_code == 200
        assert r.json()["google_place_id"] is None
        assert calls == []

    def test_out_of_range_latitude_is_422(self):
        assert self._get(lat=123).status_code == 422

    def test_no_match_is_an_empty_200(self, monkeypatch):
        self._patch(monkeypatch, [_place("far", "Casa Pepe", 900)])
        r = self._get()
        assert r.status_code == 200 and r.json()["google_place_id"] is None

    def test_no_key_is_an_empty_200(self, monkeypatch):
        monkeypatch.delenv("MYTRAVELPAL_GOOGLE_PLACES_KEY")
        assert self._get().json()["google_place_id"] is None

    def test_per_client_daily_cap_answers_429(self, monkeypatch):
        calls: list = []
        self._patch(monkeypatch, [], calls)
        monkeypatch.setattr(places_api, "PER_CLIENT_DAILY_LIMIT", 2)
        statuses = [self._get(name=f"Bar {i}").status_code for i in range(3)]
        assert statuses == [200, 200, 429]

    def test_global_daily_cap_stops_google_calls(self, monkeypatch):
        calls: list = []
        self._patch(monkeypatch, [], calls)
        monkeypatch.setattr(places_api, "DAILY_LIMIT", 1)
        self._get(name="Bar 1")
        r = self._get(name="Bar 2")
        assert r.status_code == 200 and r.json()["google_place_id"] is None
        assert len(calls) == 1

    def test_cache_hits_do_not_use_the_budget(self, monkeypatch):
        calls: list = []
        self._patch(monkeypatch, [_place("right", "Casa Pepe", 30)], calls)
        monkeypatch.setattr(places_api, "PER_CLIENT_DAILY_LIMIT", 1)
        assert [self._get().status_code for _ in range(3)] == [200, 200, 200]
        assert len(calls) == 1


class TestTypedGoogleId:
    def test_hotel_and_restaurant_out_expose_the_id_from_attributes(self):
        common = dict(
            country=Country.ES, price_band=PriceBand.MID, detour_minutes=1.0,
            distance_from_route_km=1.0, lat=LAT, lon=LON,
            attributes={"google_place_id": "ChIJabc"},
        )
        assert HotelOut(name="H", price_eur_per_night=80.0, **common).google_place_id == "ChIJabc"
        assert RestaurantOut(name="R", price_eur_per_meal=20.0, **common).google_place_id == "ChIJabc"

    def test_absent_id_stays_none(self):
        h = HotelOut(
            name="H", country=Country.ES, price_eur_per_night=80.0,
            price_band=PriceBand.MID, detour_minutes=1.0,
            distance_from_route_km=1.0, lat=LAT, lon=LON,
        )
        assert h.google_place_id is None

    def test_meal_sleep_and_suggestion_carry_the_new_fields(self):
        from datetime import datetime, timezone

        now = datetime(2026, 10, 12, tzinfo=timezone.utc)
        m = MealStopOut(
            slot="lunch", at=now, distance_from_origin_km=10.0,
            restaurant_name="R", restaurant_price_eur_per_meal=12.0,
            restaurant_lat=LAT, restaurant_lon=LON,
            google_place_id="p", restaurant_address="Calle 1",
        )
        s = SleepStopOut(
            at=now, distance_from_origin_km=10.0, hotel_name="H",
            hotel_price_eur_per_night=80.0, hotel_lat=LAT, hotel_lon=LON,
            google_place_id="q", hotel_address="Calle 2",
        )
        assert m.model_dump()["google_place_id"] == "p"
        assert s.model_dump()["hotel_address"] == "Calle 2"
        sug = SuggestionOut(
            id="1", name="N", lat=LAT, lon=LON, category="c", why="w",
            visit_minutes=10, detour_minutes=5, distance_from_route_km=1.0,
            along_km=2.0, fits_window=True, google_place_id="g",
        )
        assert sug.google_place_id == "g"


class TestGeoapifyAddressAttrs:
    def test_address_and_city_survive_the_tag_cap(self):
        feature = {"properties": {
            "address_line2": "Calle Mayor 5, Madrid", "city": "Madrid",
            "datasource": {"raw": {f"tag{i}": "v" for i in range(30)}},
        }}
        raw = tuple((f"tag{i}", "v") for i in range(30))
        attrs = dict(geo._with_address(feature, raw))
        assert len(attrs) == 12
        assert attrs["address_line1"] == "Calle Mayor 5, Madrid"
        assert attrs["addr:city"] == "Madrid"

    def test_existing_osm_tags_are_not_duplicated(self):
        feature = {"properties": {"city": "Madrid"}}
        out = geo._with_address(feature, (("addr:city", "Madrid"),))
        assert out == (("addr:city", "Madrid"),)


class TestPickIds:
    async def test_reuses_list_enrichment_and_looks_up_only_the_rest(self, monkeypatch):
        from app.api.v1 import trips

        calls: list = []
        monkeypatch.setattr(
            trips, "GooglePlacesEnricher",
            lambda: gp.GooglePlacesEnricher(
                _client([_place("new", "Casa Pepe", 30)], calls=calls),
            ),
        )
        known = HotelOut(
            name="Hotel Ibis Madrid", country=Country.ES, price_eur_per_night=80.0,
            price_band=PriceBand.MID, detour_minutes=1.0, distance_from_route_km=1.0,
            lat=LAT, lon=LON, attributes={"google_place_id": "known"},
        )
        hotel, rest = _hotel(), _restaurant()
        got = await trips._google_ids_for_picks([hotel, rest], [known])
        assert trips._pick_gid(hotel, got) == "known"
        assert trips._pick_gid(rest, got) == "new"
        assert len(calls) == 1
        assert trips._pick_address(rest, got).startswith("Calle Mayor 5")

    async def test_failures_leave_picks_without_ids(self, monkeypatch):
        from app.api.v1 import trips

        monkeypatch.setattr(
            trips, "GooglePlacesEnricher",
            lambda: gp.GooglePlacesEnricher(_client([], status=500)),
        )
        rest = _restaurant()
        got = await trips._google_ids_for_picks([rest], [])
        assert trips._pick_gid(rest, got) is None

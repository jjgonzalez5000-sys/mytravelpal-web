"""A suggestion carries the facts its place has, never invented ones."""

from __future__ import annotations

from app.services import stop_suggestions as ss

LINE = [(40.0, -3.0), (40.0, -2.5), (40.0, -2.0)]


def _feature(raw=None, **props):
    return {"properties": {
        "name": "Musée du Verrier", "lat": 40.01, "lon": -2.5,
        **props, "datasource": {"raw": raw or {}},
    }}


class TestPlaceAttributes:
    def test_contact_facts_are_passed_on(self):
        attrs = dict(ss.place_attributes(
            {"address_line2": "Route de Morens 19, 1462 Yvonand",
             "website": "https://musee.example"},
            {"phone": "+41 24 000 00 00", "opening_hours": "Tu-Su 10:00-17:00",
             "wheelchair": "yes"},
        ))
        assert attrs["website"] == "https://musee.example"
        assert attrs["phone"] == "+41 24 000 00 00"
        assert attrs["opening_hours"] == "Tu-Su 10:00-17:00"
        assert attrs["address_line1"] == "Route de Morens 19, 1462 Yvonand"
        assert attrs["wheelchair"] == "yes"

    def test_missing_facts_are_left_out_not_filled_in(self):
        assert ss.place_attributes({}, {}) == ()
        assert ss.place_attributes({"website": "  "}, {"phone": ""}) == ()

    def test_contact_prefixed_osm_tags_are_read(self):
        attrs = dict(ss.place_attributes(
            {}, {"contact:phone": "123", "contact:website": "https://x.test"},
        ))
        assert attrs["phone"] == "123" and attrs["website"] == "https://x.test"

    def test_wikipedia_tag_becomes_a_link(self):
        attrs = dict(ss.place_attributes({}, {"wikipedia": "fr:Musée du Verrier"}))
        assert attrs["wikipedia_url"] == "https://fr.wikipedia.org/wiki/Musée_du_Verrier"

    def test_a_malformed_wikipedia_tag_gives_no_link(self):
        for bad in ("Musée du Verrier", "fr:", ":Titre", "francais:Titre1234", "f1:Titre"):
            assert "wikipedia_url" not in dict(ss.place_attributes({}, {"wikipedia": bad}))

    def test_overlong_values_are_cut(self):
        attrs = dict(ss.place_attributes({}, {"opening_hours": "x" * 500}))
        assert len(attrs["opening_hours"]) == 200


class TestCandidatesKeepTheirAttributes:
    def test_attributes_survive_selection_and_renumbering(self):
        cands = ss.select_candidates(
            [_feature({"phone": "123"}, website="https://x.test")], LINE,
        )
        assert cands[0].id == "c1"
        assert dict(cands[0].attributes)["phone"] == "123"


class TestEndpointReturnsAttributes:
    def test_the_response_has_the_attributes_of_each_pick(self):
        from unittest.mock import AsyncMock, patch

        from tests.test_stop_suggestions import TestSuggestStopsEndpoint
        from app.api.v1 import suggest

        suggest._CACHE.clear()
        feats = [_feature({"phone": "+41 24 000 00 00"}, website="https://x.test")]
        client, app = TestSuggestStopsEndpoint._client("u-attrs")
        try:
            with patch(
                "app.api.v1.billing.get_subscription_tier",
                new=AsyncMock(return_value="premium"),
            ), patch.object(
                suggest, "_fetch_places", new=AsyncMock(return_value=feats),
            ), patch(
                "app.providers.llm.MockLlmProvider.generate_narrative",
                new=AsyncMock(return_value='{"picks":[{"id":"c1","why":"ok","visit_minutes":30}]}'),
            ):
                r = client.post(
                    "/v1/trips/suggest-stops", json=TestSuggestStopsEndpoint.BODY,
                )
        finally:
            app.dependency_overrides.clear()
        assert r.status_code == 200, r.text
        s = r.json()["suggestions"][0]
        assert s["attributes"]["phone"] == "+41 24 000 00 00"
        assert s["attributes"]["website"] == "https://x.test"

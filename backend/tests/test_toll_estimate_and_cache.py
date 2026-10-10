"""The rough toll estimate and the plan cache must not keep a wrong number.

Regression: Unterageri -> Madrid (CH, FR, ES) showed about 290 EUR of tolls
while the booth-level quote was about 80. The estimate charged every crossed
country's per-km rate over the whole distance, and an enrich response whose
toll quote had failed was cached for five minutes.
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.api.v1.trips import _toll_quote_ok
from app.data.countries import COUNTRIES
from app.domain import Country
from app.providers.routing import _apply_toll_pricing


class TestTollEstimate:
    def test_each_country_only_prices_its_share_of_the_drive(self):
        crossed = (Country.CH, Country.FR, Country.ES)
        km = 1670.0
        share = km / 3
        expected = (
            COUNTRIES["FR"].toll_per_km_eur * share
            + COUNTRIES["ES"].toll_per_km_eur * share
            + COUNTRIES["CH"].vignette_eur
        )
        assert _apply_toll_pricing(km, crossed) == pytest.approx(expected)

    def test_three_countries_no_longer_cost_what_the_old_formula_said(self):
        old = (
            (COUNTRIES["FR"].toll_per_km_eur + COUNTRIES["ES"].toll_per_km_eur)
            * 1670.0 + COUNTRIES["CH"].vignette_eur
        )
        new = _apply_toll_pricing(1670.0, (Country.CH, Country.FR, Country.ES))
        assert new < old * 0.6

    def test_a_single_country_is_unchanged(self):
        km = 600.0
        assert _apply_toll_pricing(km, (Country.ES,)) == pytest.approx(
            COUNTRIES["ES"].toll_per_km_eur * km,
        )

    def test_no_countries_is_zero_and_does_not_divide_by_zero(self):
        assert _apply_toll_pricing(500.0, ()) == 0.0


def _resp(verified: bool):
    return SimpleNamespace(route=SimpleNamespace(toll_verified=verified))


class TestTollQuoteOk:
    def test_a_verified_quote_is_cacheable(self):
        assert _toll_quote_ok(_resp(True), SimpleNamespace(tollguru=object()))

    def test_an_unverified_quote_is_not_cached_when_a_provider_exists(self):
        assert not _toll_quote_ok(_resp(False), SimpleNamespace(tollguru=object()))

    def test_without_a_provider_there_is_nothing_to_wait_for(self):
        assert _toll_quote_ok(_resp(False), SimpleNamespace(tollguru=None))


class TestPlanCacheVersion:
    def _payload(self):
        from app.api.v1.trips import TripPlanRequest

        return TripPlanRequest.model_validate({
            "origin": {"lat": 47.13, "lon": 8.58},
            "destination": {"lat": 40.41, "lon": -3.70},
            "desired_departure_at": "2026-10-14T09:00:00",
        })

    def test_bumping_the_version_drops_every_old_entry(self, monkeypatch):
        from app.services import plan_cache

        cache = plan_cache.PlanCache(redis_url=None)
        before = cache.key_for(self._payload(), plan_cache.PlanCacheSlot.ENRICH)
        monkeypatch.setattr(plan_cache, "_CACHE_VERSION", "next")
        after = cache.key_for(self._payload(), plan_cache.PlanCacheSlot.ENRICH)
        assert before != after

    def test_same_request_same_version_same_key(self):
        from app.services import plan_cache

        cache = plan_cache.PlanCache(redis_url=None)
        a = cache.key_for(self._payload(), plan_cache.PlanCacheSlot.CORE)
        b = cache.key_for(self._payload(), plan_cache.PlanCacheSlot.CORE)
        assert a == b

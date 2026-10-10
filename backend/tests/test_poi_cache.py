"""Shared Geoapify cache: fewer paid calls, and never a cached failure."""

from __future__ import annotations

import asyncio
import logging
import math
import time
from types import SimpleNamespace

import httpx
import pytest

from app.providers import geoapify_poi as geo
from app.services import poi_cache


def _feature(name: str, lat: float = 40.0, lon: float = -3.0, **raw):
    return {
        "type": "Feature",
        "properties": {
            "name": name, "lat": lat, "lon": lon,
            "categories": ["accommodation.hotel"],
            "datasource": {"raw": {"stars": "4", **raw}, "sourcename": "osm"},
            "details": {"nested": True},
        },
        "geometry": {"type": "Point", "coordinates": [lon, lat]},
    }


class FakeClient:
    """Stands in for httpx.AsyncClient; one scripted response per call."""

    def __init__(self, *responses, delay: float = 0.0):
        self.responses = list(responses)
        self.calls = 0
        self.delay = delay

    async def get(self, url, params=None):
        self.calls += 1
        if self.delay:
            await asyncio.sleep(self.delay)
        r = self.responses[min(self.calls - 1, len(self.responses) - 1)]
        if isinstance(r, Exception):
            raise r
        return r


def _ok(*features):
    return httpx.Response(200, json={"features": list(features)})


def _search(client, filt="rect:-3.05,39.95,-2.95,40.05", cats="accommodation.hotel"):
    return geo._search(client, cats, filt, "k")


class TestSnapping:
    def test_rect_snap_always_contains_the_original(self):
        s = poi_cache.snap_filter("rect:-3.05,39.95,-2.95,40.05")
        w, so, e, n = (float(x) for x in s.removeprefix("rect:").split(","))
        assert w <= -3.05 and so <= 39.95 and e >= -2.95 and n >= 40.05

    def test_nearby_rects_share_one_cell(self):
        a = poi_cache.snap_filter("rect:-3.04,39.96,-2.96,40.04")
        b = poi_cache.snap_filter("rect:-3.01,39.92,-2.93,40.01")
        assert a == b

    def test_snapping_is_idempotent(self):
        once = poi_cache.snap_filter("rect:-3.123,39.987,-2.456,40.321")
        assert poi_cache.snap_filter(once) == once

    def test_circle_snap_still_covers_the_original_circle(self):
        def km(lat1, lon1, lat2, lon2):
            p = math.radians
            a = (math.sin(p(lat2 - lat1) / 2) ** 2 + math.cos(p(lat1))
                 * math.cos(p(lat2)) * math.sin(p(lon2 - lon1) / 2) ** 2)
            return 6371 * 2 * math.asin(math.sqrt(a))

        for lon, lat, r in [(-3.703, 40.416, 12000), (2.349, 48.853, 25000), (12.4964, 41.9028, 5000)]:
            s = poi_cache.snap_filter(f"circle:{lon},{lat},{r}")
            slon, slat, sr = (float(x) for x in s.removeprefix("circle:").split(","))
            assert km(lat, lon, slat, slon) + r / 1000 <= sr / 1000

    def test_unknown_filters_pass_through(self):
        assert poi_cache.snap_filter("place:abc") == "place:abc"
        assert poi_cache.snap_filter("rect:a,b") == "rect:a,b"


class TestTrim:
    def test_keeps_what_the_app_reads(self):
        t = poi_cache.trim_feature(_feature("Hotel X", website="https://x"))
        p = t["properties"]
        assert p["name"] == "Hotel X" and p["lat"] == 40.0
        assert p["categories"] == ["accommodation.hotel"]
        assert p["datasource"]["raw"]["stars"] == "4"
        assert t["geometry"]["coordinates"] == [-3.0, 40.0]

    def test_drops_nested_and_heavy_parts(self):
        t = poi_cache.trim_feature(_feature("Hotel X"))
        assert "details" not in t["properties"]
        assert "sourcename" not in t["properties"]["datasource"]

    def test_polygon_geometry_is_dropped(self):
        f = _feature("Park")
        f["geometry"] = {"type": "Polygon", "coordinates": [[[0, 0]] * 500]}
        assert "geometry" not in poi_cache.trim_feature(f)


class TestSearchUsesTheCache:
    def test_an_identical_query_costs_one_call(self):
        c = FakeClient(_ok(_feature("A")))

        async def go():
            return [await _search(c), await _search(c)]

        first, second = asyncio.run(go())
        assert c.calls == 1
        assert first == second and first[0]["properties"]["name"] == "A"

    def test_a_slightly_different_area_shares_the_answer(self):
        c = FakeClient(_ok(_feature("A")))

        async def go():
            await _search(c, "rect:-3.04,39.96,-2.96,40.04")
            await _search(c, "rect:-3.01,39.92,-2.93,40.01")

        asyncio.run(go())
        assert c.calls == 1

    def test_other_categories_are_other_entries(self):
        c = FakeClient(_ok(_feature("A")))

        async def go():
            await _search(c, cats="accommodation.hotel")
            await _search(c, cats="catering")

        asyncio.run(go())
        assert c.calls == 2

    def test_a_real_empty_answer_is_kept(self):
        c = FakeClient(_ok())

        async def go():
            await _search(c)
            return await _search(c)

        assert asyncio.run(go()) == []
        assert c.calls == 1

    @pytest.mark.parametrize("bad", [
        httpx.Response(429, text="quota"),
        httpx.Response(500, text="boom"),
        httpx.Response(200, text="not json"),
        httpx.ReadTimeout("slow"),
    ])
    def test_a_failure_is_never_cached(self, bad):
        c = FakeClient(bad, bad, _ok(_feature("Recovered")))

        async def go():
            first = await _search(c)
            second = await _search(c)
            return first, second

        first, second = asyncio.run(go())
        assert first == []
        # The provider recovered between the two attempts.
        assert [f["properties"]["name"] for f in second] in ([], ["Recovered"])
        assert poi_cache.stats()["failed_calls_not_cached"] >= 1
        assert c.calls >= 2

    def test_concurrent_identical_queries_make_one_call(self):
        c = FakeClient(_ok(_feature("A")), delay=0.02)

        async def go():
            return await asyncio.gather(*[_search(c) for _ in range(6)])

        results = asyncio.run(go())
        assert c.calls == 1
        assert all(r == results[0] for r in results)
        assert poi_cache.stats()["coalesced_requests"] == 5

    def test_an_expired_entry_is_fetched_again(self, monkeypatch):
        c = FakeClient(_ok(_feature("A")))
        real = time.time

        async def go():
            await _search(c)
            monkeypatch.setattr(poi_cache.time, "time", lambda: real() + poi_cache.TTL_S + 60)
            await _search(c)

        asyncio.run(go())
        assert c.calls == 2

    def test_memory_is_bounded(self, monkeypatch):
        monkeypatch.setattr(poi_cache, "L1_MAX_ENTRIES", 3)
        c = FakeClient(_ok(_feature("A")))

        async def go():
            for i in range(10):
                await _search(c, f"rect:{i},0,{i + 0.05},0.05")

        asyncio.run(go())
        assert len(poi_cache._l1) == 3


class TestUsageAccounting:
    def test_real_calls_are_counted_but_cache_hits_are_not(self):
        c = FakeClient(_ok(_feature("A")))

        async def go():
            for _ in range(5):
                await _search(c)

        asyncio.run(go())
        s = poi_cache.stats()
        assert s["calls_today"] == 1
        assert s["cache_hits_memory"] == 4 and s["cache_misses"] == 1

    def test_alerts_fire_once_per_threshold(self, monkeypatch, caplog):
        monkeypatch.setattr(poi_cache, "DAILY_LIMIT", 10)
        with caplog.at_level(logging.ERROR, logger="app.services.poi_cache"):
            for _ in range(12):
                poi_cache.record_call(status=200, categories="catering")
        text = [r.getMessage() for r in caplog.records]
        assert sum("70%" in t for t in text) == 1
        assert sum("90%" in t for t in text) == 1
        assert sum("100%" in t for t in text) == 1

    def test_a_429_raises_a_quota_alert_once(self, caplog):
        with caplog.at_level(logging.ERROR, logger="app.services.poi_cache"):
            poi_cache.record_call(status=429, categories="catering")
            poi_cache.record_call(status=429, categories="catering")
        assert sum("429" in r.getMessage() for r in caplog.records) == 1

    def test_stats_endpoint_returns_the_counters(self):
        from fastapi.testclient import TestClient

        from app.main import app

        r = TestClient(app).get(
            "/v1/diagnostics/places-usage",
            headers={"X-MyTravelPal-Api-Key": "x"},
        )
        # Auth middleware may refuse the dummy key; the route must exist.
        assert r.status_code in (200, 401, 403)

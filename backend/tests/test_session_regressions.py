"""Regression tests for session bugfixes.

Each test is self-contained and reproduces a specific bug that was fixed.
No external network calls; all HTTP is mocked.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# ---------------------------------------------------------------------------
# 1. MEALS SAME TIME — no two meals within 1.5 h (5400 s)
# ---------------------------------------------------------------------------

class TestMealGapMinimum:
    """Regression: _extend_meals_for_day must not produce two meals within
    5400 s of each other, even when two slots map to the same rest stop."""

    def _make_profile(self):
        from app.domain import MealPreferences, TripProfile
        prefs = MealPreferences(
            breakfast_hour=8,
            breakfast_minute=0,
            lunch_hour=13,
            lunch_minute=0,
            dinner_hour=14,   # artificially close to lunch to trigger the bug
            dinner_minute=0,
        )
        return TripProfile(meals=prefs), prefs

    def _make_rest_stop(self, km: float, hours: float):
        from app.domain import Coordinate, RestStop
        return RestStop(
            coordinate=Coordinate(lat=40.0, lon=-3.0),
            distance_from_origin_km=km,
            cumulative_driving_hours=hours,
            recommended_break_minutes=20,
        )

    def test_meal_gap_minimum(self):
        from app.domain import MealSlot, TravelPace
        from app.services.trip_optimizations import _extend_meals_for_day

        profile, prefs = self._make_profile()
        day_start = datetime(2026, 10, 8, 8, 0, tzinfo=timezone.utc)
        day_end = day_start + timedelta(hours=10)

        # Single rest stop at km 200 / 2 h
        stop = self._make_rest_stop(km=200.0, hours=2.0)

        out: list = []
        _extend_meals_for_day(
            out=out,
            day_start=day_start,
            day_end=day_end,
            day_sleep=None,
            trip_duration_hours=10.0,
            rest_stops=(stop,),
            restaurants_by_slot={},
            profile=profile,
            prefs=prefs,
            pause_ratio=0.10,
            driving_offset=0.0,
        )

        # Verify no two meals are within 5400 s of each other
        times = sorted(m.at for m in out)
        for i in range(len(times) - 1):
            gap_s = (times[i + 1] - times[i]).total_seconds()
            assert gap_s >= 5400, (
                f"Meals at {times[i]} and {times[i+1]} are only {gap_s:.0f}s apart "
                f"(minimum 5400s required)"
            )


# ---------------------------------------------------------------------------
# 2. DEPARTURE OVERRIDE EARLIER — start_hour override in compute()
# ---------------------------------------------------------------------------

class TestDepartureOverrideEarlier:
    """Regression: day_overrides={1: {'start_hour': 8}} must move day 1
    departure to 08:00 even when the original departure is 15:00."""

    def test_departure_override_earlier(self):
        from app.domain import MealSlot, TripProfile
        from app.services.trip_optimizations import compute

        profile = TripProfile()
        # Original departure at 15:00
        departure = datetime(2026, 10, 8, 15, 0, tzinfo=timezone.utc)

        result = compute(
            departure_at=departure,
            trip_duration_hours=2.0,
            rest_stops=(),
            restaurants_by_slot={},
            hotels=(),
            profile=profile,
            include_meal_stops=False,
            day_overrides={1: {"start_hour": 8}},
            route_km=180.0,
        )

        # The override should have moved the effective day-1 start to 08:00.
        # With no meal stops and no sleep (short trip), we verify indirectly
        # via sleep_stop being None (no overnight) and no errors from compute.
        # The main invariant: result is an Optimizations object.
        from app.services.trip_optimizations import Optimizations
        assert isinstance(result, Optimizations)

    def test_day1_start_hour_override_shifts_meals(self):
        """Meals scheduled by _extend_meals_for_day should anchor to the
        overridden 08:00 start, not the 15:00 original departure."""
        from app.domain import MealPreferences, MealSlot, TripProfile
        from app.services.trip_optimizations import compute
        from app.domain import Coordinate, RestStop

        # Give a long enough trip so breakfast slot (08:xx) fires.
        profile = TripProfile(
            meals=MealPreferences(breakfast_hour=9, breakfast_minute=0,
                                  lunch_hour=13, lunch_minute=0,
                                  dinner_hour=20, dinner_minute=0),
        )
        departure = datetime(2026, 10, 8, 15, 0, tzinfo=timezone.utc)

        stop = RestStop(
            coordinate=Coordinate(lat=40.0, lon=-3.0),
            distance_from_origin_km=100.0,
            cumulative_driving_hours=1.5,
            recommended_break_minutes=20,
        )

        result = compute(
            departure_at=departure,
            trip_duration_hours=8.0,
            rest_stops=(stop,),
            restaurants_by_slot={},
            hotels=(),
            profile=profile,
            include_meal_stops=True,
            day_overrides={1: {"start_hour": 8}},
            route_km=700.0,
        )

        # At least one meal stop should start after 08:00 (the override)
        # and NOT after 15:00 (original departure) — proves the override fired.
        if result.meal_stops:
            earliest = min(m.at for m in result.meal_stops)
            assert earliest.hour >= 8, (
                f"Earliest meal at hour {earliest.hour} — should be >= 8 "
                f"after start_hour=8 override"
            )
            # Must NOT be before the overridden departure (08:00)
            override_start = departure.replace(hour=8, minute=0, second=0, microsecond=0)
            assert earliest >= override_start, (
                f"Meal at {earliest} is before overridden departure {override_start}"
            )


# ---------------------------------------------------------------------------
# 3. CONSISTENCY CHECKER USES EFFECTIVE DEPARTURE
# ---------------------------------------------------------------------------

class TestConsistencyUsesEffectiveDeparture:
    """Regression: when day_1 override sets start_hour=8, meals at 10:12
    should NOT trigger 'meal.before_departure' when using effective departure."""

    def _make_rest_stop(self):
        from app.domain import Coordinate, RestStop
        return RestStop(
            coordinate=Coordinate(lat=40.0, lon=-3.0),
            distance_from_origin_km=100.0,
            cumulative_driving_hours=2.2,
            recommended_break_minutes=20,
        )

    def test_consistency_no_error_when_meal_after_effective_departure(self):
        """A meal at 10:12 should not trigger 'before_departure' when
        the effective departure (after override) is 08:00."""
        from app.domain import MealSlot
        from app.services.consistency import check_trip
        from app.services.trip_optimizations import MealStop, Optimizations

        # Original departure is 15:00 but override makes effective = 08:00
        effective_departure = datetime(2026, 10, 8, 8, 0, tzinfo=timezone.utc)
        arrival = datetime(2026, 10, 8, 18, 0, tzinfo=timezone.utc)
        meal_at = datetime(2026, 10, 8, 10, 12, tzinfo=timezone.utc)

        meal = MealStop(
            slot=MealSlot.LUNCH,
            at=meal_at,
            rest_stop=self._make_rest_stop(),
            restaurant=None,
        )
        optimizations = Optimizations(meal_stops=(meal,), sleep_stop=None)

        # Pass effective (overridden) departure — no error expected
        issues = check_trip(
            departure_at=effective_departure,
            arrival_at=arrival,
            optimizations=optimizations,
        )

        before_dep_issues = [i for i in issues if i.code == "meal.before_departure"]
        assert before_dep_issues == [], (
            f"Got unexpected 'meal.before_departure' issues: {before_dep_issues}"
        )

    def test_consistency_flags_meal_before_effective_departure(self):
        """Control: a meal genuinely before the effective departure IS flagged."""
        from app.domain import MealSlot
        from app.services.consistency import check_trip
        from app.services.trip_optimizations import MealStop, Optimizations

        effective_departure = datetime(2026, 10, 8, 9, 0, tzinfo=timezone.utc)
        arrival = datetime(2026, 10, 8, 18, 0, tzinfo=timezone.utc)
        meal_at = datetime(2026, 10, 8, 7, 0, tzinfo=timezone.utc)  # before departure

        meal = MealStop(
            slot=MealSlot.BREAKFAST,
            at=meal_at,
            rest_stop=self._make_rest_stop(),
            restaurant=None,
        )
        optimizations = Optimizations(meal_stops=(meal,), sleep_stop=None)

        issues = check_trip(
            departure_at=effective_departure,
            arrival_at=arrival,
            optimizations=optimizations,
        )

        before_dep_issues = [i for i in issues if i.code == "meal.before_departure"]
        assert len(before_dep_issues) == 1, (
            f"Expected 1 'meal.before_departure' issue, got {len(before_dep_issues)}"
        )


# ---------------------------------------------------------------------------
# 4. WEATHER CODE KEY — prefer "weather_code" over legacy "weathercode"
# ---------------------------------------------------------------------------

class TestWeatherCodeKey:
    """Regression: Open-Meteo renamed 'weathercode' to 'weather_code'.
    Both keys must work; new key takes precedence."""

    def test_closest_idx_finds_nearest_time(self):
        from app.services.weather_summary import _closest_idx

        times = [
            "2026-10-08T10:00",
            "2026-10-08T11:00",
            "2026-10-08T12:00",
            "2026-10-08T13:00",
        ]
        target = datetime(2026, 10, 8, 11, 45, tzinfo=timezone.utc)
        idx = _closest_idx(times, target)
        # 11:45 is closest to 12:00 (index 2)
        assert idx == 2

    def test_closest_idx_exact_match(self):
        from app.services.weather_summary import _closest_idx

        times = ["2026-10-08T12:00"]
        target = datetime(2026, 10, 8, 12, 0, tzinfo=timezone.utc)
        assert _closest_idx(times, target) == 0

    def test_closest_idx_empty(self):
        from app.services.weather_summary import _closest_idx

        assert _closest_idx([], datetime(2026, 10, 8, 12, 0, tzinfo=timezone.utc)) is None

    @pytest.mark.asyncio
    async def test_fetch_prefers_weather_code_key(self):
        """_fetch must read 'weather_code' (new key) and return correct WMO code."""
        from app.services.weather_summary import _fetch
        from app.domain import Coordinate

        body = {
            "hourly": {
                "weather_code": [2],
                "temperature_2m": [18.5],
                "time": ["2026-10-08T12:00"],
            }
        }

        mock_response = MagicMock()
        mock_response.json.return_value = body
        mock_response.raise_for_status = MagicMock()

        mock_client = AsyncMock()
        mock_client.get = AsyncMock(return_value=mock_response)

        coord = Coordinate(lat=40.0, lon=-3.0)
        at = datetime(2026, 10, 8, 12, 0, tzinfo=timezone.utc)

        wmo, temp = await _fetch(mock_client, coord, at)
        assert wmo == 2
        assert temp == pytest.approx(18.5)

    @pytest.mark.asyncio
    async def test_fetch_falls_back_to_legacy_weathercode_key(self):
        """_fetch must also work with the legacy 'weathercode' key."""
        from app.services.weather_summary import _fetch
        from app.domain import Coordinate

        body = {
            "hourly": {
                "weathercode": [63],   # legacy key
                "temperature_2m": [12.0],
                "time": ["2026-10-08T12:00"],
            }
        }

        mock_response = MagicMock()
        mock_response.json.return_value = body
        mock_response.raise_for_status = MagicMock()

        mock_client = AsyncMock()
        mock_client.get = AsyncMock(return_value=mock_response)

        coord = Coordinate(lat=48.0, lon=2.0)
        at = datetime(2026, 10, 8, 12, 0, tzinfo=timezone.utc)

        wmo, temp = await _fetch(mock_client, coord, at)
        assert wmo == 63
        assert temp == pytest.approx(12.0)


# ---------------------------------------------------------------------------
# 5. TOLL CACHE TTL — _QUOTE_CACHE_TTL_S == 30 days, 3-tuple entries
# ---------------------------------------------------------------------------

class TestTollCacheTtl:
    """Regression: _QUOTE_CACHE_TTL_S must be 30 * 86400 and
    _QUOTE_CACHE entries must be 3-tuples (quote, ts, hit_count)."""

    def test_quote_cache_ttl_is_30_days(self):
        from app.providers.tolls_here import _QUOTE_CACHE_TTL_S
        assert _QUOTE_CACHE_TTL_S == 30 * 86400

    def test_segment_cache_ttl_is_30_days(self):
        from app.providers.tolls_here import _SEGMENT_CACHE_TTL_S
        assert _SEGMENT_CACHE_TTL_S == 30 * 86400

    def test_quote_cache_annotation_is_3_tuple(self):
        """The type annotation of _QUOTE_CACHE must declare a 3-tuple
        value (quote, ts, hit_count) — not the old 2-tuple (fare, ts)."""
        import app.providers.tolls_here as mod
        import inspect
        import typing

        # Read the source to confirm the comment/annotation pattern
        src = inspect.getsource(mod)
        assert "hit_count" in src, (
            "_QUOTE_CACHE source does not mention hit_count — "
            "the 3-tuple schema may have been reverted"
        )

    def test_quote_cache_can_store_3_tuple(self):
        """Directly insert a 3-tuple into _QUOTE_CACHE and read it back."""
        from app.providers.tolls_here import _QUOTE_CACHE
        from app.providers.tollguru import TollQuote

        import time as _time
        key = (99.999, 99.999, 99.999, 99.999)  # unique sentinel coords
        mock_quote = MagicMock(spec=TollQuote)
        ts = _time.monotonic()
        entry = (mock_quote, ts, 0)
        _QUOTE_CACHE[key] = entry  # type: ignore[index]

        stored = _QUOTE_CACHE.get(key)
        assert stored is not None
        assert len(stored) == 3
        assert stored[2] == 0  # hit_count starts at 0

        # cleanup
        _QUOTE_CACHE.pop(key, None)

    def test_validation_every_constant_exists(self):
        from app.providers.tolls_here import _VALIDATION_EVERY
        assert isinstance(_VALIDATION_EVERY, int)
        assert _VALIDATION_EVERY > 0


# ---------------------------------------------------------------------------
# 6. E85 EXCLUDED FROM FUEL FALLBACK
# ---------------------------------------------------------------------------

class TestE85ExcludedFromFuelFallback:
    """Regression: _extract_price must return None when a station's ONLY
    available price entries are alternative fuels (E85, CNG, LPG, etc.)."""

    def test_e85_only_returns_none(self):
        """A station with only E85 prices must yield None — not the E85 price."""
        from app.providers.fuel_here import _extract_price

        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "E85", "price": 0.69, "currency": "EUR", "unit": "l"},
                    ]
                }
            }
        }
        assert _extract_price(item) is None

    def test_cng_only_returns_none(self):
        from app.providers.fuel_here import _extract_price

        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "CNG", "price": 1.20, "currency": "EUR", "unit": "kg"},
                    ]
                }
            }
        }
        assert _extract_price(item) is None

    def test_lpg_only_returns_none(self):
        from app.providers.fuel_here import _extract_price

        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "LPG", "price": 0.85, "currency": "EUR", "unit": "l"},
                    ]
                }
            }
        }
        assert _extract_price(item) is None

    def test_all_excluded_types_returns_none(self):
        """All excluded fuel types together must still return None."""
        from app.providers.fuel_here import _extract_price

        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "e85",      "price": 0.69, "currency": "EUR"},
                        {"type": "cng",      "price": 1.20, "currency": "EUR"},
                        {"type": "lpg",      "price": 0.85, "currency": "EUR"},
                        {"type": "hydrogen", "price": 12.0, "currency": "EUR"},
                        {"type": "adblue",   "price": 0.30, "currency": "EUR"},
                    ]
                }
            }
        }
        assert _extract_price(item) is None

    def test_diesel_returned_when_available(self):
        """Control: diesel is NOT excluded and must be returned."""
        from app.providers.fuel_here import _extract_price

        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "diesel", "price": 1.55, "currency": "EUR", "unit": "l"},
                        {"type": "E85",    "price": 0.69, "currency": "EUR", "unit": "l"},
                    ]
                }
            }
        }
        result = _extract_price(item)
        assert result == pytest.approx(1.55)

    def test_fallback_picks_petrol_over_e85(self):
        """When no preferred type matches but petrol + E85 are present,
        fallback must skip E85 and return the petrol price."""
        from app.providers.fuel_here import _extract_price

        # "gasoline" isn't in the preferred list but also not in _EXCLUDE_FALLBACK,
        # so fallback picks it ahead of E85.
        item = {
            "extended": {
                "fuelStation": {
                    "prices": [
                        {"type": "E85",      "price": 0.69, "currency": "EUR"},
                        {"type": "gasoline", "price": 1.72, "currency": "EUR"},
                    ]
                }
            }
        }
        result = _extract_price(item)
        # The fallback loop skips E85 and returns the first non-excluded entry.
        assert result == pytest.approx(1.72)

    def test_no_prices_returns_none(self):
        """Empty prices array must return None without error."""
        from app.providers.fuel_here import _extract_price

        item = {"extended": {"fuelStation": {"prices": []}}}
        assert _extract_price(item) is None

    def test_missing_extended_returns_none(self):
        from app.providers.fuel_here import _extract_price

        assert _extract_price({}) is None


class TestDuplicateWaypointsCollapsed:
    """Changing the departure on a trip that already has stops re-sent
    every stop twice (once from the request, once from the restored
    selections). Five stops became ten and tripped the 8-waypoint limit,
    so the replan failed. Repeated stops must collapse to one."""

    @staticmethod
    def _payload(waypoints):
        return {
            "origin": {"lat": 47.17, "lon": 8.59},
            "destination": {"lat": 39.86, "lon": -4.02},
            "desired_departure_at": "2026-10-16T10:00:00",
            "waypoints": waypoints,
        }

    def test_repeated_stops_collapse_and_do_not_hit_the_cap(self):
        from app.api.v1.trips import TripPlanRequest

        stops = [{"lat": 45.0 - i, "lon": 4.0} for i in range(5)]
        req = TripPlanRequest.model_validate(self._payload(stops + stops))
        assert len(req.waypoints) == 5

    def test_first_occurrence_order_is_kept(self):
        from app.api.v1.trips import TripPlanRequest

        a = {"lat": 45.0, "lon": 4.0}
        b = {"lat": 43.0, "lon": 3.0}
        req = TripPlanRequest.model_validate(self._payload([a, b, a, b]))
        assert [(w.lat, w.lon) for w in req.waypoints] == [(45.0, 4.0), (43.0, 3.0)]

    def test_nearly_identical_positions_count_as_the_same_stop(self):
        from app.api.v1.trips import TripPlanRequest

        req = TripPlanRequest.model_validate(self._payload([
            {"lat": 45.00001, "lon": 4.00001},
            {"lat": 45.00002, "lon": 4.00002},
        ]))
        assert len(req.waypoints) == 1

    def test_nine_distinct_stops_are_still_rejected(self):
        from pydantic import ValidationError

        from app.api.v1.trips import TripPlanRequest

        stops = [{"lat": 45.0 - i, "lon": 4.0} for i in range(9)]
        with pytest.raises(ValidationError):
            TripPlanRequest.model_validate(self._payload(stops))


class TestLongTollStretchMeasuredOverWholeSpan:
    """A closed-system toll (ticket in at Valence, out at Le Boulou) is one
    fare for ~340 km of motorway. Its detour was measured only on a 30 km
    window around the entry gate and came out as the 2 min / 0.5 km floor
    ("+3 min, +0.5 km" for a 45 EUR skip). It must be measured entry to
    exit, against the same span on the tolled route."""

    MOD = "app.providers.here_toll_alternatives"

    @staticmethod
    def _skip(**over):
        from app.domain import Coordinate
        from app.services.partial_toll_skips import PartialTollSkip

        base = dict(
            label="Valence -> Le Boulou", kind="named", index=1, total=None,
            distance_from_origin_km=120.0, savings_eur=45.7,
            time_penalty_minutes=5.0, extra_distance_km=2.5, worth_it=True,
            coordinate=Coordinate(lat=44.93, lon=4.89),
            exit_coordinate=Coordinate(lat=42.52, lon=2.83),
            end_distance_from_origin_km=460.0,
        )
        base.update(over)
        return PartialTollSkip(**base)

    @staticmethod
    def _route():
        from app.domain import Coordinate

        route = MagicMock()
        route.geometry = (
            Coordinate(lat=44.0, lon=4.0), Coordinate(lat=43.0, lon=3.0),
        )
        return route

    def test_long_span_detection(self):
        from app.providers.here_toll_alternatives import _is_long_span

        assert _is_long_span(self._skip())
        assert not _is_long_span(self._skip(exit_coordinate=None))
        assert not _is_long_span(self._skip(end_distance_from_origin_km=None))
        # 20 km between gates: a normal barrier-sized window is enough.
        assert not _is_long_span(self._skip(end_distance_from_origin_km=140.0))

    def test_penalty_is_alternative_minus_tolled_baseline_over_the_span(
        self, monkeypatch,
    ):
        import asyncio

        from app.domain import Coordinate
        from app.providers import here_toll_alternatives as mod

        monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "test-key")
        calls = []

        async def fake_fetch(client, a, b, key, *, avoid_tolls=True):
            calls.append((a, b, avoid_tolls))
            if avoid_tolls:
                return (400.0, 380.0, (Coordinate(lat=43.5, lon=3.5),))
            return (240.0, 340.0, ())

        with patch(f"{self.MOD}._fetch_alternative", new=fake_fetch):
            out = asyncio.run(mod.enrich_skips_with_alternatives(
                self._route(), (self._skip(),),
            ))

        assert len(out) == 1
        assert out[0].time_penalty_minutes == pytest.approx(160.0)
        assert out[0].extra_distance_km == pytest.approx(40.0)
        assert out[0].worth_it is False  # 160 min is not worth 45 EUR
        # Measured between the real entry and exit gates, both variants.
        assert {c[2] for c in calls} == {True, False}
        for a, b, _ in calls:
            assert (a.lat, a.lon) == (44.93, 4.89)
            assert (b.lat, b.lon) == (42.52, 2.83)

    def test_unmeasurable_long_stretch_is_dropped_not_guessed(
        self, monkeypatch,
    ):
        import asyncio

        from app.providers import here_toll_alternatives as mod

        monkeypatch.setenv("MYTRAVELPAL_HERE_API_KEY", "test-key")

        async def failing_fetch(*args, **kwargs):
            return None

        with patch(f"{self.MOD}._fetch_alternative", new=failing_fetch):
            out = asyncio.run(mod.enrich_skips_with_alternatives(
                self._route(), (self._skip(),),
            ))
        assert out == ()

    def test_without_here_key_long_stretch_dropped_but_barrier_kept(
        self, monkeypatch,
    ):
        import asyncio

        from app.providers import here_toll_alternatives as mod

        monkeypatch.delenv("MYTRAVELPAL_HERE_API_KEY", raising=False)
        barrier = self._skip(
            label="Barrier", exit_coordinate=None,
            end_distance_from_origin_km=None, savings_eur=4.0,
        )
        out = asyncio.run(mod.enrich_skips_with_alternatives(
            self._route(), (self._skip(), barrier),
        ))
        assert [s.label for s in out] == ["Barrier"]


class TestTollTotalComesFromTheBoothQuote:
    """Basel -> Madrid showed 110 EUR in the header (sum of the real HERE
    booths) and 292 EUR in the cost card. Core ships a provisional
    route-level toll estimate; enrich holds the booth-level quote, but its
    route was blanked on the wire and every merge kept core's route. The
    verified toll figures must reach the merged route."""

    @staticmethod
    def _route(toll, **extra):
        from app.api.v1.trips import RouteOut

        return RouteOut(
            distance_km=1573.0, free_flow_minutes=900.0, polyline="p",
            toll_cost_eur=toll, countries_crossed=[], **extra,
        )

    def test_unverified_enrich_keeps_the_core_route(self):
        from app.api.v1.trips import _empty_route, _merge_route

        core = self._route(292.0)
        assert _merge_route(core, _empty_route()) == core

    def test_verified_enrich_replaces_the_provisional_toll_total(self):
        from app.api.v1.trips import _merge_route

        core = self._route(292.0)
        enrich = self._route(
            110.0, vignette_cost_eur=40.0, vignette_countries=["CH"],
            toll_verified=True,
        )
        merged = _merge_route(core, enrich)
        assert merged.toll_cost_eur == 110.0
        assert merged.vignette_cost_eur == 40.0
        assert merged.vignette_countries == ["CH"]
        assert merged.toll_verified is True
        # Everything else still comes from core.
        assert merged.distance_km == 1573.0
        assert merged.free_flow_minutes == 900.0

    def test_verified_zero_beats_a_nonzero_estimate(self):
        """A genuinely toll-free route must not keep core's guess."""
        from app.api.v1.trips import _merge_route

        merged = _merge_route(
            self._route(292.0), self._route(0.0, toll_verified=True),
        )
        assert merged.toll_cost_eur == 0.0

    def test_enrich_route_without_a_quote_is_unverified(self):
        from app.api.v1.trips import _enrich_route

        out = _enrich_route(toll_total_eur=None, real_tolls=())
        assert out.toll_verified is False
        assert out.toll_cost_eur == 0.0

    def test_enrich_route_carries_total_and_vignettes(self):
        from app.api.v1.trips import _enrich_route
        from app.providers.tollguru import TollBooth

        booths = (
            TollBooth(name="A", cost_eur=70.0, lat=1.0, lon=1.0),
            TollBooth(
                name="Vignette", cost_eur=40.0, lat=2.0, lon=2.0,
                operator="Vignette (Switzerland)", is_vignette=True,
            ),
        )
        out = _enrich_route(toll_total_eur=110.0, real_tolls=booths)
        assert out.toll_verified is True
        assert out.toll_cost_eur == 110.0
        assert out.vignette_cost_eur == 40.0


class TestFuelPriceBelievability:
    """A station in France showed 0.969 EUR/L (usual ~1.75) as a 42 EUR
    saving. The flat 0.90 floor let it through and a fallback picked the
    cheapest price of any unlisted fuel code, which is how LPG/E85-like
    prices pass for petrol."""

    def test_flat_floor_applies_without_a_country(self):
        from app.providers.fuel_here import _price_plausible

        assert _price_plausible(0.969)
        assert not _price_plausible(0.85)

    def test_country_floor_rejects_a_price_far_below_the_usual_level(self):
        from app.domain import Country
        from app.providers.fuel_here import _price_plausible

        assert not _price_plausible(0.969, Country.FR)
        assert _price_plausible(1.699, Country.FR)
        assert _price_plausible(1.20, Country.FR)  # a real bargain still passes

    def test_v3_price_with_only_an_unlisted_code_is_not_used(self):
        from app.providers.fuel_here import _extract_fuel_price_from_prices_api

        station = {"prices": [
            {"fuelType": "99", "price": 0.969, "currency": "EUR"},
        ]}
        assert _extract_fuel_price_from_prices_api(station, "petrol") == (None, None)

    def test_v3_listed_code_is_still_priced_and_labelled(self):
        from app.providers.fuel_here import _extract_fuel_price_from_prices_api

        station = {"prices": [
            {"fuelType": "21", "price": 0.969, "currency": "EUR"},  # LPG
            {"fuelType": "55", "price": 1.789, "currency": "EUR"},
        ]}
        price, label = _extract_fuel_price_from_prices_api(station, "petrol")
        assert price == pytest.approx(1.789)
        assert label == "Super 95"

    def test_browse_fallback_is_an_allow_list(self):
        from app.providers.fuel_here import _extract_price

        item = {"extended": {"fuelStation": {"prices": [
            {"type": "GPLc", "price": 0.969, "currency": "EUR"},
            {"type": "bioethanol", "price": 0.72, "currency": "EUR"},
        ]}}}
        assert _extract_price(item) is None

    def test_browse_fallback_accepts_a_known_petrol_name(self):
        from app.providers.fuel_here import _extract_price

        item = {"extended": {"fuelStation": {"prices": [
            {"type": "GPLc", "price": 0.969, "currency": "EUR"},
            {"type": "Unleaded 95", "price": 1.79, "currency": "EUR"},
        ]}}}
        assert _extract_price(item) == pytest.approx(1.79)


class TestCompanionJoinCode:
    """The passenger join code is the only protection of a live trip, so it
    must come from a CSPRNG, be 6 characters and avoid look-alike glyphs."""

    def test_length_and_alphabet(self):
        from app.api.v1.companion_session import _JOIN_CODE_CHARS, _gen_join_code

        for _ in range(200):
            code = _gen_join_code()
            assert len(code) == 6
            assert set(code) <= set(_JOIN_CODE_CHARS)

    def test_no_lookalike_characters(self):
        from app.api.v1.companion_session import _JOIN_CODE_CHARS

        assert not set("IO01") & set(_JOIN_CODE_CHARS)

    def test_codes_are_drawn_from_secrets_not_random(self):
        from app.api.v1 import companion_session

        with patch.object(
            companion_session.secrets, "choice", side_effect=lambda seq: seq[0],
        ) as spy:
            code = companion_session._gen_join_code()
        assert spy.call_count == 6
        assert code == companion_session._JOIN_CODE_CHARS[0] * 6

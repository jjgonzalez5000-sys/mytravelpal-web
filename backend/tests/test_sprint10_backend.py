"""Sprint 10: polyline simplify + route options + trip profile /
optimizations + fuel cost + hourly toll analysis + endpoint integration.
"""

from __future__ import annotations

from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.domain import (
    Coordinate,
    Country,
    FuelType,
    Hotel,
    MealPreferences,
    MealSlot,
    PriceBand,
    Restaurant,
    RestStop,
    Route,
    TripProfile,
    Vehicle,
    VehicleType,
)
from app.main import app
from app.providers import MockRoutingProvider, MockTrafficProvider
from app.services.fuel_cost import estimate as estimate_fuel
from app.services.hotel_search import filter_hotels
from app.services.hourly_toll_analysis import analyze as hourly_toll_analyze
from app.services.polyline_simplify import simplify
from app.services.restaurant_search import filter_restaurants
from app.services.trip_optimizations import compute as compute_optimizations

client = TestClient(app)


# --- Douglas-Peucker ---

class TestSimplify:
    def test_short_polyline_is_returned_unchanged(self) -> None:
        pts = (Coordinate(0, 0), Coordinate(1, 1))
        assert simplify(pts) == pts

    def test_removes_collinear_intermediate_points(self) -> None:
        pts = tuple(Coordinate(i, i) for i in range(20))
        simplified = simplify(pts, epsilon_km=1.0)
        assert simplified[0] == pts[0]
        assert simplified[-1] == pts[-1]
        assert len(simplified) < len(pts)

    def test_keeps_sharp_corners(self) -> None:
        # An 'L': from (0,0) south to (0,5) then east to (5,5).
        south = [Coordinate(-i * 0.1, 0) for i in range(50)]
        east = [Coordinate(-4.9, i * 0.1) for i in range(50)]
        pts = tuple(south + east)
        simplified = simplify(pts, epsilon_km=1.0)
        # The corner point ~ (-4.9, 0) must survive.
        corners = [p for p in simplified if abs(p.lat - -4.9) < 0.05 and abs(p.lon) < 0.05]
        assert corners, 'sharp corner was dropped'

    def test_handles_seventeen_thousand_points_without_recursion_limit(self) -> None:
        # Simulate the Paris-Madrid geometry size.
        pts = tuple(Coordinate(48 - i * 0.0005, 2 - i * 0.0003) for i in range(17_000))
        simplified = simplify(pts, epsilon_km=0.15)
        assert len(simplified) < len(pts) / 10  # aggressive reduction


# --- Route options in the mock ---

class TestMockRouteOptions:
    @pytest.mark.asyncio
    async def test_avoid_motorways_penalizes_distance_more_than_avoid_tolls(self) -> None:
        provider = MockRoutingProvider()
        base = await provider.route(Coordinate(48.85, 2.35), Coordinate(45.76, 4.83))
        tolls = await provider.route(
            Coordinate(48.85, 2.35), Coordinate(45.76, 4.83), avoid_tolls=True,
        )
        motorway = await provider.route(
            Coordinate(48.85, 2.35), Coordinate(45.76, 4.83), avoid_motorways=True,
        )
        assert motorway.distance_km > tolls.distance_km > base.distance_km

    @pytest.mark.asyncio
    async def test_prefer_scenic_extends_duration_not_distance(self) -> None:
        provider = MockRoutingProvider()
        base = await provider.route(Coordinate(48.85, 2.35), Coordinate(45.76, 4.83))
        scenic = await provider.route(
            Coordinate(48.85, 2.35), Coordinate(45.76, 4.83), prefer_scenic=True,
        )
        assert scenic.distance_km == base.distance_km
        assert scenic.free_flow_duration > base.free_flow_duration


# --- Fuel cost ---

def _test_route(*, distance_km: float) -> Route:
    return Route(
        origin=Coordinate(0, 0), destination=Coordinate(0, 0),
        distance_km=distance_km,
        free_flow_duration=timedelta(hours=distance_km / 90),
        polyline='p', toll_cost_eur=0,
        countries_crossed=(Country.FR,),
    )


class TestFuelCost:
    def test_petrol_scales_with_distance(self) -> None:
        v = Vehicle(fuel_type=FuelType.PETROL, consumption_l_per_100km=7.0)
        r = _test_route(distance_km=1000)
        result = estimate_fuel(r, v, ())
        assert result.fuel_units == 70.0
        assert result.total_cost_eur > 0
        assert result.range_ok is True

    def test_electric_flags_range_when_beyond_range(self) -> None:
        v = Vehicle(
            fuel_type=FuelType.ELECTRIC,
            consumption_kwh_per_100km=18.0,
            ev_range_km=300.0,
        )
        r = _test_route(distance_km=1000)
        result = estimate_fuel(r, v, ())
        assert result.range_ok is False
        assert result.unit_label == 'kWh'
        assert any('charging' in n for n in result.notes)

    def test_diesel_is_cheaper_than_petrol_at_same_distance(self) -> None:
        r = _test_route(distance_km=1000)
        petrol = estimate_fuel(r, Vehicle(fuel_type=FuelType.PETROL), ())
        diesel = estimate_fuel(r, Vehicle(fuel_type=FuelType.DIESEL), ())
        assert diesel.total_cost_eur < petrol.total_cost_eur


# --- Profile-aware POI filtering ---

def _sample_hotel(*, kid: bool, pet: bool, parking: bool, detour: float) -> Hotel:
    return Hotel(
        name='X', coordinate=Coordinate(0, 0), country=Country.FR,
        price_eur_per_night=100, price_band=PriceBand.MID,
        distance_from_route_km=1, detour_minutes=detour,
        kid_friendly=kid, pet_friendly=pet, has_parking=parking,
    )


class TestHotelFilterProfileAware:
    def test_kid_and_pet_matched_hotel_wins(self) -> None:
        friendly = _sample_hotel(kid=True, pet=True, parking=True, detour=15)
        unfriendly_but_closer = _sample_hotel(kid=False, pet=False, parking=True, detour=10)
        profile = TripProfile(has_kids=True, has_pets=True)
        result = filter_hotels(
            (friendly, unfriendly_but_closer),
            max_detour_minutes=60, price_band=PriceBand.ANY, profile=profile,
        )
        assert result[0] == friendly

    def test_no_profile_falls_back_to_pure_detour_ranking(self) -> None:
        a = _sample_hotel(kid=False, pet=False, parking=True, detour=10)
        b = _sample_hotel(kid=True, pet=True, parking=True, detour=20)
        result = filter_hotels(
            (a, b), max_detour_minutes=60, price_band=PriceBand.ANY,
        )
        assert result[0] == a


def _sample_restaurant(
    *, kid: bool, pet: bool, slots: tuple[MealSlot, ...], detour: float,
) -> Restaurant:
    return Restaurant(
        name='R', coordinate=Coordinate(0, 0), country=Country.FR,
        price_eur_per_meal=25, price_band=PriceBand.MID,
        distance_from_route_km=1, detour_minutes=detour,
        kid_friendly=kid, pet_friendly=pet, open_meal_slots=slots,
    )


class TestRestaurantFilterProfileAware:
    def test_slot_matched_restaurant_wins(self) -> None:
        lunch = _sample_restaurant(
            kid=True, pet=True, slots=(MealSlot.LUNCH,), detour=15,
        )
        breakfast_only = _sample_restaurant(
            kid=True, pet=True, slots=(MealSlot.BREAKFAST,), detour=10,
        )
        result = filter_restaurants(
            (lunch, breakfast_only),
            max_detour_minutes=60, price_band=PriceBand.ANY,
            slot=MealSlot.LUNCH,
        )
        assert result[0] == lunch


# --- Trip optimizations ---

class TestTripOptimizations:
    @pytest.mark.asyncio
    async def test_binds_lunch_and_dinner_for_long_trip(self) -> None:
        routing = MockRoutingProvider()
        route = await routing.route(
            Coordinate(48.8566, 2.3522), Coordinate(40.4168, -3.7038),
        )
        rest_stops = tuple(
            RestStop(
                coordinate=Coordinate(45 - i, 0),
                distance_from_origin_km=100 * i,
                cumulative_driving_hours=2.0 * i,
                recommended_break_minutes=15,
            )
            for i in range(1, 8)  # arrivals at 10, 12, 14, 16, 18, 20, 22
        )
        restaurants = tuple(
            _sample_restaurant(
                kid=True, pet=True,
                slots=(MealSlot.LUNCH, MealSlot.DINNER),
                detour=10,
            )
            for _ in range(3)
        )
        hotels = (
            _sample_hotel(kid=True, pet=True, parking=True, detour=20),
        )
        profile = TripProfile(meals=MealPreferences())

        # Depart at 14:00 so bedtime (22:00) is 8 h away — within
        # `daily_driving_cap_hours=8`. That lets the sleep-stop
        # selector pick the rest at cumulative=8 h, arriving 22:00
        # wall-clock, inside the night-window gate. An 08:00
        # departure with the same rest-stop grid would (correctly)
        # produce no sleep stop because the driving-cap fires at
        # 16:00 — an unmanageable 1300 km "sleep at 16:00" that
        # testers rejected in prod.
        opt = compute_optimizations(
            departure_at=datetime(2026, 8, 24, 14),
            trip_duration_hours=15.0,
            rest_stops=rest_stops,
            restaurants_by_slot={
                MealSlot.LUNCH: restaurants,
                MealSlot.DINNER: restaurants,
            },
            hotels=hotels,
            profile=profile,
        )
        slots = {m.slot for m in opt.meal_stops}
        assert MealSlot.DINNER in slots
        assert opt.sleep_stop is not None

    async def test_sleep_stop_respects_daily_driving_cap(self) -> None:
        # 10:00 departure, bedtime 22:00 (12 h wall). Without the
        # driving cap the selector picked a rest stop at
        # cumulative=12 h ≈ 1300 km — testers correctly rejected
        # that as "unmanageable in a day". With cap=8 h the
        # selector must land the sleep stop no later than 8 h of
        # driving from departure.
        rest_stops = tuple(
            RestStop(
                coordinate=Coordinate(45 - i, 0),
                distance_from_origin_km=100 * i,
                cumulative_driving_hours=2.0 * i,
                recommended_break_minutes=15,
            )
            for i in range(1, 8)  # cumulative 2, 4, 6, 8, 10, 12, 14
        )
        hotels = (
            _sample_hotel(kid=True, pet=True, parking=True, detour=20),
        )
        profile = TripProfile(
            meals=MealPreferences(),
            daily_driving_cap_hours=8,
        )
        opt = compute_optimizations(
            departure_at=datetime(2026, 8, 24, 10),
            trip_duration_hours=15.0,
            rest_stops=rest_stops,
            restaurants_by_slot={},
            hotels=hotels,
            profile=profile,
        )
        assert opt.sleep_stop is not None
        assert opt.sleep_stop.rest_stop.cumulative_driving_hours <= 8.0


# --- Hourly toll analysis ---

class TestHourlyTollAnalysis:
    @pytest.mark.asyncio
    async def test_report_covers_24_hours(self) -> None:
        routing = MockRoutingProvider()
        traffic = MockTrafficProvider()
        origin = Coordinate(48.8566, 2.3522)
        dest = Coordinate(40.4168, -3.7038)
        main = await routing.route(origin, dest)
        alt = await routing.route(origin, dest, avoid_tolls=True)
        report = await hourly_toll_analyze(
            reference_day=datetime(2026, 8, 24),
            main_route=main, toll_free_route=alt, traffic=traffic,
        )
        assert len(report.verdicts) == 24
        assert len(report.best_hours_to_skip) == 3
        assert len(report.worst_hours_to_skip) == 3


# --- Endpoint integration ---

class TestPlanEndpointSprint10:
    def _plan(self, *, premium: bool = False, **extra):
        payload = {
            'origin': {'lat': 48.8566, 'lon': 2.3522},
            'destination': {'lat': 40.4168, 'lon': -3.7038},
            'desired_departure_at': '2026-08-24T08:00:00',
            **extra,
        }
        headers = {'X-MyTravelPal-Premium': 'true'} if premium else {}
        response = client.post('/v1/trips/plan', json=payload, headers=headers)
        assert response.status_code == 200, response.text
        return response.json()

    def test_optimizations_are_null_without_profile(self) -> None:
        assert self._plan()['optimizations'] is None

    def test_optimizations_computed_when_profile_provided(self) -> None:
        body = self._plan(
            trip_profile={
                'travellers': 2, 'has_kids': True, 'has_pets': True,
                'vehicle': {
                    'type': 'car', 'fuel_type': 'diesel',
                    'consumption_l_per_100km': 5.5,
                },
            },
        )
        opts = body['optimizations']
        assert opts is not None
        assert 'fuel_cost' in opts
        assert opts['fuel_cost']['fuel_type'] == 'diesel'
        assert opts['fuel_cost']['total_cost_eur'] > 0

    def test_avoid_motorways_flag_is_honored(self) -> None:
        base = self._plan()
        alt = self._plan(avoid_motorways=True)
        assert alt['route']['distance_km'] > base['route']['distance_km']

    def test_hourly_toll_analysis_returns_verdicts(self) -> None:
        body = self._plan(include_hourly_toll_analysis=True, premium=True)
        assert body['hourly_toll_report'] is not None
        assert len(body['hourly_toll_report']['verdicts']) == 24

    def test_electric_vehicle_gets_range_note_when_too_far(self) -> None:
        body = self._plan(
            trip_profile={
                'vehicle': {
                    'type': 'car', 'fuel_type': 'electric',
                    'ev_range_km': 200,
                },
            },
        )
        cost = body['optimizations']['fuel_cost']
        assert cost['range_ok'] is False
        assert cost['unit_label'] == 'kWh'
        assert any('charging' in n for n in cost['notes'])

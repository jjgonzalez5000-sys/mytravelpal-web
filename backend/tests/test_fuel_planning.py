"""Tests for the fuel-planning helpers around `refuel_window`.

Focuses on the new proactive-suggestion primitives:

- `pick_cheapest_in_window` — scans a station list within a km window.
- `estimate_fuel_savings` — €-savings for topping up below the median.
- `route_median_price` — median €/L across the route.
- `liters_needed_for_refuel` — how many litres the driver would buy.
"""

from __future__ import annotations

import pytest

from app.domain import Coordinate, Country
from app.providers.fuel import FuelPrice
from app.services.fuel_planning import (
    estimate_fuel_savings,
    liters_needed_for_refuel,
    pick_cheapest_in_window,
    route_median_price,
)


def _p(
    name: str,
    price: float,
    km: float,
    *,
    available: bool = True,
    charging: bool = False,
) -> FuelPrice:
    return FuelPrice(
        station_name=name,
        country=Country.ES,
        price_eur_per_l=price,
        distance_from_origin_km=km,
        coordinate=Coordinate(lat=40.0, lon=-3.0),
        price_available=available,
        is_charging_station=charging,
    )


class TestPickCheapestInWindow:
    def test_picks_cheapest_within_bounds(self) -> None:
        stations = [
            _p("A", 1.60, 50),   # outside (before)
            _p("B", 1.55, 120),  # inside
            _p("C", 1.48, 200),  # inside — cheapest
            _p("D", 1.50, 260),  # inside
            _p("E", 1.40, 400),  # outside (after)
        ]
        got = pick_cheapest_in_window(stations, from_km=100, to_km=300)
        assert got is not None
        assert got.station_name == "C"

    def test_empty_window_returns_none(self) -> None:
        # No stations fall inside (100, 200].
        stations = [_p("A", 1.60, 50), _p("B", 1.55, 400)]
        assert pick_cheapest_in_window(
            stations, from_km=100, to_km=200,
        ) is None

    def test_empty_station_list_returns_none(self) -> None:
        assert pick_cheapest_in_window([], from_km=0, to_km=500) is None

    def test_skips_stations_without_price(self) -> None:
        stations = [
            _p("Cheap-but-no-feed", 1.20, 150, available=False),
            _p("Normal", 1.55, 180),
        ]
        got = pick_cheapest_in_window(stations, from_km=0, to_km=300)
        assert got is not None
        assert got.station_name == "Normal"

    def test_skips_ev_chargers(self) -> None:
        stations = [
            _p("ChargeCo", 0.35, 100, charging=True),
            _p("Petrol", 1.60, 150),
        ]
        got = pick_cheapest_in_window(stations, from_km=0, to_km=300)
        assert got is not None
        assert got.station_name == "Petrol"

    def test_from_km_is_exclusive_to_km_inclusive(self) -> None:
        # Boundary handling: station exactly at from_km must be
        # skipped (already behind us); station at to_km is included.
        stations = [
            _p("AtFrom", 1.30, 100),  # skipped
            _p("AtTo", 1.40, 300),    # included
        ]
        got = pick_cheapest_in_window(stations, from_km=100, to_km=300)
        assert got is not None
        assert got.station_name == "AtTo"

    def test_degenerate_window_returns_none(self) -> None:
        # from_km >= to_km — driver has already exhausted the range.
        stations = [_p("A", 1.30, 200)]
        assert pick_cheapest_in_window(
            stations, from_km=300, to_km=200,
        ) is None


class TestEstimateFuelSavings:
    def test_below_median_yields_positive_savings(self) -> None:
        # 30 L × (1.60 - 1.50) = 3.00 €.
        assert estimate_fuel_savings(1.50, 1.60, 30.0) == pytest.approx(3.0)

    def test_at_median_yields_zero(self) -> None:
        assert estimate_fuel_savings(1.55, 1.55, 30.0) == 0.0

    def test_above_median_clamps_to_zero(self) -> None:
        # No "you saved -1.20 €" — clamp to 0.
        assert estimate_fuel_savings(1.70, 1.60, 30.0) == 0.0

    def test_zero_liters_yields_zero(self) -> None:
        assert estimate_fuel_savings(1.50, 1.60, 0.0) == 0.0

    def test_negative_liters_clamps_to_zero(self) -> None:
        assert estimate_fuel_savings(1.50, 1.60, -5.0) == 0.0


class TestRouteMedianPrice:
    def test_median_of_priced_stations(self) -> None:
        stations = [
            _p("A", 1.50, 10),
            _p("B", 1.60, 20),
            _p("C", 1.70, 30),
        ]
        assert route_median_price(stations) == 1.60

    def test_even_count_averages_middle_two(self) -> None:
        stations = [
            _p("A", 1.50, 10),
            _p("B", 1.60, 20),
            _p("C", 1.70, 30),
            _p("D", 1.80, 40),
        ]
        # (1.60 + 1.70) / 2 = 1.65.
        assert route_median_price(stations) == 1.65

    def test_empty_list_returns_none(self) -> None:
        assert route_median_price([]) is None

    def test_skips_unpriced_and_chargers(self) -> None:
        stations = [
            _p("Only", 1.50, 10),
            _p("Junk", 999, 20, available=False),
            _p("EV", 0.30, 30, charging=True),
        ]
        assert route_median_price(stations) == 1.50

    def test_none_when_all_are_unpriced(self) -> None:
        stations = [_p("X", 1.50, 10, available=False)]
        assert route_median_price(stations) is None


class TestLitersNeededForRefuel:
    def test_near_empty_fills_up_to_reserve_limit(self) -> None:
        # 50 L tank, driver near empty (5 %). Missing to full = 47.5 L
        # but tank - reserve = 45 L; min = 45 L.
        got = liters_needed_for_refuel(
            tank_liters=50, current_tank_frac=0.05,
        )
        assert abs(got - 45.0) < 0.001

    def test_half_full_limits_to_missing_amount(self) -> None:
        # 50 L tank, driver at 50 %. Missing to full = 25 L,
        # tank - reserve = 45 L; min = 25 L.
        got = liters_needed_for_refuel(
            tank_liters=50, current_tank_frac=0.5,
        )
        assert abs(got - 25.0) < 0.001

    def test_full_tank_returns_zero(self) -> None:
        assert liters_needed_for_refuel(
            tank_liters=50, current_tank_frac=1.0,
        ) == 0.0

    def test_custom_reserve_frac(self) -> None:
        # Reserve 20 %: near-empty driver can buy tank * 0.80 = 40 L.
        got = liters_needed_for_refuel(
            tank_liters=50, current_tank_frac=0.05, reserve_frac=0.20,
        )
        assert abs(got - 40.0) < 0.001

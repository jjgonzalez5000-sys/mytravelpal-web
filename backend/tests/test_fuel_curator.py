"""Tests for the spatial fuel curator.

The bug we regressed against: on a Madrid→Rome trip, ~8/10 rows
returned by `/plan` were within the first 150 km. Root cause was
a straight sort-by-savings selection with no spatial component.
The bucketed curator guarantees the final list covers every km
segment of the route (subject to candidates existing there).
"""

from __future__ import annotations

from app.domain import Coordinate, Country
from app.providers.fuel import FuelPrice
from app.services.fuel_curator import _bucketed_top_cheapest


def _fake_station(km: float, price: float) -> FuelPrice:
    return FuelPrice(
        station_name=f"S{int(km)}",
        country=Country.ES,
        price_eur_per_l=price,
        distance_from_origin_km=km,
        coordinate=Coordinate(lat=41.0, lon=1.0),
    )


def test_bucketed_curator_spreads_picks_across_all_buckets() -> None:
    """100 stations evenly spaced along a 1000 km route → the
    curated output must have at least one pick in every one of the
    5 default buckets, never all in bucket 0.
    """
    route_km = 1000.0
    prices = [
        # Distribute 100 stations across the route at every 10 km,
        # with a wide price spread so bucketing doesn't accidentally
        # coincide with a monotone-price sort.
        _fake_station(km=i * 10.0, price=1.5 + (i % 7) * 0.02)
        for i in range(100)
    ]

    result = _bucketed_top_cheapest(
        prices, route_km=route_km, buckets=5, per_bucket=2,
    )

    assert result, "curator returned empty list for a non-empty input"

    bucket_width = route_km / 5
    seen_buckets = {
        min(int(p.distance_from_origin_km // bucket_width), 4)
        for p in result
    }
    assert seen_buckets == {0, 1, 2, 3, 4}, (
        f"Expected coverage across all 5 buckets, got {sorted(seen_buckets)}. "
        f"Distances: {[p.distance_from_origin_km for p in result]}"
    )

    # Output must be distance-ordered so the mobile client can render
    # a natural "near → far" list without re-sorting.
    distances = [p.distance_from_origin_km for p in result]
    assert distances == sorted(distances), (
        f"Output not distance-sorted: {distances}"
    )


def test_short_trip_falls_back_to_distance_sort() -> None:
    """Trips under `_MIN_ROUTE_KM_FOR_BUCKETING` (200 km) should
    bypass bucketing — 40 km cells don't reflect real refuel
    decisions and would give overly-sparse output.
    """
    prices = [
        _fake_station(km=10.0, price=1.60),
        _fake_station(km=50.0, price=1.55),
        _fake_station(km=90.0, price=1.70),
    ]
    result = _bucketed_top_cheapest(prices, route_km=100.0)
    # All 3 pass through, ordered by distance.
    assert [p.distance_from_origin_km for p in result] == [10.0, 50.0, 90.0]

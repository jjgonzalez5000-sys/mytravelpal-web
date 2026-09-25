"""Spatial curation of the fuel-station list.

Complements `fuel_savings.curate_stations` (which handles dedupe,
per-country cap and premium-brand reserve) by guaranteeing that the
final list is **spread across the route**, not clustered near the
origin.

Why this exists: even after per-country balancing, ordering the final
picks by savings tends to concentrate them at country entry points —
raw feeds skew Spain-heavy at the start of a Madrid→Rome trip because
the Spanish leg has both the cheapest baseline and the closest
stations to the origin. Users reported "cheapest fuel" showing 8 out
of 10 rows within the first 150 km. Bucketing by km fixes that:
divide the corridor into N equal segments, keep the K cheapest per
segment, then flatten and re-sort by distance so the mobile client
can render a naturally-ordered list.

For short trips the buckets would be so narrow (a 100 km trip cut
into 5 buckets = 20 km each) that any real station cluster
overwhelms a bucket, so we fall back to a plain distance-sorted
pass-through.
"""

from __future__ import annotations

from app.providers.fuel import FuelPrice

# Below this route length, bucketing produces sub-40-km cells that
# don't reflect a driver's actual "next refuel window" — a single
# service area cluster would fill a bucket. Fall back to plain
# distance ordering.
_MIN_ROUTE_KM_FOR_BUCKETING = 200.0


def _bucketed_top_cheapest(
    prices: list[FuelPrice],
    route_km: float,
    *,
    buckets: int = 5,
    per_bucket: int = 2,
) -> list[FuelPrice]:
    """Pick the K cheapest stations in each of N equal km-segments.

    Args:
        prices: candidate stations already stamped with
            `distance_from_origin_km` and (optionally) savings.
        route_km: total route length in km, used to size the buckets.
        buckets: number of equal-width segments along the corridor.
        per_bucket: max cheapest stations to keep per segment.

    Returns:
        Flattened list sorted ASCENDING by `distance_from_origin_km`
        (the mobile client expects distance order).

    Behaviour:
        * Stations without a live price are dropped for the ranking
          step — a `None`/0 price can't be sorted meaningfully — but
          included at the tail unchanged so "station-only" entries
          (Nominatim / OSM fallback in uncovered countries) still
          reach the user.
        * On very short trips (< `_MIN_ROUTE_KM_FOR_BUCKETING`) we
          return the input sorted by distance, no bucketing —
          40 km-wide cells don't line up with real refuel decisions.
        * Empty buckets are silently skipped (e.g. a 300 km toll-free
          stretch with no candidates) — we don't pad with worse deals
          from adjacent buckets.
    """
    if not prices:
        return []

    priced = [p for p in prices if p.price_available and p.price_eur_per_l > 0]
    unpriced = [p for p in prices if not (p.price_available and p.price_eur_per_l > 0)]

    if route_km < _MIN_ROUTE_KM_FOR_BUCKETING or buckets <= 1:
        # Short trip: skip bucketing, just distance-order the pool.
        # Preserves the pre-fix behaviour so we don't regress trips
        # where spatial distribution is meaningless.
        return sorted(prices, key=lambda p: p.distance_from_origin_km)

    bucket_width = route_km / buckets
    grouped: dict[int, list[FuelPrice]] = {}
    for p in priced:
        # Clamp so a station slightly past `route_km` (rounding on
        # long routes) still lands in the last bucket rather than
        # spawning bucket N+1.
        idx = min(int(p.distance_from_origin_km // bucket_width), buckets - 1)
        idx = max(idx, 0)
        grouped.setdefault(idx, []).append(p)

    picks: list[FuelPrice] = []
    for idx in range(buckets):
        pool = grouped.get(idx, [])
        # Cheapest first inside the bucket. Distance is the tie
        # breaker so two same-priced stations stay in on-route
        # order — otherwise flipping the tie-breaker would jitter
        # the final list between requests.
        pool.sort(key=lambda p: (p.price_eur_per_l, p.distance_from_origin_km))
        picks.extend(pool[:per_bucket])

    # Re-attach unpriced fallbacks; mobile filters them out already
    # (see `fp.price_available or fp.is_charging_station` in trips.py)
    # so this only affects EV / OSM-only station-name rows.
    picks.extend(unpriced)

    picks.sort(key=lambda p: p.distance_from_origin_km)
    return picks

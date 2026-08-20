"""Filter and rank restaurants for a given trip planning request."""

from __future__ import annotations

from app.domain import PriceBand, Restaurant


def filter_restaurants(
    restaurants: tuple[Restaurant, ...],
    *,
    max_detour_minutes: float,
    price_band: PriceBand,
    limit: int = 10,
) -> tuple[Restaurant, ...]:
    """Return the top-N restaurants that satisfy the filters.

    Ordering matches hotel search: shortest detour first, then cheapest.
    """
    kept = [r for r in restaurants if r.detour_minutes <= max_detour_minutes]
    if price_band is not PriceBand.ANY:
        kept = [r for r in kept if r.price_band is price_band]
    kept.sort(key=lambda r: (r.detour_minutes, r.price_eur_per_meal))
    return tuple(kept[:limit])

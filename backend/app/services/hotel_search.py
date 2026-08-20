"""Filter and rank hotels for a given trip planning request."""

from __future__ import annotations

from app.domain import Hotel, PriceBand


def filter_hotels(
    hotels: tuple[Hotel, ...],
    *,
    max_detour_minutes: float,
    price_band: PriceBand,
    limit: int = 10,
) -> tuple[Hotel, ...]:
    """Return the top-N hotels that satisfy the filters.

    Ordering: shortest detour first, then cheapest. That matches how a
    driver picks: minimise time off the route, then price.
    """
    kept = [h for h in hotels if h.detour_minutes <= max_detour_minutes]
    if price_band is not PriceBand.ANY:
        kept = [h for h in kept if h.price_band is price_band]
    kept.sort(key=lambda h: (h.detour_minutes, h.price_eur_per_night))
    return tuple(kept[:limit])

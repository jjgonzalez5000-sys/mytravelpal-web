"""Filter and rank restaurants for a given trip planning request."""

from __future__ import annotations

from app.domain import MealSlot, PriceBand, Restaurant, TripProfile


def filter_restaurants(
    restaurants: tuple[Restaurant, ...],
    *,
    max_detour_minutes: float,
    price_band: PriceBand,
    profile: TripProfile | None = None,
    slot: MealSlot | None = None,
    limit: int = 10,
) -> tuple[Restaurant, ...]:
    """Return the top-N restaurants after applying the filters.

    Ranking (lowest score wins): detour first, then price. Demotes (not
    excludes) restaurants that don't advertise a profile-required trait
    or that don't open at the desired meal slot.
    """
    kept = [r for r in restaurants if r.detour_minutes <= max_detour_minutes]
    if price_band is not PriceBand.ANY:
        kept = [r for r in kept if r.price_band is price_band]

    def _key(r: Restaurant) -> tuple:
        penalty = 0.0
        if profile is not None:
            if profile.has_kids and not r.kid_friendly:
                penalty += 20.0
            if profile.has_pets and not r.pet_friendly:
                penalty += 20.0
        if slot is not None and r.open_meal_slots and slot not in r.open_meal_slots:
            penalty += 15.0
        return (penalty + r.detour_minutes, r.price_eur_per_meal)

    kept.sort(key=_key)
    return tuple(kept[:limit])

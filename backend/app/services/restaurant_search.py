"""Filter and rank restaurants for a given trip planning request."""

from __future__ import annotations

from app.domain import Coordinate, MealSlot, PriceBand, Restaurant, TripProfile


def _price_bands_normalized(
    bands: tuple[PriceBand, ...] | list[PriceBand] | None,
) -> tuple[PriceBand, ...] | None:
    """Reduce the multi-band filter to a canonical form.

    Returns `None` when no filtering should happen (empty, missing,
    or `ANY` in the list). Otherwise a tuple of the specific bands.
    """
    if not bands:
        return None
    normalized = tuple(b for b in bands if b is not PriceBand.ANY)
    if not normalized:
        return None
    # A driver who selected every specific band is asking for "any".
    all_specific = {PriceBand.BUDGET, PriceBand.MID, PriceBand.LUX}
    if all_specific.issubset(set(normalized)):
        return None
    return normalized


def _cuisine_matches(
    restaurant: Restaurant, cuisines: tuple[str, ...] | None,
) -> bool:
    """Whether the restaurant's OSM `cuisine` tag overlaps the wanted
    list. Split by ';' because OSM lets a single restaurant declare
    multiple cuisines that way (e.g. 'italian;pizza').
    """
    if not cuisines:
        return True
    raw = dict(restaurant.attributes).get("cuisine", "")
    if not raw:
        # Unknown cuisine — don't hide the restaurant just because
        # the mapper didn't tag it. Better to keep and let ranking
        # push it down than filter out entire regions.
        return True
    parts = {p.strip().lower() for p in raw.split(";") if p.strip()}
    return any(c.lower() in parts for c in cuisines)


def _is_fast_food_like(restaurant: Restaurant) -> bool:
    """Detect fast-food / quick-service places we don't want to
    surface to families paying for a proper mid/lux meal.

    OSM tags: `amenity=fast_food` isn't preserved on our `Restaurant`
    object but the price band + brand often are. Combine three signals:
    - Explicit `fast_food` in attributes (rare but present on some).
    - Big fast-food brand names.
    - Budget price band with a `takeaway` or `delivery` yes.
    """
    attrs = dict(restaurant.attributes)
    if attrs.get("amenity") == "fast_food":
        return True
    name_l = restaurant.name.lower()
    brand_l = (attrs.get("brand") or "").lower()
    fast_food_brands = {
        "mcdonald", "burger king", "kfc", "subway", "domino",
        "pizza hut", "starbucks", "telepizza", "goiko", "five guys",
        "taco bell", "wendys", "popeyes", "quick",
    }
    if any(b in name_l or b in brand_l for b in fast_food_brands):
        return True
    return False


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km as f
    return f(a, b)


def filter_restaurants(
    restaurants: tuple[Restaurant, ...],
    *,
    max_detour_minutes: float,
    price_band: PriceBand = PriceBand.ANY,
    price_bands: tuple[PriceBand, ...] | list[PriceBand] | None = None,
    cuisines: tuple[str, ...] | list[str] | None = None,
    origin: Coordinate | None = None,
    exclude_origin_radius_km: float = 0.0,
    profile: TripProfile | None = None,
    slot: MealSlot | None = None,
    limit: int = 15,
) -> tuple[Restaurant, ...]:
    """Return the top-N restaurants after applying the filters.

    Filter chain (hard, in order):
    1. Detour cap.
    2. Origin buffer: drop places within `exclude_origin_radius_km` km
       of the origin — dining next door to the departure point is
       useless for a road-trip planner.
    3. Price bands: multi-band via `price_bands`, falling back to the
       legacy single `price_band` if `price_bands` is None. `ANY` in
       the list or all three specific bands means "no filter".
    4. Cuisines: only keep restaurants whose OSM `cuisine` tag matches
       one of the wanted values (untagged places are kept — no data ≠
       wrong cuisine).
    5. Fast-food guard: when kids are along AND the driver isn't
       looking for budget explicitly, drop fast-food places. Families
       who paid extra to sit down don't want the McDonald's option
       ranked next to the proper restaurant.

    Then a soft ranking (`_key`) sorts by profile-match penalty +
    detour, capped at `limit`.
    """
    kept = list(restaurants)

    # 1. Detour cap.
    kept = [r for r in kept if r.detour_minutes <= max_detour_minutes]

    # 2. Origin buffer.
    if origin is not None and exclude_origin_radius_km > 0:
        kept = [
            r for r in kept
            if _haversine_km(origin, r.coordinate) > exclude_origin_radius_km
        ]

    # 3. Price bands.
    bands = _price_bands_normalized(price_bands)
    if bands is None and price_band is not PriceBand.ANY:
        bands = (price_band,)
    if bands is not None:
        kept = [r for r in kept if r.price_band in bands]

    # 4. Cuisines.
    cuisine_tuple = tuple(cuisines) if cuisines else None
    if cuisine_tuple:
        kept = [r for r in kept if _cuisine_matches(r, cuisine_tuple)]

    # 5. Fast-food guard for kids-with-a-budget-above-budget.
    if (
        profile is not None
        and profile.has_kids
        and bands is not None
        and PriceBand.BUDGET not in bands
    ):
        kept = [r for r in kept if not _is_fast_food_like(r)]

    def _key(r: Restaurant) -> tuple[float, float]:
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

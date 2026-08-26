"""Filter and rank hotels for a given trip planning request."""

from __future__ import annotations

from app.domain import Hotel, PriceBand, TripProfile


def _normalize_bands(
    bands: tuple[PriceBand, ...] | list[PriceBand] | None,
) -> tuple[PriceBand, ...] | None:
    if not bands:
        return None
    specific = tuple(b for b in bands if b is not PriceBand.ANY)
    if not specific:
        return None
    if {PriceBand.BUDGET, PriceBand.MID, PriceBand.LUX}.issubset(set(specific)):
        return None
    return specific


def _stars(hotel: Hotel) -> int | None:
    """Read the OSM `stars` self-declared classification. Missing on
    the majority of hotels — the caller decides whether to treat
    missing as "keep" or "drop" via the `strict` flag on the
    filter.
    """
    raw = dict(hotel.attributes).get("stars")
    if raw in (None, ""):
        return None
    try:
        return int(str(raw).strip().split()[0])
    except (TypeError, ValueError):
        return None


def filter_hotels(
    hotels: tuple[Hotel, ...],
    *,
    max_detour_minutes: float,
    price_band: PriceBand = PriceBand.ANY,
    price_bands: tuple[PriceBand, ...] | list[PriceBand] | None = None,
    profile: TripProfile | None = None,
    min_stars: int | None = None,
    limit: int = 10,
) -> tuple[Hotel, ...]:
    """Return the top-N hotels that satisfy the filters, ranked by fit.

    Ranking (lowest score wins):
      1. detour minutes (primary — driver mostly cares about time off route)
      2. price
    We *demote* rather than exclude when a profile flag (has_kids / has_pets)
    isn't matched: the driver still sees the hotel, but at the bottom of the
    list. Prevents the filter from ever returning nothing when the mock
    catalogue is small.
    """
    kept = [h for h in hotels if h.detour_minutes <= max_detour_minutes]
    # Multi-band wins over the legacy single-band parameter.
    bands = _normalize_bands(price_bands)
    if bands is None and price_band is not PriceBand.ANY:
        bands = (price_band,)
    if bands is not None:
        kept = [h for h in kept if h.price_band in bands]

    # Star rating (OSM `stars` self-declared tag). Only enforced
    # when the caller asks; missing stars are DROPPED under a
    # strict filter — a driver who selected "4+ stars only" would
    # be misled by a hotel that just didn't fill the tag. Trade-
    # off: pool shrinks a lot in regions where mappers omit the
    # tag. Acceptable for MVP; upgrade path is Google Places.
    if min_stars is not None and min_stars > 0:
        kept = [
            h for h in kept
            if (s := _stars(h)) is not None and s >= min_stars
        ]

    def _key(h: Hotel) -> tuple:
        # Penalty applied when the profile asks for something the hotel
        # doesn't advertise. Bigger penalty = ranked lower.
        penalty = 0.0
        if profile is not None:
            if profile.has_kids and not h.kid_friendly:
                penalty += 30.0
            if profile.has_pets and not h.pet_friendly:
                penalty += 30.0
            if not h.has_parking:
                penalty += 10.0
        return (penalty + h.detour_minutes, h.price_eur_per_night)

    kept.sort(key=_key)
    return tuple(kept[:limit])

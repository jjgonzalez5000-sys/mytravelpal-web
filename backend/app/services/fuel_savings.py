"""Cross-station and cross-country fuel savings analysis.

Two derived signals we surface on top of raw fuel prices:

1. **Per-station savings vs country median.** For each station we know
   the country. Median the country's diesel price and expose
   `savings_vs_country_median_eur_per_l`; positive → cheaper, negative
   → pricier. Multiplied by the vehicle's tank capacity, that's the
   Euros a driver saves by picking THIS station over an average one.

2. **Cross-country arbitrage.** For multi-country trips (Spain→France,
   Portugal→Spain, Italy→Austria…), if one country's median is
   materially cheaper than another's the driver can save real money by
   refuelling **before** crossing. We emit an advisory `FuelArbitrage`
   only when the delta exceeds a threshold (else it's noise).
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from statistics import median

from app.domain import Country, Vehicle
from app.providers.fuel import FuelPrice


# Threshold below which a per-litre gap is noise — border stations
# already compete within ~2 cents, we only surface a hint when it's a
# real cross-country structural gap.
_MIN_ARBITRAGE_DELTA_EUR_PER_L = 0.05

# Curated results per country. A driver doesn't need 30 pumps of the
# same brand in the same town — 8-12 signal-heavy picks per country
# is plenty. Total cap of `_TOTAL_CAP` prevents flooding for
# multi-country trips (ES+FR+IT could otherwise yield 30+ each).
_PER_COUNTRY_CAP = 10
_TOTAL_CAP = 30

# "Premium" brands the app guarantees at least a handful of every
# request so drivers who prefer a trusted brand to squeeze the last
# cent aren't dropped in favour of a wall of low-cost independents
# (Ballenoil, Petroprix, Plenoil …). Kept as a lowercase brand-key
# set so `_brand_key` matches directly. Add majors here as we notice
# them missing. Deliberately generous — better to over-include than
# to filter out a station a driver would actually recognise.
_PREMIUM_BRANDS: frozenset[str] = frozenset({
    # Iberia
    "repsol", "cepsa", "moeve", "galp", "bp", "shell",
    # France + Benelux
    "totalenergies", "total", "esso", "eni", "avia",
    # Italy
    "agip", "ip", "tamoil", "q8", "kuwait",
    # DACH + wider Europe (future)
    "aral", "jet", "omv", "gulf",
})

# Fraction of each country's cap reserved for premium brands, applied
# on top of the pure "cheapest first" sort. On a 10-slot cap this
# guarantees 3 premium picks even when independents dominate the low
# end of the corridor.
_PREMIUM_SLOT_FRACTION = 0.3
# Cluster stations within this many degrees of each other under the
# same brand — a Repsol AND another Repsol 200 m away is usually the
# same commercial site with two access lanes; keep the cheaper one.
_CLUSTER_GRID_DEG = 0.005  # ~500 m at European latitudes


@dataclass(frozen=True, slots=True)
class FuelArbitrage:
    cheaper_country: Country
    cheaper_median_eur_per_l: float
    pricier_country: Country
    pricier_median_eur_per_l: float
    delta_eur_per_l: float
    estimated_tank_saving_eur: float


def _primary_fuel_key(p: FuelPrice) -> str:
    """Extract the primary fuel type from `attributes` (set by
    `_pick_primary_price`). Falls back to `"unknown"` so mock rows
    don't crash the grouping.
    """
    return dict(p.attributes).get("primary_fuel", "unknown")


def _country_fuel_medians(
    prices: tuple[FuelPrice, ...],
) -> dict[tuple[Country, str], float]:
    """Median price per (country, fuel type). Mixing diesel (~1.9€/L)
    with LPG (~0.8€/L) into a single median made every LPG station
    look like a huge savings vs "average", which is wrong — LPG cars
    aren't a majority and LPG isn't a substitute for diesel. Comparing
    within the same fuel type keeps the deal signal honest.
    """
    by_group: dict[tuple[Country, str], list[float]] = {}
    for p in prices:
        if not p.price_available or p.price_eur_per_l <= 0:
            continue
        key = (p.country, _primary_fuel_key(p))
        by_group.setdefault(key, []).append(p.price_eur_per_l)
    return {k: round(median(vs), 3) for k, vs in by_group.items() if vs}


def _country_medians(
    prices: tuple[FuelPrice, ...],
) -> dict[Country, float]:
    """Legacy per-country median (mixes fuel types). Kept because the
    `cross_country_arbitrage()` public API uses country-level deltas,
    where a rough aggregate is what we want (drivers care about
    "France in general is pricier"). Per-fuel medians are used only
    for per-station savings.
    """
    by_country: dict[Country, list[float]] = {}
    for p in prices:
        if not p.price_available or p.price_eur_per_l <= 0:
            continue
        by_country.setdefault(p.country, []).append(p.price_eur_per_l)
    return {c: round(median(vs), 3) for c, vs in by_country.items() if vs}


def stamp_savings(
    prices: tuple[FuelPrice, ...],
    *,
    vehicle: Vehicle | None = None,
) -> tuple[FuelPrice, ...]:
    """Return a new tuple with each `FuelPrice` re-stamped with
    `savings_vs_country_median_eur_per_l`.

    Positive = cheaper than the country median (a good deal).
    Negative = above the median. Mock / Nominatim entries with no
    price stay untouched (savings = None).

    We stamp on the object rather than a side-dict so downstream
    curation and serialisation can just read `p.savings_...`.
    """
    del vehicle  # kept for future weighting; €/L is vehicle-agnostic
    medians = _country_fuel_medians(prices)
    out: list[FuelPrice] = []
    for p in prices:
        if not p.price_available or p.price_eur_per_l <= 0:
            out.append(p)
            continue
        key = (p.country, _primary_fuel_key(p))
        median_price = medians.get(key)
        if median_price is None:
            out.append(p)
            continue
        delta = round(median_price - p.price_eur_per_l, 3)
        out.append(replace(p, savings_vs_country_median_eur_per_l=delta))
    return tuple(out)


# Back-compat wrapper for callers that still want the dict.
def station_savings(
    prices: tuple[FuelPrice, ...],
    *,
    vehicle: Vehicle | None = None,
) -> dict[int, float]:
    del vehicle
    medians = _country_fuel_medians(prices)
    return {
        id(p): round(medians[(p.country, _primary_fuel_key(p))] - p.price_eur_per_l, 3)
        for p in prices
        if p.price_available
        and p.price_eur_per_l > 0
        and (p.country, _primary_fuel_key(p)) in medians
    }


def _brand_key(name: str) -> str:
    """Rough brand key for clustering. Everything before the first
    space, lowercased — 'Repsol Butano' → 'repsol', 'BP Fermin' → 'bp'.
    Good enough to collapse the multi-lane duplicates we see in
    Ministerio / Roulez-Éco feeds without needing a real brand list.
    """
    return (name or "").strip().lower().split()[0] if name else ""


def curate_stations(
    prices: tuple[FuelPrice, ...],
) -> tuple[FuelPrice, ...]:
    """Reduce a raw station list to the picks worth showing.

    Applied AFTER `station_savings()` has stamped each row's savings
    field. Three steps:

    1. Cluster near-duplicates (same brand within ~500 m) and keep
       the cheapest — Ministerio and Roulez-Éco both list every
       physical pump, which visually reads as spam.
    2. Keep only stations priced **at or below** their country's
       median. A driver optimises for savings; anything at or above
       median is noise for that use case.
    3. Per-country cap + overall cap, sorted by savings desc (best
       deals first). Guarantees every country the trip crosses is
       represented rather than being crowded out by a denser country.
    """
    if not prices:
        return prices

    # ---- Cluster near-duplicates by (brand, ~500 m grid) ----
    clustered: dict[tuple[str, int, int], FuelPrice] = {}
    for p in prices:
        if p.coordinate is None:
            # Without a coord we can't cluster; keep as-is under a
            # unique key.
            clustered[(p.station_name, id(p), 0)] = p
            continue
        key = (
            _brand_key(p.station_name),
            round(p.coordinate.lat / _CLUSTER_GRID_DEG),
            round(p.coordinate.lon / _CLUSTER_GRID_DEG),
        )
        existing = clustered.get(key)
        if existing is None or p.price_eur_per_l < existing.price_eur_per_l:
            clustered[key] = p

    deduped = list(clustered.values())

    # ---- Per-country cap sorted by savings desc ----
    # Order by savings (best deal first). We deliberately DO NOT drop
    # above-median stations: on Spain→Zurich the entire French leg
    # is on autoroute service areas which are always pricier than
    # the country median (city stations are cheaper), so a strict
    # below-median filter erased the whole French section. Sorting
    # by savings and per-country capping already surfaces the best
    # available deals country-by-country without hiding France
    # entirely.
    per_country: dict[str, list[FuelPrice]] = {}
    for p in deduped:
        per_country.setdefault(p.country.value, []).append(p)

    def _score(p: FuelPrice) -> tuple[float, float]:
        # `savings` may be None (mock / Nominatim / single-country
        # sample) — treat as neutral 0 so those don't dominate.
        savings = p.savings_vs_country_median_eur_per_l or 0.0
        return (-savings, p.distance_from_origin_km)

    for lst in per_country.values():
        lst.sort(key=_score)

    # Per-country picks: reserve part of the cap for premium brands
    # so a country dominated by low-cost independents (Iberia is full
    # of Ballenoil / Petroprix) still surfaces a Repsol, Cepsa or BP
    # among the cheapest — many drivers prefer a mid-price major to a
    # rock-bottom no-name. Guarantee is best-effort: if not enough
    # premium stations exist in the corridor, we don't pad with worse
    # deals just to hit the target.
    picks: list[FuelPrice] = []
    premium_target = max(1, round(_PER_COUNTRY_CAP * _PREMIUM_SLOT_FRACTION))
    for lst in per_country.values():
        cheapest = lst[:_PER_COUNTRY_CAP]
        already_ids = {id(p) for p in cheapest}
        premium_extras = [
            p for p in lst
            if _brand_key(p.station_name) in _PREMIUM_BRANDS
            and id(p) not in already_ids
        ][:premium_target]
        combined = list(cheapest) + premium_extras
        combined.sort(key=_score)
        picks.extend(combined[:_PER_COUNTRY_CAP])
    picks.sort(key=_score)
    return tuple(picks[:_TOTAL_CAP])


def cross_country_arbitrage(
    prices: tuple[FuelPrice, ...],
    *,
    vehicle: Vehicle | None,
) -> FuelArbitrage | None:
    """Return the biggest cross-country arbitrage in the corridor.

    - Needs prices from at least two countries with real numbers.
    - Delta must exceed `_MIN_ARBITRAGE_DELTA_EUR_PER_L`.
    - `estimated_tank_saving_eur` uses the vehicle's tank capacity when
      known, else falls back to a 50 L reference so the hint still
      shows a meaningful order of magnitude.
    """
    medians = _country_medians(prices)
    if len(medians) < 2:
        return None
    cheapest_country, cheapest_price = min(medians.items(), key=lambda x: x[1])
    priciest_country, priciest_price = max(medians.items(), key=lambda x: x[1])
    if cheapest_country == priciest_country:
        return None
    delta = round(priciest_price - cheapest_price, 3)
    if delta < _MIN_ARBITRAGE_DELTA_EUR_PER_L:
        return None
    tank_l = (
        vehicle.fuel_tank_l
        if vehicle is not None and vehicle.fuel_tank_l > 0
        else 50.0
    )
    return FuelArbitrage(
        cheaper_country=cheapest_country,
        cheaper_median_eur_per_l=cheapest_price,
        pricier_country=priciest_country,
        pricier_median_eur_per_l=priciest_price,
        delta_eur_per_l=delta,
        estimated_tank_saving_eur=round(delta * tank_l, 2),
    )

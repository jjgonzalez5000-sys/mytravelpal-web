"""Cross-country hotel-price arbitrage.

Mirror of `fuel_savings.cross_country_arbitrage` for the `Hotel` pool.
Surfaces the fact that a driver crossing (say) France → Switzerland
sleeps dramatically cheaper if the overnight is pushed one country
south. Same UX pattern as the fuel banner but rendered per-day
(inside the day card of every night that lands in the pricier country).

Rules:
- Needs hotels from at least two countries in the corridor.
- Delta must exceed `_MIN_DELTA_PERCENT` **relative** to the cheaper
  median (not an absolute €). A 20 % gap between Bulgaria (~€30/night)
  and Romania (~€45) is worth flagging even at a raw €15 delta; a
  €25 absolute gap between France and Switzerland at ~15 % isn't
  strong enough signal to interrupt the driver.
- Median (not mean) so a single 500 €/night boutique doesn't skew the
  country signal.
- Emits which day indices have a sleep in the pricier country + the
  estimated total saving = delta × affected nights, so the frontend
  shows "N noches en X → ahorras ≈ €Y" instead of a raw €/night.
"""

from __future__ import annotations

from dataclasses import dataclass
from statistics import median

from app.domain import Coordinate, Country, Hotel, Route
from app.services.trip_optimizations import SleepStop

# 20 % relative gap between the cheaper and pricier country medians.
# Below this the banner is noise — hotels vary by more than that
# within a single country (business hotel vs rural pension).
_MIN_DELTA_PERCENT = 20.0


@dataclass(frozen=True, slots=True)
class HotelArbitrage:
    cheaper_country: Country
    cheaper_median_eur_per_night: float
    pricier_country: Country
    pricier_median_eur_per_night: float
    delta_eur_per_night: float
    delta_percent: float
    affected_day_indices: tuple[int, ...]
    """1-based day indices where the sleep coord lands in the pricier
    country. Mobile renders the banner inside each of these day
    cards (not as a global banner above the plan)."""
    estimated_total_saving_eur: float
    """delta_eur_per_night × len(affected_day_indices). Rounded to 0
    decimals for a clean UI headline."""


def _country_medians(hotels: tuple[Hotel, ...]) -> dict[Country, float]:
    by_country: dict[Country, list[float]] = {}
    for h in hotels:
        if h.price_eur_per_night <= 0:
            continue
        by_country.setdefault(h.country, []).append(h.price_eur_per_night)
    return {k: round(median(vs), 2) for k, vs in by_country.items() if vs}


def _country_of_coord(
    coord: Coordinate, route: Route,
) -> Country | None:
    """Country lookup for a sleep coord.

    Reuses the same `detect_country` helper the POI providers do
    (real Shapely polygons, not bounding boxes) so a sleep near the
    Swiss border doesn't get mislabeled as French/German because the
    country bboxes overlap. Falls back to the first
    `countries_crossed` when detection returns None.
    """
    from app.services.country_detection import detect_country
    return detect_country(coord) or (
        route.countries_crossed[0]
        if route.countries_crossed
        else None
    )


def cross_country_hotel_arbitrage(
    hotels: tuple[Hotel, ...],
    *,
    all_sleeps: tuple[SleepStop, ...],
    route: Route,
) -> HotelArbitrage | None:
    """Return the biggest cross-country hotel arbitrage in the corridor.

    None when we can't find at least two countries with hotels, when
    the relative delta is below the 20 % threshold, or when no sleep
    stop lands in the pricier country (nothing to relocate).
    """
    medians = _country_medians(hotels)
    if len(medians) < 2:
        return None
    cheaper_country, cheaper_price = min(medians.items(), key=lambda x: x[1])
    pricier_country, pricier_price = max(medians.items(), key=lambda x: x[1])
    if cheaper_country == pricier_country or cheaper_price <= 0:
        return None
    delta = round(pricier_price - cheaper_price, 2)
    delta_pct = round(100.0 * delta / cheaper_price, 1)
    if delta_pct < _MIN_DELTA_PERCENT:
        return None
    # Which sleeps land in the pricier country? Those day cards get
    # the banner. `day_index` on SleepStop is 1-based per Optimizations.
    affected: list[int] = []
    for i, sleep in enumerate(all_sleeps):
        country = _country_of_coord(sleep.rest_stop.coordinate, route)
        if country == pricier_country:
            # Day index for the sleep is (i + 1) — sleeps[0] closes
            # day 1's driving, sleeps[1] closes day 2's, etc.
            affected.append(i + 1)
    if not affected:
        return None
    return HotelArbitrage(
        cheaper_country=cheaper_country,
        cheaper_median_eur_per_night=cheaper_price,
        pricier_country=pricier_country,
        pricier_median_eur_per_night=pricier_price,
        delta_eur_per_night=delta,
        delta_percent=delta_pct,
        affected_day_indices=tuple(affected),
        estimated_total_saving_eur=round(delta * len(affected)),
    )

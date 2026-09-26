"""Refuel-window computation for a planned trip.

Given the driver's tank size, real-world consumption and current tank
level, this returns two distance milestones along the route:

- `comfortable_by_km` — the point at which the tank drops to ~25 %.
  Rendered as a gentle suggestion ("refuel around here — cheapest
  station on the window is X").
- `must_by_km` — the point at which the tank hits the reserve line
  (10 % by default). Past this the fuel light is on and the driver
  has to stop or risk running dry.

Both figures are expressed as km-from-origin so the mobile client can
compare directly with a fuel station's `distance_from_origin_km`
and highlight the ones inside the window. When the current tank
already reaches the destination, both values are clamped to the route
distance and the client hides the chip entirely.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Iterable, Sequence

if TYPE_CHECKING:
    from app.providers.fuel import FuelPrice


@dataclass(frozen=True, slots=True)
class RefuelWindow:
    """Two distance milestones plus derived range figures.

    - `usable_range_km`: distance the driver can cover on the fuel
      they currently have, minus reserve.
    - `must_by_km`: origin-relative km at which the tank hits the
      reserve line (10 % by default). Never > route distance.
    - `comfortable_by_km`: origin-relative km at which the tank drops
      to ~25 %. Always ≤ `must_by_km`.
    - `reaches_destination`: True when the current fuel comfortably
      covers the whole route (chip should be hidden).
    """
    usable_range_km: float
    must_by_km: float
    comfortable_by_km: float
    reaches_destination: bool


def pick_cheapest_in_window(
    prices: "Iterable[FuelPrice]",
    from_km: float,
    to_km: float,
) -> "FuelPrice | None":
    """Return the single cheapest priced station whose
    ``distance_from_origin_km`` sits within ``(from_km, to_km]``.

    Stations without a live price feed (``price_available`` False) and
    EV charging stations are ignored — we can't compare them on
    €/L. Returns ``None`` when the window is empty. Behaves gracefully
    when ``from_km >= to_km`` (returns ``None``).
    """
    if to_km <= from_km:
        return None
    candidates = [
        p for p in prices
        if getattr(p, "price_available", True)
        and not getattr(p, "is_charging_station", False)
        and from_km < float(p.distance_from_origin_km) <= to_km
    ]
    if not candidates:
        return None
    return min(candidates, key=lambda p: p.price_eur_per_l)


def estimate_fuel_savings(
    picked_price: float,
    median_price: float,
    liters_needed: float,
) -> float:
    """Rough €-savings for topping up at ``picked_price`` vs the
    route's ``median_price``.

    Formula: ``(median - picked) * liters_needed``, clamped to
    ``max(0, …)`` — a station at or above the median contributes
    no savings signal (we don't shout "you saved -1.20 €" at
    the user, that's dishonest).
    """
    delta = float(median_price) - float(picked_price)
    liters = max(0.0, float(liters_needed))
    return max(0.0, delta * liters)


def route_median_price(prices: "Sequence[FuelPrice]") -> float | None:
    """Median €/L across the route's priced stations. Skips
    non-priced entries and EV chargers. ``None`` when no station has
    a live price to compare against.
    """
    values = sorted(
        float(p.price_eur_per_l)
        for p in prices
        if getattr(p, "price_available", True)
        and not getattr(p, "is_charging_station", False)
    )
    if not values:
        return None
    mid = len(values) // 2
    if len(values) % 2 == 1:
        return values[mid]
    return (values[mid - 1] + values[mid]) / 2.0


def liters_needed_for_refuel(
    tank_liters: float,
    current_tank_frac: float,
    reserve_frac: float = 0.10,
) -> float:
    """How many litres the driver actually needs to buy at the
    suggested station, expressed as
    ``min(tank - reserve, tank * (1 - current_tank_frac))``.

    - The first term is the biggest amount the tank can physically
      accept above the reserve line (useful when the driver arrives
      near-empty and refills to full).
    - The second term is what's actually missing to reach full from
      the current level (useful when the tank is still half-full and
      a topping-up doesn't need much).

    The ``min`` picks whichever situation constrains — you can't buy
    more than the tank can hold, and you don't buy more than what's
    missing.
    """
    tank = max(0.0, float(tank_liters))
    frac = max(0.0, min(1.0, float(current_tank_frac)))
    reserve = max(0.0, min(1.0, float(reserve_frac)))
    usable_capacity = tank * max(0.0, 1.0 - reserve)
    missing_to_full = tank * (1.0 - frac)
    return max(0.0, min(usable_capacity, missing_to_full))


def refuel_window(
    route_distance_km: float,
    tank_level_frac: float,
    tank_liters: float,
    consumption_l100km: float,
    reserve_frac: float = 0.10,
    comfortable_reserve_frac: float = 0.25,
) -> RefuelWindow:
    """Compute the two refuel milestones for the trip.

    `tank_level_frac` is 0.0–1.0 (e.g. 0.5 for half-tank). The client
    picker in v1 exposes the four common notches (0.25 / 0.5 /
    0.75 / 1.0) but the helper accepts any float in [0, 1].

    Any value ≤ 0 fuel-consumption is defended with a fallback — a
    profile with a broken consumption slider shouldn't crash the plan
    endpoint. Same for the tank size.

    All returned distances are clamped to `route_distance_km`; a
    driver whose tank comfortably outlasts the trip sees both
    milestones at the destination (mobile hides the chip when
    `reaches_destination`).
    """
    tank_liters = max(1.0, float(tank_liters))
    consumption_l100km = max(0.1, float(consumption_l100km))
    tank_level_frac = max(0.0, min(1.0, float(tank_level_frac)))
    reserve_frac = max(0.0, min(0.5, float(reserve_frac)))
    comfortable_reserve_frac = max(
        reserve_frac, min(0.9, float(comfortable_reserve_frac))
    )

    # Litres actually usable before hitting the reserve line.
    usable_liters = max(0.0, (tank_level_frac - reserve_frac)) * tank_liters
    comfortable_liters = max(
        0.0, (tank_level_frac - comfortable_reserve_frac)
    ) * tank_liters

    # Distance = (litres / consumption per 100 km) * 100.
    usable_range_km = (usable_liters / consumption_l100km) * 100.0
    comfortable_range_km = (comfortable_liters / consumption_l100km) * 100.0

    must = min(route_distance_km, usable_range_km)
    comfortable = min(route_distance_km, comfortable_range_km)
    reaches = usable_range_km >= route_distance_km

    return RefuelWindow(
        usable_range_km=round(usable_range_km, 1),
        must_by_km=round(must, 1),
        comfortable_by_km=round(comfortable, 1),
        reaches_destination=reaches,
    )

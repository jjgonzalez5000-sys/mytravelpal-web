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

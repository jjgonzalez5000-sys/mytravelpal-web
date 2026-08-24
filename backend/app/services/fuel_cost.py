"""Estimate the fuel (or electric) cost of a planned trip.

Simple model: distance × consumption × unit price. Uses the average of
per-country fuel prices returned by the fuel provider so users see a
single number instead of doing mental math on 8 rows of gas stations.

For electric vehicles, we default to a rough EU average kWh price
(€0.35 /kWh) because charging-price feeds are a whole separate
integration; a follow-up sprint can wire e.g. Chargefinder or IONITY
tariffs and swap this constant.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain import FuelType, Route, Vehicle
from app.providers.fuel import FuelPrice

_DEFAULT_EV_PRICE_EUR_PER_KWH = 0.35
# Very rough diesel/petrol/lpg conversion when the fuel provider only
# reports 'petrol' prices in the mock. Real fuel providers will report
# per-fuel-type prices and we can drop these.
_APPROX_MULTIPLIER_VS_PETROL: dict[FuelType, float] = {
    FuelType.PETROL: 1.00,
    FuelType.DIESEL: 0.94,
    FuelType.LPG: 0.62,
    FuelType.HYBRID: 0.75,
    FuelType.ELECTRIC: 0.0,  # handled separately
}


@dataclass(frozen=True, slots=True)
class FuelCostEstimate:
    total_cost_eur: float
    average_unit_price_eur: float
    fuel_type: FuelType
    fuel_units: float          # litres, or kWh for EV
    unit_label: str            # "L" or "kWh"
    range_ok: bool             # True unless an EV can't cover the route on one charge
    notes: tuple[str, ...] = ()


def _avg_price(prices: tuple[FuelPrice, ...]) -> float:
    if not prices:
        return 1.75  # fall-back EU average
    return sum(p.price_eur_per_l for p in prices) / len(prices)


def estimate(
    route: Route, vehicle: Vehicle, fuel_prices: tuple[FuelPrice, ...],
) -> FuelCostEstimate:
    distance_km = route.distance_km

    if vehicle.fuel_type is FuelType.ELECTRIC:
        kwh = distance_km * vehicle.consumption_kwh_per_100km / 100.0
        cost = kwh * _DEFAULT_EV_PRICE_EUR_PER_KWH
        range_ok = distance_km <= vehicle.ev_range_km
        notes: tuple[str, ...] = ()
        if not range_ok:
            required_stops = int(
                distance_km // max(vehicle.ev_range_km, 1e-9),
            )
            notes = (
                f"Beyond your single-charge range — plan {required_stops} "
                f"charging stop(s).",
            )
        return FuelCostEstimate(
            total_cost_eur=round(cost, 2),
            average_unit_price_eur=_DEFAULT_EV_PRICE_EUR_PER_KWH,
            fuel_type=vehicle.fuel_type,
            fuel_units=round(kwh, 1),
            unit_label="kWh",
            range_ok=range_ok,
            notes=notes,
        )

    litres = distance_km * vehicle.consumption_l_per_100km / 100.0
    base = _avg_price(fuel_prices)
    unit_price = base * _APPROX_MULTIPLIER_VS_PETROL.get(vehicle.fuel_type, 1.0)
    cost = litres * unit_price
    return FuelCostEstimate(
        total_cost_eur=round(cost, 2),
        average_unit_price_eur=round(unit_price, 3),
        fuel_type=vehicle.fuel_type,
        fuel_units=round(litres, 1),
        unit_label="L",
        range_ok=True,
    )

#!/usr/bin/env python3
"""Premium subscription revenue estimator for MyTravelPal.

Model:
    monthly_revenue = paying_users × ARPU_month × (1 - store_cut) × (1 - churn_impact)

Where `paying_users` = MAU × conversion_rate, and `ARPU_month` blends
monthly and annual price points weighted by the annual/monthly mix.

Numbers here are conservative defaults for a Travel/Nav freemium app in
CH/FR/IT/ES. Adjust with CLI flags or scenario presets. Output is a
range, not a forecast.

Usage:
    python tools/subscription_revenue_calculator.py --mau 20000
    python tools/subscription_revenue_calculator.py --scenario moderate --mau 100000
    python tools/subscription_revenue_calculator.py --mau 50000 \\
        --monthly-price 3.99 --annual-price 29.99 --annual-mix 0.55
    python tools/subscription_revenue_calculator.py --scenario aggressive --sweep-mau
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace


# -- Scenarios --------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class SubScenario:
    """Preset that overrides several parameters at once."""

    name: str
    conversion_rate: float          # fraction of MAU that pays
    monthly_price_eur: float
    annual_price_eur: float
    annual_mix: float               # fraction of paying users on annual plan
    monthly_churn: float            # monthly churn of paying users
    store_cut: float                # Apple/Google take. 0.30 first year, 0.15 after
    intro_discount: float           # % off first period (weighted into effective ARPU)


SCENARIOS: dict[str, SubScenario] = {
    "conservative": SubScenario(
        name="conservative",
        conversion_rate=0.008,      # 0.8 %
        monthly_price_eur=2.99,
        annual_price_eur=19.99,
        annual_mix=0.30,
        monthly_churn=0.10,         # 10 %/month
        store_cut=0.30,
        intro_discount=0.20,
    ),
    "moderate": SubScenario(
        name="moderate",
        conversion_rate=0.020,      # 2 %
        monthly_price_eur=3.99,
        annual_price_eur=29.99,
        annual_mix=0.50,
        monthly_churn=0.06,
        store_cut=0.20,             # some subs already > 1 year
        intro_discount=0.15,
    ),
    "aggressive": SubScenario(
        name="aggressive",
        conversion_rate=0.045,      # 4.5 %
        monthly_price_eur=4.99,
        annual_price_eur=39.99,
        annual_mix=0.65,            # long-term users love the annual
        monthly_churn=0.04,
        store_cut=0.15,             # majority > 1 year
        intro_discount=0.10,
    ),
}


# -- Core math --------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class SubEstimate:
    paying_users: float
    arpu_month_eur: float
    gross_monthly_revenue_eur: float
    net_monthly_revenue_eur: float
    net_annual_revenue_eur: float
    ltv_per_user_eur: float

    def print_report(self, mau: int) -> None:
        print(f"MAU:                     {mau:>12,}")
        print(f"Paying users:            {self.paying_users:>12,.0f}")
        print(f"Effective ARPU / month:  {self.arpu_month_eur:>12,.2f} €")
        print(f"Gross monthly revenue:   {self.gross_monthly_revenue_eur:>12,.2f} €")
        print(f"Net monthly (post-store): {self.net_monthly_revenue_eur:>11,.2f} €")
        print(f"Net annual (post-store): {self.net_annual_revenue_eur:>12,.2f} €")
        print(f"LTV per paying user:     {self.ltv_per_user_eur:>12,.2f} €")


def _blended_arpu_month(
    monthly_price: float,
    annual_price: float,
    annual_mix: float,
    intro_discount: float,
) -> float:
    """Weighted average of monthly and annual ARPU, both expressed per month.

    An annual plan at €N is €N/12 per month; the intro discount lowers the
    effective ARPU by the pro-rated fraction (rough model — assumes users
    stay through the discount period).
    """
    annual_per_month = annual_price / 12.0
    blended = monthly_price * (1 - annual_mix) + annual_per_month * annual_mix
    return blended * (1 - intro_discount)


def estimate_subs(
    *,
    mau: int,
    conversion_rate: float,
    monthly_price_eur: float,
    annual_price_eur: float,
    annual_mix: float,
    monthly_churn: float,
    store_cut: float,
    intro_discount: float,
) -> SubEstimate:
    """Compute the estimate. All inputs validated."""
    if mau < 0:
        raise ValueError("mau must be >= 0")
    for label, value in (
        ("conversion_rate", conversion_rate),
        ("annual_mix", annual_mix),
        ("store_cut", store_cut),
        ("intro_discount", intro_discount),
    ):
        if not 0.0 <= value <= 1.0:
            raise ValueError(f"{label} must be in [0, 1]")
    if not 0.0 < monthly_churn <= 1.0:
        raise ValueError("monthly_churn must be in (0, 1]")
    if monthly_price_eur < 0 or annual_price_eur < 0:
        raise ValueError("prices must be >= 0")

    paying = mau * conversion_rate
    arpu = _blended_arpu_month(
        monthly_price_eur, annual_price_eur, annual_mix, intro_discount,
    )
    gross = paying * arpu
    net = gross * (1 - store_cut)
    # LTV = ARPU / churn, minus store cut, minus intro discount already applied.
    ltv = arpu * (1 - store_cut) / monthly_churn

    return SubEstimate(
        paying_users=paying,
        arpu_month_eur=arpu,
        gross_monthly_revenue_eur=gross,
        net_monthly_revenue_eur=net,
        net_annual_revenue_eur=net * 12,
        ltv_per_user_eur=ltv,
    )


def estimate_from_scenario(
    scenario: SubScenario,
    *,
    mau: int,
    overrides: dict[str, object] | None = None,
) -> SubEstimate:
    kwargs: dict[str, object] = {
        "mau": mau,
        "conversion_rate": scenario.conversion_rate,
        "monthly_price_eur": scenario.monthly_price_eur,
        "annual_price_eur": scenario.annual_price_eur,
        "annual_mix": scenario.annual_mix,
        "monthly_churn": scenario.monthly_churn,
        "store_cut": scenario.store_cut,
        "intro_discount": scenario.intro_discount,
    }
    if overrides:
        kwargs.update(overrides)
    return estimate_subs(**kwargs)  # type: ignore[arg-type]


# -- CLI --------------------------------------------------------------------

_MAU_SWEEP = (1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000)


def _sensitivity_table(scenario: SubScenario) -> None:
    print(f"Sensitivity — scenario '{scenario.name}'")
    print(f"{'MAU':>10} {'Payers':>10} {'Net €/mo':>12} {'Net €/yr':>12}")
    print("-" * 48)
    for m in _MAU_SWEEP:
        est = estimate_from_scenario(scenario, mau=m)
        print(
            f"{m:>10,} {est.paying_users:>10,.0f} "
            f"{est.net_monthly_revenue_eur:>12,.0f} "
            f"{est.net_annual_revenue_eur:>12,.0f}",
        )


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Estimate premium subscription revenue for MyTravelPal.",
    )
    p.add_argument("--mau", type=int, default=20_000)
    p.add_argument("--scenario", choices=sorted(SCENARIOS))
    p.add_argument("--conversion", type=float,
                   help="Fraction of MAU that pays. Typical 0.005 – 0.05.")
    p.add_argument("--monthly-price", type=float, help="Monthly plan price (€).")
    p.add_argument("--annual-price", type=float, help="Annual plan price (€).")
    p.add_argument("--annual-mix", type=float,
                   help="Fraction of paying users on the annual plan. 0.3 – 0.7.")
    p.add_argument("--churn", type=float,
                   help="Monthly churn of paying users. Typical 0.03 – 0.10.")
    p.add_argument("--store-cut", type=float,
                   help="Apple/Google take. 0.30 first year, 0.15 after.")
    p.add_argument("--intro-discount", type=float,
                   help="Effective first-period discount fraction. 0 – 0.30.")
    p.add_argument("--sweep-mau", action="store_true",
                   help="Print a MAU sensitivity table.")
    return p


def _resolve(args: argparse.Namespace) -> SubScenario:
    scenario = SCENARIOS[args.scenario] if args.scenario else SCENARIOS["moderate"]
    return replace(
        scenario,
        conversion_rate=args.conversion if args.conversion is not None else scenario.conversion_rate,
        monthly_price_eur=args.monthly_price if args.monthly_price is not None else scenario.monthly_price_eur,
        annual_price_eur=args.annual_price if args.annual_price is not None else scenario.annual_price_eur,
        annual_mix=args.annual_mix if args.annual_mix is not None else scenario.annual_mix,
        monthly_churn=args.churn if args.churn is not None else scenario.monthly_churn,
        store_cut=args.store_cut if args.store_cut is not None else scenario.store_cut,
        intro_discount=args.intro_discount if args.intro_discount is not None else scenario.intro_discount,
    )


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    scenario = _resolve(args)

    if args.sweep_mau:
        _sensitivity_table(scenario)
        return 0

    est = estimate_from_scenario(scenario, mau=args.mau)
    print(f"Scenario: {scenario.name}")
    print(f"Pricing: {scenario.monthly_price_eur:.2f} €/mo · "
          f"{scenario.annual_price_eur:.2f} €/yr (annual mix {scenario.annual_mix:.0%})")
    print(f"Conversion: {scenario.conversion_rate:.2%}   "
          f"Churn: {scenario.monthly_churn:.1%}/mo   "
          f"Store cut: {scenario.store_cut:.0%}   "
          f"Intro discount: {scenario.intro_discount:.0%}")
    print()
    est.print_report(args.mau)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

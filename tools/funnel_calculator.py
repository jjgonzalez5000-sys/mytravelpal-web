#!/usr/bin/env python3
"""End-to-end funnel calculator: installs → MAU → ad + subscription revenue.

Composes the ad and subscription calculators to answer:
    "Given N monthly installs, what total monthly revenue can I expect?"

Assumes a steady-state month: installs are churning at the same rate as
new installs land, so MAU stabilises. This isn't a cohort model — for
that you'd wire a proper retention curve, out of scope for the MVP.

Usage:
    python tools/funnel_calculator.py --installs 50000 --scenario moderate
    python tools/funnel_calculator.py --installs 100000 \\
        --scenario aggressive --geo-multiplier 1.15
    python tools/funnel_calculator.py --scenario conservative --sweep-installs
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ad_revenue_calculator import (  # noqa: E402
    SCENARIOS as AD_SCENARIOS,
    estimate_from_scenario as estimate_ads,
)
from subscription_revenue_calculator import (  # noqa: E402
    SCENARIOS as SUB_SCENARIOS,
    estimate_from_scenario as estimate_subs_scenario,
)


# -- Funnel presets ---------------------------------------------------------

@dataclass(frozen=True, slots=True)
class FunnelScenario:
    """Retention profile that turns monthly installs into MAU."""

    name: str
    activation_rate: float          # % of installs that open the app once
    month_1_retention: float        # % of activated who come back 30 days later
    steady_state_mau_ratio: float   # steady-state MAU / cumulative installs


FUNNEL_SCENARIOS: dict[str, FunnelScenario] = {
    "conservative": FunnelScenario(
        name="conservative",
        activation_rate=0.55,       # weak onboarding
        month_1_retention=0.10,
        steady_state_mau_ratio=0.04,
    ),
    "moderate": FunnelScenario(
        name="moderate",
        activation_rate=0.75,
        month_1_retention=0.20,
        steady_state_mau_ratio=0.10,
    ),
    "aggressive": FunnelScenario(
        name="aggressive",
        activation_rate=0.85,       # polished onboarding, notifications
        month_1_retention=0.35,
        steady_state_mau_ratio=0.18,
    ),
}


# -- Composition ------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class FunnelEstimate:
    installs: int
    activated: float
    mau: float
    ad_monthly_eur: float
    sub_monthly_eur: float
    total_monthly_eur: float
    total_annual_eur: float

    def print_report(self) -> None:
        print(f"Monthly installs:        {self.installs:>12,}")
        print(f"Activated (opened once): {self.activated:>12,.0f}")
        print(f"Steady-state MAU:        {self.mau:>12,.0f}")
        print()
        print(f"Ad revenue / month:      {self.ad_monthly_eur:>12,.0f} €")
        print(f"Sub revenue / month:     {self.sub_monthly_eur:>12,.0f} €")
        print("-" * 42)
        print(f"TOTAL / month:           {self.total_monthly_eur:>12,.0f} €")
        print(f"TOTAL / year:            {self.total_annual_eur:>12,.0f} €")


def estimate_funnel(
    *,
    installs: int,
    funnel_scenario: FunnelScenario,
    ad_scenario_key: str = "moderate",
    sub_scenario_key: str = "moderate",
    geo_multiplier: float = 1.0,
) -> FunnelEstimate:
    if installs < 0:
        raise ValueError("installs must be >= 0")

    # Interpretation: for a steady-state month, the pool of active users is
    # steady_state_mau_ratio × cumulative_installs. For a fresh app,
    # cumulative_installs is the sum of new installs over the retention
    # window — we approximate as installs / month_1_retention (the average
    # user contributes ~1/retention months of MAU life).
    activated = installs * funnel_scenario.activation_rate
    denom = max(funnel_scenario.month_1_retention, 1e-9)
    approx_cumulative = installs / denom
    mau = approx_cumulative * funnel_scenario.steady_state_mau_ratio

    ad_est = estimate_ads(
        AD_SCENARIOS[ad_scenario_key],
        mau=int(round(mau)),
        geo_multiplier=geo_multiplier,
    )
    sub_est = estimate_subs_scenario(
        SUB_SCENARIOS[sub_scenario_key],
        mau=int(round(mau)),
    )

    total_month = ad_est.monthly_revenue_eur + sub_est.net_monthly_revenue_eur
    return FunnelEstimate(
        installs=installs,
        activated=activated,
        mau=mau,
        ad_monthly_eur=ad_est.monthly_revenue_eur,
        sub_monthly_eur=sub_est.net_monthly_revenue_eur,
        total_monthly_eur=total_month,
        total_annual_eur=total_month * 12,
    )


# -- CLI --------------------------------------------------------------------

_INSTALL_SWEEP = (5_000, 25_000, 50_000, 100_000, 250_000, 500_000, 1_000_000)


def _sensitivity_table(fs: FunnelScenario, ad_key: str, sub_key: str, geo: float) -> None:
    print(f"Sensitivity — funnel '{fs.name}', ads '{ad_key}', subs '{sub_key}', geo ×{geo:.2f}")
    print(f"{'Installs/mo':>12} {'MAU':>10} {'Ads €/mo':>10} {'Subs €/mo':>11} {'Total €/mo':>12}")
    print("-" * 60)
    for inst in _INSTALL_SWEEP:
        est = estimate_funnel(
            installs=inst,
            funnel_scenario=fs,
            ad_scenario_key=ad_key,
            sub_scenario_key=sub_key,
            geo_multiplier=geo,
        )
        print(
            f"{inst:>12,} {est.mau:>10,.0f} "
            f"{est.ad_monthly_eur:>10,.0f} "
            f"{est.sub_monthly_eur:>11,.0f} "
            f"{est.total_monthly_eur:>12,.0f}",
        )


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="End-to-end funnel: installs → MAU → ads + subs revenue.",
    )
    p.add_argument("--installs", type=int, default=50_000,
                   help="Monthly installs.")
    p.add_argument("--scenario", choices=sorted(FUNNEL_SCENARIOS),
                   default="moderate",
                   help=("Preset that fixes funnel + ads + subs scenarios "
                         "to the same tier."))
    p.add_argument("--funnel", choices=sorted(FUNNEL_SCENARIOS),
                   help="Override funnel scenario.")
    p.add_argument("--ads", choices=sorted(AD_SCENARIOS),
                   help="Override ads scenario.")
    p.add_argument("--subs", choices=sorted(SUB_SCENARIOS),
                   help="Override subs scenario.")
    p.add_argument("--geo-multiplier", type=float, default=1.0)
    p.add_argument("--sweep-installs", action="store_true")
    return p


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    fs = FUNNEL_SCENARIOS[args.funnel or args.scenario]
    ad_key = args.ads or args.scenario
    sub_key = args.subs or args.scenario

    if args.sweep_installs:
        _sensitivity_table(fs, ad_key, sub_key, args.geo_multiplier)
        return 0

    est = estimate_funnel(
        installs=args.installs,
        funnel_scenario=fs,
        ad_scenario_key=ad_key,
        sub_scenario_key=sub_key,
        geo_multiplier=args.geo_multiplier,
    )
    print(f"Funnel: {fs.name}  ·  Ads: {ad_key}  ·  Subs: {sub_key}  ·  Geo ×{args.geo_multiplier:.2f}")
    print(f"Activation {fs.activation_rate:.0%}  ·  "
          f"M1 retention {fs.month_1_retention:.0%}  ·  "
          f"Steady MAU ratio {fs.steady_state_mau_ratio:.0%}")
    print()
    est.print_report()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

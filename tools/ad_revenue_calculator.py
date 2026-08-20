#!/usr/bin/env python3
"""Ad-revenue estimator for MyTravelPal.

Model:
    revenue = MAU × sessions × impressions_per_session × (eCPM / 1000) × fill_rate

Applied per ad format and summed. Multipliers apply on top of the raw
formula to account for geo, GDPR consent, and premium conversion.

Numbers here are calibrated for a Travel/Navigation app targeting
CH/FR/IT/ES (Tier-1 EU) in 2025. eCPM ranges come from published
benchmarks (AdMob, AppLovin, StatShot) and vary widely by season, geo
mix, mediation setup, and creative — always treat outputs as a range,
not a forecast.

Usage:

    # Quick preset scenarios
    python tools/ad_revenue_calculator.py --scenario conservative --mau 20000
    python tools/ad_revenue_calculator.py --scenario aggressive --mau 100000

    # Custom mix
    python tools/ad_revenue_calculator.py --mau 50000 --sessions 5 \\
        --formats banner,native,interstitial --premium-conversion 0.03

    # Sensitivity table across MAU
    python tools/ad_revenue_calculator.py --scenario moderate --sweep-mau

Run --help for the full option list.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
from typing import Iterable


# -- Format catalogue -------------------------------------------------------

@dataclass(frozen=True, slots=True)
class AdFormat:
    """A single ad unit and its economics for a Travel/Nav EU-4 app."""

    key: str
    display_name: str
    ecpm_eur_low: float
    ecpm_eur_high: float
    impressions_per_session: float
    ux_note: str

    @property
    def ecpm_mid(self) -> float:
        return (self.ecpm_eur_low + self.ecpm_eur_high) / 2


FORMATS: dict[str, AdFormat] = {
    "banner": AdFormat(
        key="banner",
        display_name="Banner",
        ecpm_eur_low=0.5,
        ecpm_eur_high=2.0,
        impressions_per_session=2.0,
        ux_note="Bottom-of-screen during planning. Never during navigation.",
    ),
    "native": AdFormat(
        key="native",
        display_name="Native (list)",
        ecpm_eur_low=2.0,
        ecpm_eur_high=8.0,
        impressions_per_session=1.5,
        ux_note="Slot inside hotel/restaurant/fuel lists. Contextual match, low friction.",
    ),
    "interstitial": AdFormat(
        key="interstitial",
        display_name="Interstitial",
        ecpm_eur_low=5.0,
        ecpm_eur_high=15.0,
        impressions_per_session=0.7,
        ux_note="Fullscreen after 'Plan trip'. Never mid-navigation.",
    ),
    "rewarded": AdFormat(
        key="rewarded",
        display_name="Rewarded video",
        ecpm_eur_low=10.0,
        ecpm_eur_high=25.0,
        impressions_per_session=0.3,
        ux_note="Opt-in: 15s for extra premium features today.",
    ),
    "app_open": AdFormat(
        key="app_open",
        display_name="App-open",
        ecpm_eur_low=4.0,
        ecpm_eur_high=10.0,
        impressions_per_session=1.0,
        ux_note="Shown on cold start. High revenue but users often hate it.",
    ),
}


# -- Scenarios --------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class Scenario:
    """A named preset that overrides several parameters at once."""

    name: str
    formats: tuple[str, ...]
    sessions_per_mau: float
    ecpm_position: float          # 0.0 = low, 0.5 = mid, 1.0 = high
    fill_rate: float
    consent_penalty: float        # multiplier: 1.0 = perfect consent, 0.5 = half revenue lost
    premium_conversion: float     # fraction of MAU that pays and sees no ads


SCENARIOS: dict[str, Scenario] = {
    "conservative": Scenario(
        name="conservative",
        formats=("banner",),
        sessions_per_mau=3.0,
        ecpm_position=0.25,
        fill_rate=0.88,
        consent_penalty=0.60,       # weak CMP + strict EU users
        premium_conversion=0.005,   # <1% pay
    ),
    "moderate": Scenario(
        name="moderate",
        formats=("banner", "native", "interstitial"),
        sessions_per_mau=5.0,
        ecpm_position=0.50,
        fill_rate=0.92,
        consent_penalty=0.75,
        premium_conversion=0.02,
    ),
    "aggressive": Scenario(
        name="aggressive",
        formats=("banner", "native", "interstitial", "rewarded", "app_open"),
        sessions_per_mau=8.0,
        ecpm_position=0.75,
        fill_rate=0.95,
        consent_penalty=0.85,       # invested in CMP + prompts
        premium_conversion=0.04,
    ),
}


# -- Core math --------------------------------------------------------------

@dataclass(frozen=True, slots=True)
class FormatBreakdown:
    format_key: str
    display_name: str
    effective_ecpm: float
    impressions: float
    revenue_eur: float


@dataclass(frozen=True, slots=True)
class Estimate:
    monthly_revenue_eur: float
    annual_revenue_eur: float
    ad_eligible_mau: float
    breakdown: tuple[FormatBreakdown, ...]

    def print_report(self, mau: int) -> None:
        print(f"MAU:                       {mau:>12,}")
        print(f"Ad-eligible MAU (post-premium): {self.ad_eligible_mau:>7,.0f}")
        print()
        print(f"{'Format':<18} {'eCPM (€)':>10} {'Impressions':>14} {'Revenue (€)':>14}")
        print("-" * 60)
        for b in self.breakdown:
            print(
                f"{b.display_name:<18} {b.effective_ecpm:>10.2f} "
                f"{b.impressions:>14,.0f} {b.revenue_eur:>14,.2f}",
            )
        print("-" * 60)
        print(
            f"{'TOTAL / month':<18} {'':>10} {'':>14} "
            f"{self.monthly_revenue_eur:>14,.2f}",
        )
        print(f"{'TOTAL / year':<18} {'':>10} {'':>14} "
              f"{self.annual_revenue_eur:>14,.2f}")


def _interpolate_ecpm(fmt: AdFormat, position: float) -> float:
    """Blend the format's low/high eCPM by `position` (0..1)."""
    position = max(0.0, min(1.0, position))
    return fmt.ecpm_eur_low + (fmt.ecpm_eur_high - fmt.ecpm_eur_low) * position


def estimate(
    *,
    mau: int,
    sessions_per_mau: float,
    formats: Iterable[str],
    ecpm_position: float = 0.5,
    fill_rate: float = 0.92,
    consent_penalty: float = 0.75,
    premium_conversion: float = 0.02,
    geo_multiplier: float = 1.0,
) -> Estimate:
    """Compute the estimate. All inputs are validated; nothing exotic."""
    if mau < 0:
        raise ValueError("mau must be >= 0")
    if sessions_per_mau < 0:
        raise ValueError("sessions_per_mau must be >= 0")
    if not 0.0 <= fill_rate <= 1.0:
        raise ValueError("fill_rate must be in [0, 1]")
    if not 0.0 <= consent_penalty <= 1.0:
        raise ValueError("consent_penalty must be in [0, 1]")
    if not 0.0 <= premium_conversion <= 1.0:
        raise ValueError("premium_conversion must be in [0, 1]")
    if geo_multiplier <= 0:
        raise ValueError("geo_multiplier must be > 0")

    format_keys = list(dict.fromkeys(formats))
    unknown = [k for k in format_keys if k not in FORMATS]
    if unknown:
        raise ValueError(f"Unknown ad formats: {unknown}. Known: {list(FORMATS)}")

    ad_eligible_mau = mau * (1.0 - premium_conversion)
    total_sessions = ad_eligible_mau * sessions_per_mau

    breakdown: list[FormatBreakdown] = []
    total = 0.0
    for key in format_keys:
        fmt = FORMATS[key]
        base_ecpm = _interpolate_ecpm(fmt, ecpm_position)
        effective_ecpm = base_ecpm * geo_multiplier * consent_penalty
        impressions = total_sessions * fmt.impressions_per_session * fill_rate
        revenue = impressions * effective_ecpm / 1000.0
        breakdown.append(
            FormatBreakdown(
                format_key=key,
                display_name=fmt.display_name,
                effective_ecpm=effective_ecpm,
                impressions=impressions,
                revenue_eur=revenue,
            )
        )
        total += revenue

    return Estimate(
        monthly_revenue_eur=total,
        annual_revenue_eur=total * 12,
        ad_eligible_mau=ad_eligible_mau,
        breakdown=tuple(breakdown),
    )


def estimate_from_scenario(
    scenario: Scenario,
    *,
    mau: int,
    geo_multiplier: float = 1.0,
    overrides: dict[str, object] | None = None,
) -> Estimate:
    """Run an estimate from a preset scenario, applying any per-call overrides."""
    kwargs: dict[str, object] = {
        "mau": mau,
        "sessions_per_mau": scenario.sessions_per_mau,
        "formats": scenario.formats,
        "ecpm_position": scenario.ecpm_position,
        "fill_rate": scenario.fill_rate,
        "consent_penalty": scenario.consent_penalty,
        "premium_conversion": scenario.premium_conversion,
        "geo_multiplier": geo_multiplier,
    }
    if overrides:
        kwargs.update(overrides)
    return estimate(**kwargs)  # type: ignore[arg-type]


# -- CLI --------------------------------------------------------------------

_MAU_SWEEP = (1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000)


def _sensitivity_table(scenario: Scenario, geo: float) -> None:
    print(f"Sensitivity — scenario '{scenario.name}', geo × {geo:.2f}")
    print(f"{'MAU':>10} {'Monthly (€)':>14} {'Annual (€)':>14}")
    print("-" * 42)
    for m in _MAU_SWEEP:
        est = estimate_from_scenario(scenario, mau=m, geo_multiplier=geo)
        print(f"{m:>10,} {est.monthly_revenue_eur:>14,.0f} {est.annual_revenue_eur:>14,.0f}")


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Estimate ad revenue for MyTravelPal under different assumptions.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python tools/ad_revenue_calculator.py --scenario moderate --mau 20000\n"
            "  python tools/ad_revenue_calculator.py --mau 50000 --sessions 4 \\\n"
            "      --formats banner,native --premium-conversion 0.03\n"
            "  python tools/ad_revenue_calculator.py --scenario aggressive --sweep-mau\n"
        ),
    )
    p.add_argument("--mau", type=int, default=20_000,
                   help="Monthly active users. Default 20,000.")
    p.add_argument("--scenario", choices=sorted(SCENARIOS),
                   help="Preset scenario. Individual flags below override.")
    p.add_argument("--sessions", type=float,
                   help="Sessions per MAU per month. Overrides scenario.")
    p.add_argument("--formats", type=str,
                   help=("Comma-separated list of formats. "
                         f"Choices: {','.join(FORMATS)}. "
                         "Overrides scenario."))
    p.add_argument("--ecpm-position", type=float,
                   help="0.0=low, 0.5=mid, 1.0=high within each format's range.")
    p.add_argument("--fill-rate", type=float,
                   help="Ad request fill rate in [0,1]. Typical 0.88-0.97.")
    p.add_argument("--consent-penalty", type=float,
                   help=("Multiplier for GDPR consent effect in [0,1]. "
                         "1.0 = full personalized ads; 0.5 = half revenue lost."))
    p.add_argument("--premium-conversion", type=float,
                   help="Fraction of MAU on the premium (ad-free) tier in [0,1].")
    p.add_argument("--geo-multiplier", type=float, default=1.0,
                   help=("Extra eCPM multiplier for geo mix. CH-heavy = 1.2, "
                         "ES/IT-heavy = 0.85. Default 1.0."))
    p.add_argument("--sweep-mau", action="store_true",
                   help="Print a MAU sensitivity table instead of a single estimate.")
    return p


def _resolve(args: argparse.Namespace) -> tuple[Scenario, dict[str, object]]:
    scenario = SCENARIOS[args.scenario] if args.scenario else SCENARIOS["moderate"]
    overrides: dict[str, object] = {}
    if args.sessions is not None:
        overrides["sessions_per_mau"] = args.sessions
    if args.formats:
        overrides["formats"] = tuple(f.strip() for f in args.formats.split(","))
    if args.ecpm_position is not None:
        overrides["ecpm_position"] = args.ecpm_position
    if args.fill_rate is not None:
        overrides["fill_rate"] = args.fill_rate
    if args.consent_penalty is not None:
        overrides["consent_penalty"] = args.consent_penalty
    if args.premium_conversion is not None:
        overrides["premium_conversion"] = args.premium_conversion
    return scenario, overrides


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    scenario, overrides = _resolve(args)

    # If the user specified individual flags without a scenario, respect the
    # implicit "moderate" default but let overrides fully shape the run.
    effective = replace(
        scenario,
        formats=overrides.get("formats", scenario.formats),  # type: ignore[arg-type]
        sessions_per_mau=overrides.get("sessions_per_mau", scenario.sessions_per_mau),  # type: ignore[arg-type]
        ecpm_position=overrides.get("ecpm_position", scenario.ecpm_position),  # type: ignore[arg-type]
        fill_rate=overrides.get("fill_rate", scenario.fill_rate),  # type: ignore[arg-type]
        consent_penalty=overrides.get("consent_penalty", scenario.consent_penalty),  # type: ignore[arg-type]
        premium_conversion=overrides.get("premium_conversion", scenario.premium_conversion),  # type: ignore[arg-type]
    )

    if args.sweep_mau:
        _sensitivity_table(effective, args.geo_multiplier)
        return 0

    est = estimate_from_scenario(
        effective, mau=args.mau, geo_multiplier=args.geo_multiplier
    )
    print(f"Scenario: {effective.name}   Formats: {', '.join(effective.formats)}")
    print(f"Sessions/MAU: {effective.sessions_per_mau}   "
          f"eCPM position: {effective.ecpm_position:.2f}   "
          f"Fill: {effective.fill_rate:.0%}   "
          f"Consent: {effective.consent_penalty:.0%}   "
          f"Premium conv: {effective.premium_conversion:.1%}   "
          f"Geo ×{args.geo_multiplier:.2f}")
    print()
    est.print_report(args.mau)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

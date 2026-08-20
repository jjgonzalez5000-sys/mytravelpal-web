from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

# Make the sibling module importable when running under `pytest tools/`.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from ad_revenue_calculator import (  # noqa: E402
    FORMATS,
    SCENARIOS,
    _interpolate_ecpm,
    estimate,
    estimate_from_scenario,
)


class TestInterpolate:
    def test_low_returns_low_bound(self) -> None:
        assert _interpolate_ecpm(FORMATS["banner"], 0.0) == FORMATS["banner"].ecpm_eur_low

    def test_high_returns_high_bound(self) -> None:
        assert _interpolate_ecpm(FORMATS["banner"], 1.0) == FORMATS["banner"].ecpm_eur_high

    def test_mid_matches_midpoint(self) -> None:
        assert _interpolate_ecpm(FORMATS["banner"], 0.5) == FORMATS["banner"].ecpm_mid

    def test_clamps_out_of_range(self) -> None:
        assert _interpolate_ecpm(FORMATS["banner"], -1.0) == FORMATS["banner"].ecpm_eur_low
        assert _interpolate_ecpm(FORMATS["banner"], 2.0) == FORMATS["banner"].ecpm_eur_high


class TestEstimateFormula:
    def test_hand_check_banner_only(self) -> None:
        """Banner low=0.5, high=2.0, imp/s=2.
        At MAU=1000, sessions=1, ecpm_position=0 (low), fill=1, consent=1,
        premium=0, geo=1: sessions=1000, impressions=2000, revenue = 2000*0.5/1000 = 1.
        """
        est = estimate(
            mau=1000,
            sessions_per_mau=1.0,
            formats=("banner",),
            ecpm_position=0.0,
            fill_rate=1.0,
            consent_penalty=1.0,
            premium_conversion=0.0,
        )
        assert est.monthly_revenue_eur == pytest.approx(1.0)
        assert est.annual_revenue_eur == pytest.approx(12.0)

    def test_premium_conversion_reduces_ad_eligible_mau(self) -> None:
        est_none = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            premium_conversion=0.0,
        )
        est_ten = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            premium_conversion=0.10,
        )
        assert est_ten.monthly_revenue_eur == pytest.approx(
            est_none.monthly_revenue_eur * 0.9,
        )

    def test_geo_multiplier_scales_revenue(self) -> None:
        base = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            geo_multiplier=1.0,
        )
        high = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            geo_multiplier=1.5,
        )
        assert high.monthly_revenue_eur == pytest.approx(base.monthly_revenue_eur * 1.5)

    def test_consent_penalty_scales_revenue(self) -> None:
        base = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            consent_penalty=1.0,
        )
        half = estimate(
            mau=10_000, sessions_per_mau=5, formats=("banner",),
            consent_penalty=0.5,
        )
        assert half.monthly_revenue_eur == pytest.approx(base.monthly_revenue_eur * 0.5)

    def test_multi_format_sums_breakdowns(self) -> None:
        est = estimate(
            mau=10_000,
            sessions_per_mau=5,
            formats=("banner", "native", "interstitial"),
        )
        assert len(est.breakdown) == 3
        assert est.monthly_revenue_eur == pytest.approx(
            sum(b.revenue_eur for b in est.breakdown),
        )

    def test_duplicate_formats_deduped(self) -> None:
        once = estimate(mau=1_000, sessions_per_mau=1, formats=("banner",))
        twice = estimate(mau=1_000, sessions_per_mau=1, formats=("banner", "banner"))
        assert once.monthly_revenue_eur == pytest.approx(twice.monthly_revenue_eur)

    def test_zero_mau_yields_zero_revenue(self) -> None:
        est = estimate(mau=0, sessions_per_mau=5, formats=("banner", "native"))
        assert est.monthly_revenue_eur == 0.0


class TestValidation:
    def test_rejects_unknown_format(self) -> None:
        with pytest.raises(ValueError, match="Unknown ad formats"):
            estimate(mau=1_000, sessions_per_mau=1, formats=("skywriting",))

    @pytest.mark.parametrize(
        "kwargs",
        [
            {"fill_rate": 1.5},
            {"consent_penalty": -0.1},
            {"premium_conversion": 2.0},
            {"geo_multiplier": 0.0},
            {"mau": -1},
            {"sessions_per_mau": -1},
        ],
    )
    def test_rejects_out_of_range(self, kwargs: dict[str, float]) -> None:
        base = {"mau": 1_000, "sessions_per_mau": 1, "formats": ("banner",)}
        base.update(kwargs)
        with pytest.raises(ValueError):
            estimate(**base)


class TestScenarios:
    def test_aggressive_beats_moderate_beats_conservative(self) -> None:
        c = estimate_from_scenario(SCENARIOS["conservative"], mau=50_000)
        m = estimate_from_scenario(SCENARIOS["moderate"], mau=50_000)
        a = estimate_from_scenario(SCENARIOS["aggressive"], mau=50_000)
        assert c.monthly_revenue_eur < m.monthly_revenue_eur < a.monthly_revenue_eur

    def test_overrides_are_applied(self) -> None:
        base = estimate_from_scenario(SCENARIOS["moderate"], mau=50_000)
        boosted = estimate_from_scenario(
            SCENARIOS["moderate"], mau=50_000, overrides={"sessions_per_mau": 20.0}
        )
        assert boosted.monthly_revenue_eur > base.monthly_revenue_eur


class TestCli:
    def test_help_runs(self) -> None:
        result = subprocess.run(
            [sys.executable, "tools/ad_revenue_calculator.py", "--help"],
            capture_output=True, text=True, cwd=Path(__file__).resolve().parents[1],
        )
        assert result.returncode == 0
        assert "Estimate ad revenue" in result.stdout

    def test_scenario_moderate_prints_totals(self) -> None:
        result = subprocess.run(
            [
                sys.executable, "tools/ad_revenue_calculator.py",
                "--scenario", "moderate", "--mau", "20000",
            ],
            capture_output=True, text=True, cwd=Path(__file__).resolve().parents[1],
        )
        assert result.returncode == 0
        assert "TOTAL / month" in result.stdout
        assert "TOTAL / year" in result.stdout

    def test_sweep_mau(self) -> None:
        result = subprocess.run(
            [
                sys.executable, "tools/ad_revenue_calculator.py",
                "--scenario", "aggressive", "--sweep-mau",
            ],
            capture_output=True, text=True, cwd=Path(__file__).resolve().parents[1],
        )
        assert result.returncode == 0
        assert "Sensitivity" in result.stdout
        assert "500,000" in result.stdout

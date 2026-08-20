from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from funnel_calculator import (  # noqa: E402
    FUNNEL_SCENARIOS,
    estimate_funnel,
)
from subscription_revenue_calculator import (  # noqa: E402
    SCENARIOS as SUB_SCENARIOS,
    _blended_arpu_month,
    estimate_from_scenario,
    estimate_subs,
)


class TestBlendedARPU:
    def test_all_monthly_returns_monthly_price(self) -> None:
        assert _blended_arpu_month(3.99, 29.99, annual_mix=0.0, intro_discount=0.0) == 3.99

    def test_all_annual_returns_annual_per_month(self) -> None:
        assert _blended_arpu_month(3.99, 24.0, annual_mix=1.0, intro_discount=0.0) == 2.0

    def test_intro_discount_scales_arpu_down(self) -> None:
        full = _blended_arpu_month(4.0, 48.0, annual_mix=0.5, intro_discount=0.0)
        discounted = _blended_arpu_month(4.0, 48.0, annual_mix=0.5, intro_discount=0.25)
        assert discounted == pytest.approx(full * 0.75)


class TestEstimateSubs:
    def test_hand_check(self) -> None:
        """MAU=10000, conv=0.01 → 100 payers.
        arpu = 3.99*(1-0.5) + 24/12*0.5 = 1.995 + 1.0 = 2.995.
        No intro discount → gross = 100 * 2.995 = 299.50.
        Store cut 0.30 → net = 299.50 * 0.70 = 209.65.
        """
        est = estimate_subs(
            mau=10_000, conversion_rate=0.01,
            monthly_price_eur=3.99, annual_price_eur=24.0,
            annual_mix=0.5, monthly_churn=0.1,
            store_cut=0.30, intro_discount=0.0,
        )
        assert est.paying_users == pytest.approx(100.0)
        assert est.gross_monthly_revenue_eur == pytest.approx(299.5)
        assert est.net_monthly_revenue_eur == pytest.approx(209.65)
        # LTV = arpu * (1 - store_cut) / churn = 2.995 * 0.7 / 0.1 = 20.965
        assert est.ltv_per_user_eur == pytest.approx(20.965)

    def test_zero_mau_yields_zero(self) -> None:
        est = estimate_from_scenario(SUB_SCENARIOS["moderate"], mau=0)
        assert est.net_monthly_revenue_eur == 0

    def test_aggressive_beats_moderate_beats_conservative(self) -> None:
        c = estimate_from_scenario(SUB_SCENARIOS["conservative"], mau=50_000)
        m = estimate_from_scenario(SUB_SCENARIOS["moderate"], mau=50_000)
        a = estimate_from_scenario(SUB_SCENARIOS["aggressive"], mau=50_000)
        assert c.net_monthly_revenue_eur < m.net_monthly_revenue_eur < a.net_monthly_revenue_eur

    @pytest.mark.parametrize(
        "kwargs",
        [
            {"conversion_rate": -0.01},
            {"annual_mix": 1.5},
            {"store_cut": 2.0},
            {"intro_discount": -0.1},
            {"monthly_churn": 0.0},
            {"monthly_churn": 1.5},
            {"monthly_price_eur": -1.0},
            {"mau": -100},
        ],
    )
    def test_rejects_out_of_range(self, kwargs: dict[str, float]) -> None:
        base = {
            "mau": 1000, "conversion_rate": 0.02,
            "monthly_price_eur": 3.99, "annual_price_eur": 29.99,
            "annual_mix": 0.5, "monthly_churn": 0.06,
            "store_cut": 0.20, "intro_discount": 0.1,
        }
        base.update(kwargs)
        with pytest.raises(ValueError):
            estimate_subs(**base)


class TestFunnel:
    def test_zero_installs_yields_zero_mau(self) -> None:
        est = estimate_funnel(
            installs=0, funnel_scenario=FUNNEL_SCENARIOS["moderate"],
        )
        assert est.mau == 0
        assert est.total_monthly_eur == 0

    def test_more_installs_more_revenue(self) -> None:
        a = estimate_funnel(installs=10_000, funnel_scenario=FUNNEL_SCENARIOS["moderate"])
        b = estimate_funnel(installs=100_000, funnel_scenario=FUNNEL_SCENARIOS["moderate"])
        assert b.total_monthly_eur > a.total_monthly_eur

    def test_aggressive_funnel_produces_more_mau_at_same_installs(self) -> None:
        c = estimate_funnel(installs=50_000, funnel_scenario=FUNNEL_SCENARIOS["conservative"])
        a = estimate_funnel(installs=50_000, funnel_scenario=FUNNEL_SCENARIOS["aggressive"])
        assert a.mau > c.mau

    def test_total_equals_ads_plus_subs(self) -> None:
        est = estimate_funnel(installs=25_000, funnel_scenario=FUNNEL_SCENARIOS["moderate"])
        assert est.total_monthly_eur == pytest.approx(
            est.ad_monthly_eur + est.sub_monthly_eur,
        )


class TestCli:
    _cwd = Path(__file__).resolve().parents[1]

    def _run(self, script: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, f"tools/{script}", *args],
            capture_output=True, text=True, cwd=self._cwd,
        )

    def test_subs_scenario_prints_report(self) -> None:
        r = self._run("subscription_revenue_calculator.py",
                      "--scenario", "moderate", "--mau", "20000")
        assert r.returncode == 0
        assert "Net monthly" in r.stdout
        assert "LTV" in r.stdout

    def test_subs_sweep_prints_table(self) -> None:
        r = self._run("subscription_revenue_calculator.py",
                      "--scenario", "aggressive", "--sweep-mau")
        assert r.returncode == 0
        assert "Sensitivity" in r.stdout

    def test_funnel_defaults(self) -> None:
        r = self._run("funnel_calculator.py", "--installs", "50000",
                      "--scenario", "moderate")
        assert r.returncode == 0
        assert "TOTAL / month" in r.stdout
        assert "Ad revenue" in r.stdout
        assert "Sub revenue" in r.stdout

    def test_funnel_sweep(self) -> None:
        r = self._run("funnel_calculator.py",
                      "--scenario", "moderate", "--sweep-installs")
        assert r.returncode == 0
        assert "1,000,000" in r.stdout

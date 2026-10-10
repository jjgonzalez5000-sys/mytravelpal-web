"""Vignettes are reported per country, not as one lump sum."""

from __future__ import annotations

from types import SimpleNamespace

from app.api.v1.trips import _enrich_route, _merge_route, _vignette_lines, _empty_route


def _toll(operator: str, cost: float, vignette: bool = True):
    return SimpleNamespace(operator=operator, cost_eur=cost, is_vignette=vignette)


class TestVignetteLines:
    def test_one_line_per_country_with_its_price(self):
        lines = _vignette_lines((
            _toll("Austria Autobahn Vignette", 12.8),
            _toll("Schweiz Vignette", 40.0),
        ))
        assert [(l.country, l.cost_eur) for l in lines] == [("AT", 12.8), ("CH", 40.0)]

    def test_a_country_with_two_stickers_is_summed(self):
        lines = _vignette_lines((
            _toll("Slovakia e-vignette", 5.0),
            _toll("Slovak motorway", 2.5),
        ))
        assert [(l.country, l.cost_eur) for l in lines] == [("SK", 7.5)]

    def test_booth_tolls_are_not_vignettes(self):
        assert _vignette_lines((_toll("Autoroutes du Sud", 9.0, vignette=False),)) == []

    def test_unrecognised_country_is_left_out(self):
        assert _vignette_lines((_toll("Mystery operator", 9.0),)) == []

    def test_enrich_route_carries_the_lines(self):
        out = _enrich_route(
            toll_total_eur=60.0,
            real_tolls=(_toll("Austria Vignette", 12.8), _toll("France péage", 7.0, False)),
        )
        assert out.vignette_cost_eur == 12.8
        assert [(l.country, l.cost_eur) for l in out.vignettes] == [("AT", 12.8)]

    def test_merge_prefers_the_verified_lines(self):
        core = _empty_route()
        enrich = _enrich_route(
            toll_total_eur=50.0, real_tolls=(_toll("Switzerland vignette", 40.0),),
        )
        merged = _merge_route(core, enrich)
        assert [(l.country, l.cost_eur) for l in merged.vignettes] == [("CH", 40.0)]

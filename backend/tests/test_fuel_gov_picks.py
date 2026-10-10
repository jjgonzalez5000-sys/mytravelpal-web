"""Government fuel feeds (ES / FR / IT / PT) must never quote another fuel's
price as the driver's fuel.

Regression: a petrol driver saw 0.961 / 0.969 EUR/L at French stations
because stations without petrol fell through to their LPG / E85 column and
that price was shown as petrol, as a 42 EUR "saving".
"""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from app.domain import Coordinate, Country
from app.providers import fuel_gov
from app.providers.fuel_gov import _pick_primary_price, _Station, _station_to_fuel_price


def _route():
    # The conversion only reads the route's origin.
    return SimpleNamespace(origin=Coordinate(lat=47.75, lon=7.34))


class TestPickPrimaryPrice:
    def test_petrol_driver_never_gets_lpg_or_e85(self):
        assert _pick_primary_price(
            {"lpg": 0.969, "e85": 0.72}, "petrol", Country.FR,
        ) is None

    def test_petrol_driver_does_not_get_a_diesel_price(self):
        assert _pick_primary_price({"diesel": 1.74}, "petrol", Country.FR) is None

    def test_petrol_driver_gets_petrol_even_if_lpg_is_cheaper(self):
        got = _pick_primary_price(
            {"lpg": 0.969, "sp95": 1.79, "diesel": 1.7}, "petrol", Country.FR,
        )
        assert got == ("sp95", 1.79)

    def test_diesel_driver_gets_diesel_only(self):
        assert _pick_primary_price(
            {"sp95": 1.79, "lpg": 0.97}, "diesel", Country.ES,
        ) is None
        assert _pick_primary_price(
            {"sp95": 1.79, "diesel": 1.62}, "diesel", Country.ES,
        ) == ("diesel", 1.62)

    def test_unknown_fuel_still_excludes_alternative_fuels(self):
        assert _pick_primary_price({"lpg": 0.97, "e85": 0.8}, None, Country.IT) is None
        assert _pick_primary_price(
            {"lpg": 0.97, "diesel": 1.7}, None, Country.IT,
        ) == ("diesel", 1.7)

    @pytest.mark.parametrize("country", [Country.FR, Country.ES, Country.IT])
    def test_implausibly_low_road_fuel_price_is_dropped(self, country):
        # 0.969 EUR/L passes a flat 0.90 floor but is far below any of
        # these countries' usual pump price.
        assert _pick_primary_price({"sp95": 0.969}, "petrol", country) is None

    def test_lpg_driver_keeps_the_cheap_lpg_price(self):
        assert _pick_primary_price(
            {"lpg": 0.969, "sp95": 1.79}, "lpg", Country.FR,
        ) == ("lpg", 0.969)

    def test_hybrid_is_treated_as_petrol(self):
        assert _pick_primary_price(
            {"lpg": 0.97, "sp95": 1.8}, "hybrid", Country.FR,
        ) == ("sp95", 1.8)


class TestStationConversion:
    def _station(self, prices):
        return _Station(Coordinate(lat=47.7, lon=7.3), "Mulhouse", None, prices)

    def test_lpg_only_station_is_not_offered_to_a_petrol_driver(self):
        st = self._station({"lpg": 0.961})
        assert _station_to_fuel_price(
            st, _route(), 1.0, Country.FR, preferred_fuel="petrol",
        ) is None

    def test_petrol_station_is_priced_with_its_petrol_column(self):
        st = self._station({"lpg": 0.961, "sp95": 1.789})
        fp = _station_to_fuel_price(
            st, _route(), 1.0, Country.FR, preferred_fuel="petrol",
        )
        assert fp is not None
        assert fp.price_eur_per_l == pytest.approx(1.789)
        assert dict(fp.attributes)["primary_fuel"] == "sp95"


class TestFeedParsers:
    def test_spain_lpg_only_station_is_skipped_for_petrol(self):
        import json

        raw = json.dumps({"ListaEESSPrecio": [{
            "Latitud": "40,4", "Longitud (WGS84)": "-3,7", "Rótulo": "X",
            "Precio Gases licuados del petróleo": "0,899",
        }]}).encode()
        stations = fuel_gov._parse_spain(raw)
        assert len(stations) == 1
        assert _pick_primary_price(
            stations[0].prices, "petrol", Country.ES,
        ) is None

    def test_italy_mixed_station_keeps_benzina_for_petrol(self):
        registry = (
            "Estrazione del 2026-10-09\n"
            "idImpianto|Gestore|Bandiera|Tipo|Nome|Indirizzo|Comune|Prov|Lat|Lon\n"
            "1|G|Q8|Stradale|Pompa|Via|Roma|RM|41.9|12.5\n"
        )
        prices = (
            "Estrazione del 2026-10-09\n"
            "idImpianto|descCarburante|prezzo|isSelf|dtComu\n"
            "1|GPL|0.719|1|x\n"
            "1|Benzina|1.869|1|x\n"
        )
        stations = fuel_gov._parse_italy(registry, prices)
        assert len(stations) == 1
        assert _pick_primary_price(
            stations[0].prices, "petrol", Country.IT,
        ) == ("sp95", 1.869)

"""HERE fuel codes follow HERE's own catalogue (GET /v3/fuelTypes).

Regression: the table assumed 1 = petrol E10, 53 = diesel and 55 = Super 95.
The catalogue says 1 = Diesel, 53 = Super E5, 54 = Super E10, 55 = Premium
Diesel, so a petrol driver in Germany or Austria was quoted diesel prices and
a diesel driver was quoted petrol.
"""

from __future__ import annotations

import pytest

from app.providers.fuel_here import (
    _attributes_from_prices_api,
    _extract_fuel_price_from_prices_api as pick,
)


def _p(code, price, cur="EUR"):
    return {"fuelType": code, "price": price, "currency": cur}


# A Munich-like station: diesel (1), Super E5 (53), Super E10 (54),
# Premium Diesel (55), AdBlue car (71) and truck (72), LPG (14).
STATION = {"prices": [
    _p("1", 1.99), _p("53", 2.18), _p("54", 2.10), _p("55", 2.09),
    _p("71", 1.27), _p("72", 1.27), _p("14", 1.05),
]}


class TestCodesFollowTheCatalogue:
    def test_petrol_driver_gets_super_e10_not_diesel(self):
        price, label = pick(STATION, "petrol")
        assert price == pytest.approx(2.10) and label == "Super E10"

    def test_petrol_falls_back_to_e5_when_there_is_no_e10(self):
        station = {"prices": [_p("1", 1.99), _p("53", 2.18)]}
        assert pick(station, "petrol") == (pytest.approx(2.18), "Super E5")

    def test_diesel_driver_gets_diesel_not_petrol(self):
        price, label = pick(STATION, "diesel")
        assert price == pytest.approx(1.99) and label == "Diesel"

    def test_premium_diesel_only_after_plain_diesel(self):
        station = {"prices": [_p("55", 2.09), _p("54", 2.10)]}
        price, label = pick(station, "diesel")
        assert price == pytest.approx(2.09) and label == "Premium Diesel"

    @pytest.mark.parametrize("fuel", ["petrol", "hybrid", "gasoline"])
    def test_a_petrol_family_driver_is_never_quoted_diesel(self, fuel):
        station = {"prices": [_p("1", 1.99), _p("55", 2.09)]}
        assert pick(station, fuel) == (None, None)

    def test_a_diesel_driver_is_never_quoted_petrol(self):
        station = {"prices": [_p("54", 2.10), _p("53", 2.18)]}
        assert pick(station, "diesel") == (None, None)

    def test_adblue_is_never_a_fuel_price(self):
        station = {"prices": [_p("71", 1.27), _p("72", 1.27)]}
        assert pick(station, "diesel") == (None, None)
        assert pick(station, "petrol") == (None, None)

    def test_lpg_and_e85_drivers_read_their_own_codes(self):
        station = {"prices": [_p("14", 0.95), _p("5", 0.99), _p("54", 2.10)]}
        assert pick(station, "lpg")[0] == pytest.approx(0.95)
        assert pick(station, "e85")[0] == pytest.approx(0.99)


class TestAdBlue:
    def test_car_and_truck_prices_are_exposed_as_attributes(self):
        attrs = dict(_attributes_from_prices_api({
            "name": "Shell",
            "prices": [_p("71", 1.269), _p("72", 1.349)],
        }))
        assert attrs["adblue"] == "1.269"
        assert attrs["adblue_truck"] == "1.349"

    def test_generic_adblue_code_counts_for_cars(self):
        attrs = dict(_attributes_from_prices_api({
            "name": "X", "prices": [_p("19", 0.99)],
        }))
        assert attrs["adblue"] == "0.990"
        assert "adblue_truck" not in attrs

    def test_no_adblue_no_attribute(self):
        attrs = dict(_attributes_from_prices_api({"name": "X", "prices": [_p("1", 2.0)]}))
        assert "adblue" not in attrs

    def test_swiss_francs_are_converted(self):
        attrs = dict(_attributes_from_prices_api({
            "name": "X", "prices": [_p("71", 1.0, "CHF")],
        }))
        assert float(attrs["adblue"]) == pytest.approx(1.05)


class TestGovFeedsKeepAdBlueAsAttributeOnly:
    def test_spain_adblue_is_parsed_but_never_the_primary_price(self):
        import json

        from app.domain import Country
        from app.providers import fuel_gov

        raw = json.dumps({"ListaEESSPrecio": [{
            "Latitud": "40,4", "Longitud (WGS84)": "-3,7", "Rótulo": "X",
            "Precio Gasoleo A": "1,55", "Precio Adblue": "0,69",
        }]}).encode()
        st = fuel_gov._parse_spain(raw)[0]
        assert st.prices["adblue"] == pytest.approx(0.69)
        assert fuel_gov._pick_primary_price(st.prices, "diesel", Country.ES) == ("diesel", 1.55)
        # An AdBlue-only station sells no fuel: nothing to offer a driver.
        assert fuel_gov._pick_primary_price({"adblue": 0.69}, "diesel", Country.ES) is None
        assert fuel_gov._pick_primary_price({"adblue": 0.69}, None, Country.ES) is None

from __future__ import annotations

from app.domain import Coordinate, Country
from app.services.country_detection import detect_country, infer_countries_crossed


def test_detects_launch_countries_from_city_centres() -> None:
    assert detect_country(Coordinate(48.8566, 2.3522)) is Country.FR   # Paris
    assert detect_country(Coordinate(40.4168, -3.7038)) is Country.ES  # Madrid
    assert detect_country(Coordinate(41.9028, 12.4964)) is Country.IT  # Roma
    assert detect_country(Coordinate(46.9481, 7.4474)) is Country.CH   # Bern


def test_detects_more_european_countries() -> None:
    assert detect_country(Coordinate(52.52, 13.405)) is Country.DE   # Berlin
    assert detect_country(Coordinate(52.37, 4.90)) is Country.NL     # Amsterdam
    assert detect_country(Coordinate(59.33, 18.07)) is Country.SE    # Stockholm
    assert detect_country(Coordinate(52.23, 21.01)) is Country.PL    # Warszawa
    assert detect_country(Coordinate(38.72, -9.14)) is Country.PT    # Lisboa


def test_returns_none_outside_all_supported_countries() -> None:
    # Middle of the North Atlantic — outside every bbox.
    assert detect_country(Coordinate(0.0, -30.0)) is None
    # Central Sahara — Africa, unsupported.
    assert detect_country(Coordinate(20.0, 10.0)) is None


def test_infer_countries_crossed_preserves_order_and_dedupes() -> None:
    paris = Coordinate(48.8566, 2.3522)
    lyon = Coordinate(45.764, 4.8357)
    madrid = Coordinate(40.4168, -3.7038)
    result = infer_countries_crossed([paris, lyon, madrid])
    assert result == (Country.FR, Country.ES)


def test_ch_wins_over_fr_at_border_overlap() -> None:
    """A point plausibly inside both CH and FR bounding boxes (near Geneva)
    should resolve to CH because CH is smaller and checked first.
    """
    # Near Geneva, Swiss side.
    assert detect_country(Coordinate(46.20, 6.15)) is Country.CH

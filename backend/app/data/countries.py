"""Country data table.

One row per supported country. Providers pull anchors, bounding boxes,
toll pricing and sample cities from here so we don't have per-country
data scattered across the codebase.

Coverage: EU-27 + United Kingdom + Norway + Iceland + Switzerland
(≈30 countries). Balkans, Turkey, Belarus/Russia/Ukraine and the
micro-states are deferred — their toll and vignette systems are
country-specific enough that hand-rolling the mock isn't worth it
before we contract a real routing provider.

Bounding boxes are axis-aligned approximations of mainland extents;
they're deliberately generous so border towns get attributed. Where two
countries overlap, the country-detection service resolves ties by
checking the smaller country first (see `_PRIORITY`).

Toll model:
- `toll_per_km_eur`: applied to distance for the countries that price
  motorway usage per kilometre.
- `vignette_eur`: flat contribution added when the route crosses the
  country (amortised annual/weekly sticker cost); zero for pay-per-km
  and toll-free countries.

Anchors are EUR-denominated typical prices for a 3★ mid-tier stay, a
sit-down lunch per person and unleaded 95 fuel — plausible order of
magnitude, tuned per region. Real integrations will replace them.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class CountryData:
    code: str                   # matches Country enum value
    display_name: str
    nominatim_code: str         # lowercase two-letter for OSM Nominatim
    bbox: tuple[float, float, float, float]  # min_lat, max_lat, min_lon, max_lon
    toll_per_km_eur: float
    vignette_eur: float
    hotel_anchor_eur: float
    restaurant_anchor_eur: float
    fuel_petrol_anchor_eur: float
    # (display_name, lat, lon) — added to the mock geocoding catalogue.
    sample_cities: tuple[tuple[str, float, float], ...] = ()


COUNTRIES: dict[str, CountryData] = {
    # -- Launch four (existing) -----------------------------------------------
    "CH": CountryData(
        "CH", "Switzerland", "ch",
        (45.82, 47.81, 5.96, 10.49),
        toll_per_km_eur=0.0, vignette_eur=40.0,
        hotel_anchor_eur=180.0, restaurant_anchor_eur=40.0,
        fuel_petrol_anchor_eur=1.75,
        sample_cities=(
            ("Zürich, Switzerland", 47.3769, 8.5417),
            ("Genève, Switzerland", 46.2044, 6.1432),
            ("Bern, Switzerland", 46.9481, 7.4474),
            ("Basel, Switzerland", 47.5596, 7.5886),
            ("Lausanne, Switzerland", 46.5197, 6.6323),
            ("Lugano, Switzerland", 46.0037, 8.9511),
        ),
    ),
    "FR": CountryData(
        "FR", "France", "fr",
        (41.36, 51.09, -5.14, 9.56),
        toll_per_km_eur=0.09, vignette_eur=0.0,
        hotel_anchor_eur=120.0, restaurant_anchor_eur=28.0,
        fuel_petrol_anchor_eur=1.80,
        sample_cities=(
            ("Paris, France", 48.8566, 2.3522),
            ("Lyon, France", 45.7640, 4.8357),
            ("Marseille, France", 43.2965, 5.3698),
            ("Bordeaux, France", 44.8378, -0.5792),
            ("Toulouse, France", 43.6047, 1.4442),
            ("Nice, France", 43.7102, 7.2620),
            ("Nantes, France", 47.2184, -1.5536),
            ("Strasbourg, France", 48.5734, 7.7521),
            ("Lille, France", 50.6292, 3.0573),
        ),
    ),
    "IT": CountryData(
        "IT", "Italy", "it",
        (35.49, 47.09, 6.63, 18.52),
        toll_per_km_eur=0.08, vignette_eur=0.0,
        hotel_anchor_eur=110.0, restaurant_anchor_eur=25.0,
        fuel_petrol_anchor_eur=1.85,
        sample_cities=(
            ("Roma, Italy", 41.9028, 12.4964),
            ("Milano, Italy", 45.4642, 9.1900),
            ("Napoli, Italy", 40.8518, 14.2681),
            ("Torino, Italy", 45.0703, 7.6869),
            ("Firenze, Italy", 43.7696, 11.2558),
            ("Bologna, Italy", 44.4949, 11.3426),
            ("Venezia, Italy", 45.4408, 12.3155),
            ("Palermo, Italy", 38.1157, 13.3615),
        ),
    ),
    "ES": CountryData(
        "ES", "Spain", "es",
        (35.95, 43.79, -9.30, 4.32),
        toll_per_km_eur=0.07, vignette_eur=0.0,
        hotel_anchor_eur=95.0, restaurant_anchor_eur=22.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Madrid, Spain", 40.4168, -3.7038),
            ("Barcelona, Spain", 41.3874, 2.1686),
            ("Valencia, Spain", 39.4699, -0.3763),
            ("Sevilla, Spain", 37.3891, -5.9845),
            ("Bilbao, Spain", 43.2630, -2.9350),
            ("Zaragoza, Spain", 41.6488, -0.8891),
            ("Málaga, Spain", 36.7213, -4.4213),
            ("Palma, Spain", 39.5696, 2.6502),
        ),
    ),

    # -- Nordics -------------------------------------------------------------
    "NO": CountryData(
        "NO", "Norway", "no",
        (57.9, 71.2, 4.5, 31.2),
        toll_per_km_eur=0.06, vignette_eur=0.0,
        hotel_anchor_eur=170.0, restaurant_anchor_eur=38.0,
        fuel_petrol_anchor_eur=2.10,
        sample_cities=(
            ("Oslo, Norway", 59.9139, 10.7522),
            ("Bergen, Norway", 60.3913, 5.3221),
        ),
    ),
    "SE": CountryData(
        "SE", "Sweden", "se",
        (55.3, 69.1, 10.9, 24.2),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=140.0, restaurant_anchor_eur=32.0,
        fuel_petrol_anchor_eur=1.90,
        sample_cities=(
            ("Stockholm, Sweden", 59.3293, 18.0686),
            ("Göteborg, Sweden", 57.7089, 11.9746),
        ),
    ),
    "DK": CountryData(
        "DK", "Denmark", "dk",
        (54.5, 57.8, 8.0, 15.2),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=145.0, restaurant_anchor_eur=32.0,
        fuel_petrol_anchor_eur=1.95,
        sample_cities=(
            ("København, Denmark", 55.6761, 12.5683),
            ("Aarhus, Denmark", 56.1629, 10.2039),
        ),
    ),
    "FI": CountryData(
        "FI", "Finland", "fi",
        (59.7, 70.1, 20.5, 31.6),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=130.0, restaurant_anchor_eur=28.0,
        fuel_petrol_anchor_eur=1.95,
        sample_cities=(
            ("Helsinki, Finland", 60.1699, 24.9384),
            ("Tampere, Finland", 61.4978, 23.7610),
        ),
    ),
    "IS": CountryData(
        "IS", "Iceland", "is",
        (63.3, 66.6, -24.6, -13.5),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=200.0, restaurant_anchor_eur=45.0,
        fuel_petrol_anchor_eur=2.20,
        sample_cities=(
            ("Reykjavík, Iceland", 64.1466, -21.9426),
        ),
    ),

    # -- Western Europe ------------------------------------------------------
    "DE": CountryData(
        "DE", "Germany", "de",
        (47.3, 55.1, 5.9, 15.0),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=115.0, restaurant_anchor_eur=25.0,
        fuel_petrol_anchor_eur=1.80,
        sample_cities=(
            ("Berlin, Germany", 52.5200, 13.4050),
            ("München, Germany", 48.1351, 11.5820),
            ("Hamburg, Germany", 53.5511, 9.9937),
            ("Frankfurt, Germany", 50.1109, 8.6821),
            ("Köln, Germany", 50.9375, 6.9603),
        ),
    ),
    "AT": CountryData(
        "AT", "Austria", "at",
        (46.4, 49.0, 9.5, 17.2),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=120.0, restaurant_anchor_eur=25.0,
        fuel_petrol_anchor_eur=1.70,
        sample_cities=(
            ("Wien, Austria", 48.2082, 16.3738),
            ("Salzburg, Austria", 47.8095, 13.0550),
            ("Innsbruck, Austria", 47.2692, 11.4041),
        ),
    ),
    "BE": CountryData(
        "BE", "Belgium", "be",
        (49.5, 51.5, 2.5, 6.4),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=125.0, restaurant_anchor_eur=28.0,
        fuel_petrol_anchor_eur=1.85,
        sample_cities=(
            ("Bruxelles, Belgium", 50.8503, 4.3517),
            ("Antwerpen, Belgium", 51.2194, 4.4025),
        ),
    ),
    "NL": CountryData(
        "NL", "Netherlands", "nl",
        (50.7, 53.6, 3.3, 7.2),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=140.0, restaurant_anchor_eur=28.0,
        fuel_petrol_anchor_eur=2.05,
        sample_cities=(
            ("Amsterdam, Netherlands", 52.3676, 4.9041),
            ("Rotterdam, Netherlands", 51.9244, 4.4777),
            ("Utrecht, Netherlands", 52.0907, 5.1214),
        ),
    ),
    "LU": CountryData(
        "LU", "Luxembourg", "lu",
        (49.4, 50.2, 5.7, 6.5),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=150.0, restaurant_anchor_eur=32.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Luxembourg, Luxembourg", 49.6117, 6.1319),
        ),
    ),
    "IE": CountryData(
        "IE", "Ireland", "ie",
        (51.4, 55.4, -10.5, -5.9),
        toll_per_km_eur=0.06, vignette_eur=0.0,
        hotel_anchor_eur=140.0, restaurant_anchor_eur=30.0,
        fuel_petrol_anchor_eur=1.85,
        sample_cities=(
            ("Dublin, Ireland", 53.3498, -6.2603),
            ("Cork, Ireland", 51.8985, -8.4756),
        ),
    ),
    "GB": CountryData(
        "GB", "United Kingdom", "gb",
        (49.9, 60.9, -8.6, 1.9),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=135.0, restaurant_anchor_eur=32.0,
        fuel_petrol_anchor_eur=1.75,
        sample_cities=(
            ("London, United Kingdom", 51.5074, -0.1278),
            ("Manchester, United Kingdom", 53.4808, -2.2426),
            ("Edinburgh, United Kingdom", 55.9533, -3.1883),
        ),
    ),

    # -- Southern Europe -----------------------------------------------------
    "PT": CountryData(
        "PT", "Portugal", "pt",
        (36.9, 42.2, -9.6, -6.1),
        toll_per_km_eur=0.10, vignette_eur=0.0,
        hotel_anchor_eur=90.0, restaurant_anchor_eur=20.0,
        fuel_petrol_anchor_eur=1.75,
        sample_cities=(
            ("Lisboa, Portugal", 38.7223, -9.1393),
            ("Porto, Portugal", 41.1579, -8.6291),
        ),
    ),
    "GR": CountryData(
        "GR", "Greece", "gr",
        (34.8, 41.8, 19.3, 28.3),
        toll_per_km_eur=0.05, vignette_eur=0.0,
        hotel_anchor_eur=85.0, restaurant_anchor_eur=20.0,
        fuel_petrol_anchor_eur=1.85,
        sample_cities=(
            ("Athens, Greece", 37.9838, 23.7275),
            ("Thessaloniki, Greece", 40.6401, 22.9444),
        ),
    ),
    "MT": CountryData(
        "MT", "Malta", "mt",
        (35.8, 36.1, 14.2, 14.6),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=105.0, restaurant_anchor_eur=22.0,
        fuel_petrol_anchor_eur=1.35,
        sample_cities=(
            ("Valletta, Malta", 35.8989, 14.5146),
        ),
    ),
    "CY": CountryData(
        "CY", "Cyprus", "cy",
        (34.5, 35.7, 32.3, 34.6),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=95.0, restaurant_anchor_eur=22.0,
        fuel_petrol_anchor_eur=1.40,
        sample_cities=(
            ("Nicosia, Cyprus", 35.1856, 33.3823),
            ("Limassol, Cyprus", 34.7071, 33.0226),
        ),
    ),

    # -- Central / Eastern Europe --------------------------------------------
    "PL": CountryData(
        "PL", "Poland", "pl",
        (49.0, 54.9, 14.1, 24.2),
        toll_per_km_eur=0.05, vignette_eur=0.0,
        hotel_anchor_eur=75.0, restaurant_anchor_eur=15.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Warszawa, Poland", 52.2297, 21.0122),
            ("Kraków, Poland", 50.0647, 19.9450),
            ("Gdańsk, Poland", 54.3520, 18.6466),
        ),
    ),
    "CZ": CountryData(
        "CZ", "Czechia", "cz",
        (48.5, 51.1, 12.1, 18.9),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=80.0, restaurant_anchor_eur=16.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Praha, Czechia", 50.0755, 14.4378),
            ("Brno, Czechia", 49.1951, 16.6068),
        ),
    ),
    "SK": CountryData(
        "SK", "Slovakia", "sk",
        (47.7, 49.6, 16.8, 22.6),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=70.0, restaurant_anchor_eur=14.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Bratislava, Slovakia", 48.1486, 17.1077),
        ),
    ),
    "HU": CountryData(
        "HU", "Hungary", "hu",
        (45.7, 48.6, 16.1, 22.9),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=75.0, restaurant_anchor_eur=16.0,
        fuel_petrol_anchor_eur=1.50,
        sample_cities=(
            ("Budapest, Hungary", 47.4979, 19.0402),
        ),
    ),
    "SI": CountryData(
        "SI", "Slovenia", "si",
        (45.4, 46.9, 13.4, 16.6),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=95.0, restaurant_anchor_eur=20.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Ljubljana, Slovenia", 46.0569, 14.5058),
        ),
    ),
    "HR": CountryData(
        "HR", "Croatia", "hr",
        (42.4, 46.6, 13.5, 19.5),
        toll_per_km_eur=0.08, vignette_eur=0.0,
        hotel_anchor_eur=90.0, restaurant_anchor_eur=20.0,
        fuel_petrol_anchor_eur=1.50,
        sample_cities=(
            ("Zagreb, Croatia", 45.8150, 15.9819),
            ("Split, Croatia", 43.5081, 16.4402),
        ),
    ),
    "RO": CountryData(
        "RO", "Romania", "ro",
        (43.6, 48.3, 20.3, 29.7),
        toll_per_km_eur=0.0, vignette_eur=3.0,
        hotel_anchor_eur=70.0, restaurant_anchor_eur=14.0,
        fuel_petrol_anchor_eur=1.45,
        sample_cities=(
            ("București, Romania", 44.4268, 26.1025),
            ("Cluj-Napoca, Romania", 46.7712, 23.6236),
        ),
    ),
    "BG": CountryData(
        "BG", "Bulgaria", "bg",
        (41.2, 44.2, 22.4, 28.6),
        toll_per_km_eur=0.0, vignette_eur=15.0,
        hotel_anchor_eur=65.0, restaurant_anchor_eur=12.0,
        fuel_petrol_anchor_eur=1.35,
        sample_cities=(
            ("Sofia, Bulgaria", 42.6977, 23.3219),
        ),
    ),
    "EE": CountryData(
        "EE", "Estonia", "ee",
        (57.5, 59.7, 21.7, 28.2),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=95.0, restaurant_anchor_eur=22.0,
        fuel_petrol_anchor_eur=1.75,
        sample_cities=(
            ("Tallinn, Estonia", 59.4370, 24.7536),
        ),
    ),
    "LV": CountryData(
        "LV", "Latvia", "lv",
        (55.6, 58.1, 20.9, 28.2),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=80.0, restaurant_anchor_eur=18.0,
        fuel_petrol_anchor_eur=1.65,
        sample_cities=(
            ("Riga, Latvia", 56.9496, 24.1052),
        ),
    ),
    "LT": CountryData(
        "LT", "Lithuania", "lt",
        (53.9, 56.5, 20.9, 26.9),
        toll_per_km_eur=0.0, vignette_eur=0.0,
        hotel_anchor_eur=75.0, restaurant_anchor_eur=16.0,
        fuel_petrol_anchor_eur=1.55,
        sample_cities=(
            ("Vilnius, Lithuania", 54.6872, 25.2797),
        ),
    ),
}


# When several bounding boxes contain a point, resolve by trying the
# smaller/priority countries first. Ordered smallest → largest, with a
# few tuned overrides where a Scandinavian country's rectangular bbox
# spuriously covers a neighbour (NO's box is very wide east–west and
# catches SE; SE has to be checked first).
_PRIORITY: tuple[str, ...] = (
    "LU", "CY", "MT", "IS",
    "CH", "AT", "SI", "SK", "BE", "NL", "DK", "IE",
    "HR", "PT", "CZ", "HU", "GR", "LT", "LV", "EE", "BG", "RO",
    "SE", "FI", "IT", "PL", "GB",
    "NO",
    "ES", "DE", "FR",
)


def priority_order() -> tuple[str, ...]:
    """Country codes in the order they should be checked for point-in-box."""
    return _PRIORITY


def all_nominatim_codes() -> str:
    """Comma-separated country codes for Nominatim's `countrycodes` param."""
    return ",".join(sorted(c.nominatim_code for c in COUNTRIES.values()))

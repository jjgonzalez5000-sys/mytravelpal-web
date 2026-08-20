from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

from app.domain import Coordinate, Country


@dataclass(frozen=True, slots=True)
class GeocodeResult:
    display_name: str
    coordinate: Coordinate
    country: Country


class GeocodingProvider(Protocol):
    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]: ...


# Small city catalogue for the four launch countries. Enough to demo
# autocomplete and drive plans end-to-end without leaving mock-land.
# Coordinates from public city-centre references.
_CATALOGUE: tuple[GeocodeResult, ...] = (
    # CH
    GeocodeResult("Zürich, Switzerland", Coordinate(47.3769, 8.5417), Country.CH),
    GeocodeResult("Genève, Switzerland", Coordinate(46.2044, 6.1432), Country.CH),
    GeocodeResult("Bern, Switzerland", Coordinate(46.9481, 7.4474), Country.CH),
    GeocodeResult("Basel, Switzerland", Coordinate(47.5596, 7.5886), Country.CH),
    GeocodeResult("Lausanne, Switzerland", Coordinate(46.5197, 6.6323), Country.CH),
    GeocodeResult("Lugano, Switzerland", Coordinate(46.0037, 8.9511), Country.CH),
    # FR
    GeocodeResult("Paris, France", Coordinate(48.8566, 2.3522), Country.FR),
    GeocodeResult("Lyon, France", Coordinate(45.7640, 4.8357), Country.FR),
    GeocodeResult("Marseille, France", Coordinate(43.2965, 5.3698), Country.FR),
    GeocodeResult("Bordeaux, France", Coordinate(44.8378, -0.5792), Country.FR),
    GeocodeResult("Toulouse, France", Coordinate(43.6047, 1.4442), Country.FR),
    GeocodeResult("Nice, France", Coordinate(43.7102, 7.2620), Country.FR),
    GeocodeResult("Nantes, France", Coordinate(47.2184, -1.5536), Country.FR),
    GeocodeResult("Strasbourg, France", Coordinate(48.5734, 7.7521), Country.FR),
    GeocodeResult("Lille, France", Coordinate(50.6292, 3.0573), Country.FR),
    # IT
    GeocodeResult("Roma, Italy", Coordinate(41.9028, 12.4964), Country.IT),
    GeocodeResult("Milano, Italy", Coordinate(45.4642, 9.1900), Country.IT),
    GeocodeResult("Napoli, Italy", Coordinate(40.8518, 14.2681), Country.IT),
    GeocodeResult("Torino, Italy", Coordinate(45.0703, 7.6869), Country.IT),
    GeocodeResult("Firenze, Italy", Coordinate(43.7696, 11.2558), Country.IT),
    GeocodeResult("Bologna, Italy", Coordinate(44.4949, 11.3426), Country.IT),
    GeocodeResult("Venezia, Italy", Coordinate(45.4408, 12.3155), Country.IT),
    GeocodeResult("Palermo, Italy", Coordinate(38.1157, 13.3615), Country.IT),
    # ES
    GeocodeResult("Madrid, Spain", Coordinate(40.4168, -3.7038), Country.ES),
    GeocodeResult("Barcelona, Spain", Coordinate(41.3874, 2.1686), Country.ES),
    GeocodeResult("Valencia, Spain", Coordinate(39.4699, -0.3763), Country.ES),
    GeocodeResult("Sevilla, Spain", Coordinate(37.3891, -5.9845), Country.ES),
    GeocodeResult("Bilbao, Spain", Coordinate(43.2630, -2.9350), Country.ES),
    GeocodeResult("Zaragoza, Spain", Coordinate(41.6488, -0.8891), Country.ES),
    GeocodeResult("Málaga, Spain", Coordinate(36.7213, -4.4213), Country.ES),
    GeocodeResult("Palma, Spain", Coordinate(39.5696, 2.6502), Country.ES),
)


class MockGeocodingProvider:
    """In-memory prefix/substring search over a small city catalogue.

    Same query → same results. Comparison is case- and accent-insensitive
    where practical (Python's casefold handles the case part; a real Nominatim
    integration will handle full accent folding).
    """

    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]:
        q = query.strip().casefold()
        if not q:
            return ()
        matches = [r for r in _CATALOGUE if q in r.display_name.casefold()]
        # Prefix matches rank higher than mid-string matches.
        matches.sort(key=lambda r: (0 if r.display_name.casefold().startswith(q) else 1,
                                    r.display_name))
        return tuple(matches[:limit])

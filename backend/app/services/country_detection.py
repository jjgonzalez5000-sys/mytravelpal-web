"""Country detection from geographic coordinates.

MVP heuristic: axis-aligned bounding boxes per launch country. Good enough
for planning routes between well-known cities in CH/FR/IT/ES; a real
implementation will use PostGIS polygons.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

from app.domain import Coordinate, Country


@dataclass(frozen=True, slots=True)
class _BBox:
    min_lat: float
    max_lat: float
    min_lon: float
    max_lon: float

    def contains(self, c: Coordinate) -> bool:
        return (
            self.min_lat <= c.lat <= self.max_lat
            and self.min_lon <= c.lon <= self.max_lon
        )


# Approximate mainland bounding boxes for the four launch countries.
# Overseas territories intentionally out of scope for the MVP.
_BOXES: dict[Country, _BBox] = {
    Country.CH: _BBox(45.82, 47.81, 5.96, 10.49),
    Country.FR: _BBox(41.36, 51.09, -5.14, 9.56),
    Country.IT: _BBox(35.49, 47.09, 6.63, 18.52),
    Country.ES: _BBox(35.95, 43.79, -9.30, 4.32),
}


def detect_country(coord: Coordinate) -> Country | None:
    """Return the launch country containing `coord`, or None if outside all.

    Overlap handling: CH is checked first (smallest, wins over FR/IT border
    overlap); ES before FR (Pyrenees overlap); IT before FR (Alps overlap).
    """
    for country in (Country.CH, Country.ES, Country.IT, Country.FR):
        if _BOXES[country].contains(coord):
            return country
    return None


def infer_countries_crossed(
    points: Iterable[Coordinate],
) -> tuple[Country, ...]:
    """Return the ordered, de-duplicated countries covering `points`.

    In the MVP we only pass origin and destination; a future real routing
    provider will let us pass every polyline vertex.
    """
    seen: list[Country] = []
    for p in points:
        c = detect_country(p)
        if c is not None and c not in seen:
            seen.append(c)
    return tuple(seen)

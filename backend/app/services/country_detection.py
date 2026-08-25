"""Country detection from geographic coordinates.

Uses axis-aligned bounding boxes from [`countries data`](../data/countries.py)
so adding a country doesn't require touching this service. Overlaps are
resolved by a hand-tuned priority order (smaller / more specific
countries win — CH beats FR near Geneva, LU beats DE/BE/FR, etc.).
"""

from __future__ import annotations

from typing import Iterable

from app.data.countries import COUNTRIES, priority_order
from app.domain import Coordinate, Country


def _contains(bbox: tuple[float, float, float, float], c: Coordinate) -> bool:
    return bbox[0] <= c.lat <= bbox[1] and bbox[2] <= c.lon <= bbox[3]


def detect_country(coord: Coordinate) -> Country | None:
    """Return the country whose bounding box contains `coord`.

    Returns None if `coord` falls outside every supported country's
    bounding box.
    """
    for code in priority_order():
        data = COUNTRIES.get(code)
        if data is not None and _contains(data.bbox, coord):
            return Country(code)
    return None


def infer_countries_crossed(
    points: Iterable[Coordinate],
) -> tuple[Country, ...]:
    """Ordered, de-duplicated countries covering `points`."""
    seen: list[Country] = []
    for p in points:
        c = detect_country(p)
        if c is not None and c not in seen:
            seen.append(c)
    return tuple(seen)

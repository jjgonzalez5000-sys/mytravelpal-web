"""Ramer-Douglas-Peucker polyline simplification.

The public OSRM demo returns tens of thousands of geometry points for
long routes. Sending the raw polyline to the client bloats the response
(~800 KB for Paris → Madrid) with no visual gain: at typical map zoom
levels the map can only render a few hundred distinct pixels along the
route anyway. This service reduces the polyline to the minimum number of
points that stay within `epsilon_km` of the original curve.

Not a general-purpose library — tuned for lat/lon geographic data at
country-scale zooms. For very short polylines (city routes) drop
`epsilon_km` accordingly.
"""

from __future__ import annotations

from math import asin, cos, radians, sin, sqrt

from app.domain import Coordinate

_EARTH_RADIUS_KM = 6371.0


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    lat1, lon1, lat2, lon2 = map(radians, (a.lat, a.lon, b.lat, b.lon))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * asin(sqrt(h))


def _perpendicular_km(
    point: Coordinate, start: Coordinate, end: Coordinate,
) -> float:
    """Great-circle perpendicular distance from `point` to the geodesic
    segment start→end. For an MVP we approximate with the flat-plane
    projection in the local tangent; at country scale the error vs true
    great-circle is far below the epsilons we use.
    """
    if start.lat == end.lat and start.lon == end.lon:
        return _haversine_km(point, start)

    # Project everything to a local ENU-ish frame around the segment midpoint.
    mid_lat = radians((start.lat + end.lat) / 2)
    scale_lat = 111.32
    scale_lon = 111.32 * cos(mid_lat)

    def to_xy(c: Coordinate) -> tuple[float, float]:
        return (c.lon * scale_lon, c.lat * scale_lat)

    px, py = to_xy(point)
    sx, sy = to_xy(start)
    ex, ey = to_xy(end)

    dx, dy = ex - sx, ey - sy
    seg_len_sq = dx * dx + dy * dy
    if seg_len_sq == 0:
        return sqrt((px - sx) ** 2 + (py - sy) ** 2)
    # t = clamped projection scalar
    t = max(0.0, min(1.0, ((px - sx) * dx + (py - sy) * dy) / seg_len_sq))
    projx = sx + t * dx
    projy = sy + t * dy
    return sqrt((px - projx) ** 2 + (py - projy) ** 2)


def simplify(
    points: tuple[Coordinate, ...],
    *,
    epsilon_km: float = 0.15,
) -> tuple[Coordinate, ...]:
    """Return a subset of `points` that keeps the polyline shape within
    `epsilon_km` of the original. Endpoints always preserved.
    """
    if len(points) < 3:
        return points

    # Iterative RDP — avoids Python's recursion limit on 17k+ point inputs.
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack: list[tuple[int, int]] = [(0, len(points) - 1)]

    while stack:
        start_idx, end_idx = stack.pop()
        if end_idx - start_idx < 2:
            continue
        max_dist = -1.0
        max_idx = -1
        for i in range(start_idx + 1, end_idx):
            d = _perpendicular_km(points[i], points[start_idx], points[end_idx])
            if d > max_dist:
                max_dist = d
                max_idx = i
        if max_dist > epsilon_km:
            keep[max_idx] = True
            stack.append((start_idx, max_idx))
            stack.append((max_idx, end_idx))

    return tuple(p for i, p in enumerate(points) if keep[i])

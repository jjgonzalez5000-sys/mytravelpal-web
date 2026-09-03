"""Parking provider — finds parking near a coordinate.

Two access patterns supported:
- **Trip-context** (from a plan waypoint): "I'm stopping in Vienna
  for the day, where can I park?"
- **Standalone** (from the home screen): "I'm going to a concert at
  the Palau Sant Jordi, find me parking near it"

Primary source: Geoapify Places API, category `parking`. HERE
Places is a fallback when Geoapify returns nothing (rare — parking
data is well-tagged in OSM which is what Geoapify indexes).

We keep the surface small: one method, `parking_near(coord,
radius_km)`, returns tuple[Parking, ...] sorted by distance
ascending. The caller filters / caps as needed.

Price and covered flags come from OSM tags where available. When
absent (majority of cases outside big-city commercial garages) we
ship `None` and the mobile UI shows a "?" chip.
"""

from __future__ import annotations

import logging
import os
from math import asin, cos, radians, sin, sqrt
from typing import Any, Protocol

import httpx

from app.data.countries import COUNTRIES
from app.domain import Coordinate, Country, Parking

_log = logging.getLogger(__name__)

_ENDPOINT = "https://api.geoapify.com/v2/places"
_TIMEOUT_S = 6.0


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_GEOAPIFY_KEY") or None


class ParkingProvider(Protocol):
    async def parking_near(
        self, coord: Coordinate, radius_km: float,
    ) -> tuple[Parking, ...]: ...


class MockParkingProvider:
    """Returns a small deterministic set of parkings for tests and
    offline mode. Names include the country hint so debug output
    stays legible.
    """
    async def parking_near(
        self, coord: Coordinate, radius_km: float,
    ) -> tuple[Parking, ...]:
        country = _point_country(coord)
        base = country.value if country else "??"
        return tuple(
            Parking(
                name=f"Parking mock {base} #{i+1}",
                coordinate=Coordinate(
                    lat=coord.lat + 0.001 * (i + 1),
                    lon=coord.lon + 0.001 * (i + 1),
                ),
                country=country or Country.ES,
                distance_from_query_km=0.15 * (i + 1),
                price_eur_per_hour=2.0 if i == 0 else None,
                covered=(i % 2 == 0),
                kind="garage" if i % 2 == 0 else "surface",
            )
            for i in range(3)
        )


class GeoapifyParkingProvider:
    """Real parking lookup via Geoapify Places."""

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def parking_near(
        self, coord: Coordinate, radius_km: float,
    ) -> tuple[Parking, ...]:
        key = _api_key()
        if not key:
            return ()
        radius_m = int(max(min(radius_km, 20.0), 0.5) * 1000)
        params = {
            "categories": "parking",
            "filter": f"circle:{coord.lon:.5f},{coord.lat:.5f},{radius_m}",
            "bias": f"proximity:{coord.lon:.5f},{coord.lat:.5f}",
            "limit": "40",
            "apiKey": key,
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("Geoapify parking request failed: %r", exc)
            return ()
        if r.status_code != 200:
            _log.warning(
                "Geoapify parking HTTP %s: %s",
                r.status_code, r.text[:200],
            )
            return ()
        try:
            body = r.json()
        except ValueError:
            return ()
        parkings: list[Parking] = []
        for f in body.get("features") or []:
            p = _feature_to_parking(f, coord)
            if p is not None:
                parkings.append(p)
        parkings.sort(key=lambda x: x.distance_from_query_km)
        return tuple(parkings)


# -------- helpers ---------------------------------------------------


def _feature_to_parking(
    feature: dict[str, Any], query: Coordinate,
) -> Parking | None:
    props = feature.get("properties") or {}
    lat = props.get("lat")
    lon = props.get("lon")
    if lat is None or lon is None:
        return None
    try:
        coord = Coordinate(lat=float(lat), lon=float(lon))
    except (TypeError, ValueError):
        return None
    name = (
        props.get("name")
        or props.get("address_line1")
        or _kind_label(_parse_kind(props))
    )
    country = _point_country(coord)
    tags = _raw_tags(feature)
    price = _parse_fee(tags)
    covered = _parse_covered(tags)
    max_stay = _parse_max_stay(tags)
    capacity = _parse_int(tags.get("capacity"))
    kind = _parse_kind(props, tags)
    attrs: list[tuple[str, str]] = []
    for k in (
        "access", "fee", "opening_hours", "wheelchair", "supervised",
        "phone", "website", "park_ride",
    ):
        v = tags.get(k)
        if v:
            attrs.append((k, str(v)))
    return Parking(
        name=str(name).strip() or "Parking",
        coordinate=coord,
        country=country or Country.ES,
        distance_from_query_km=_haversine_km(query, coord),
        price_eur_per_hour=price,
        max_stay_hours=max_stay,
        covered=covered,
        capacity=capacity,
        kind=kind,
        kid_friendly=_parse_kid_friendly(tags),
        dogs_allowed=_parse_bool_tag(tags, "dog"),
        toilets=_parse_bool_tag(tags, "toilets"),
        showers=_parse_bool_tag(tags, "shower"),
        food_nearby=_parse_bool_tag(tags, "restaurant") or
                    _parse_bool_tag(tags, "vending"),
        ev_charging=_parse_bool_tag(tags, "charging_station"),
        fuel_station=_parse_bool_tag(tags, "fuel"),
        wheelchair_access=_parse_bool_tag(tags, "wheelchair"),
        supervised=_parse_bool_tag(tags, "supervised"),
        rv_friendly=_parse_rv_friendly(tags),
        truck_friendly=_parse_bool_tag(tags, "hgv"),
        park_and_ride=str(tags.get("park_ride") or "").lower()
                      in ("yes", "bus", "train", "tram", "metro"),
        attributes=tuple(attrs),
    )


def _parse_bool_tag(tags: dict[str, Any], key: str) -> bool | None:
    """Tri-state parse for OSM yes/no tags."""
    v = tags.get(key)
    if v is None:
        return None
    s = str(v).lower()
    if s in ("yes", "true", "1", "designated"):
        return True
    if s in ("no", "false", "0"):
        return False
    return None


def _parse_kid_friendly(tags: dict[str, Any]) -> bool | None:
    """Kid-friendly signal from multiple OSM tags. True if any of
    playground, kids_area, family or child_care is set to yes.
    """
    for k in ("playground", "kids_area", "family", "child_care"):
        if _parse_bool_tag(tags, k) is True:
            return True
    return None


def _parse_rv_friendly(tags: dict[str, Any]) -> bool | None:
    """RV / motorhome / campervan friendly."""
    for k in ("motorhome", "campervan_site", "caravan"):
        if _parse_bool_tag(tags, k) is True:
            return True
    # OSM's `motor_vehicle` can carry a comma-separated list
    mv = str(tags.get("motor_vehicle") or "").lower()
    if "motorhome" in mv or "campervan" in mv:
        return True
    return None


def _raw_tags(feature: dict[str, Any]) -> dict[str, Any]:
    props = feature.get("properties") or {}
    datasource = props.get("datasource") or {}
    return datasource.get("raw") or {}


def _parse_fee(tags: dict[str, Any]) -> float | None:
    """Best-effort €/h. OSM `fee` is boolean; `charge` may carry a
    formatted string like `2 EUR/hour` — we sniff EUR + digits.
    """
    raw = tags.get("charge") or tags.get("fee:conditional")
    if not raw:
        return None
    s = str(raw).lower()
    if "eur" not in s and "€" not in s:
        return None
    digits = "".join(
        ch for ch in s.split("/")[0] if ch.isdigit() or ch == "."
    )
    try:
        return round(float(digits), 2) if digits else None
    except ValueError:
        return None


def _parse_covered(tags: dict[str, Any]) -> bool | None:
    v = tags.get("covered")
    if v is None:
        # `parking` = underground / multi-storey / rooftop / etc.
        parking_type = tags.get("parking")
        if parking_type in ("underground", "multi-storey"):
            return True
        if parking_type == "surface":
            return False
        return None
    return str(v).lower() in ("yes", "true", "1")


def _parse_max_stay(tags: dict[str, Any]) -> float | None:
    v = tags.get("maxstay")
    if not v:
        return None
    s = str(v).lower()
    try:
        if "hour" in s or "h" in s:
            digits = "".join(ch for ch in s if ch.isdigit() or ch == ".")
            return float(digits) if digits else None
    except ValueError:
        pass
    return None


def _parse_int(v: Any) -> int | None:
    if v is None:
        return None
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return None


def _parse_kind(
    props: dict[str, Any], tags: dict[str, Any] | None = None,
) -> str:
    tags = tags or _raw_tags({"properties": props})
    parking = str(tags.get("parking") or "").lower()
    if parking in ("underground", "multi-storey"):
        return "garage"
    if str(tags.get("park_ride") or "").lower() in ("yes", "bus", "train"):
        return "park_and_ride"
    return "surface"


def _kind_label(kind: str) -> str:
    return {
        "garage": "Underground parking",
        "park_and_ride": "Park & ride",
        "surface": "Parking",
    }.get(kind, "Parking")


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    lat1, lon1, lat2, lon2 = map(
        radians, (a.lat, a.lon, b.lat, b.lon),
    )
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * 6371.0 * asin(sqrt(h))


def _point_country(coord: Coordinate) -> Country | None:
    """Rough bounding-box match against the same country table the
    rest of the app uses. Good enough for tagging — precision at
    borders isn't critical here.
    """
    for code, data in COUNTRIES.items():
        bbox = getattr(data, "bbox", None)
        if bbox is None:
            continue
        min_lat, min_lon, max_lat, max_lon = bbox
        if min_lat <= coord.lat <= max_lat and min_lon <= coord.lon <= max_lon:
            try:
                return Country(code)
            except ValueError:
                return None
    return None

"""Geoapify Places API providers for hotels + restaurants (+ fuel).

Drop-in replacement for the Nominatim POI providers when
`MYTRAVELPAL_GEOAPIFY_KEY` is set. The Nominatim demo server started
banning our Fly IP under normal load; Geoapify's free tier is
3 000 requests/day (5 req/s) which comfortably covers a beta cohort
without the ban-hammer risk. The interface (`hotels_along`,
`restaurants_along`, `hotels_near`, `restaurants_near`) matches
Nominatim exactly so the factory can swap providers with zero
changes anywhere else.

Endpoint used:
- `GET https://api.geoapify.com/v2/places` with:
  - `categories=…` (comma-separated Geoapify category slugs)
  - `filter=rect:west,north,east,south` for corridor chunks
  - `filter=circle:lon,lat,radius_m` for point-radius densification
  - `limit=40` (matches the Nominatim knob)
  - `apiKey=…`

Response shape: GeoJSON FeatureCollection where each feature has
`properties.name`, `properties.lat`, `properties.lon`, plus optional
`stars`, `wheelchair`, `datasource.raw.*` for extended tags.
"""

from __future__ import annotations

import logging
import os
from typing import Any

import httpx

from app.data.countries import COUNTRIES
from app.domain import (
    Coordinate,
    Country,
    Hotel,
    PriceBand,
    Restaurant,
    Route,
)
from app.providers.fuel import FuelPrice
from app.providers.nominatim_poi import (
    _AVG_DETOUR_SPEED_KMH,
    _MAX_OFF_CORRIDOR_KM,
    _corridor_viewboxes,
    _distance_to_points,
    _haversine_km,
    _route_reference_points,
    _route_viewbox,
)
from app.providers.restaurants import _classify_meal_price

_log = logging.getLogger(__name__)

_URL = "https://api.geoapify.com/v2/places"
_TIMEOUT_S = 12.0
_LIMIT = 40
_USER_AGENT = "MyTravelPal/1.0 (+https://mytravelpal.app)"


def _api_key() -> str | None:
    return os.environ.get("MYTRAVELPAL_GEOAPIFY_KEY") or None


def _new_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=_TIMEOUT_S,
        headers={
            "User-Agent": _USER_AGENT,
            "Accept": "application/json",
        },
    )


def _rect_filter(vb: tuple[float, float, float, float]) -> str:
    # Nominatim's viewbox tuple is (west, north, east, south);
    # Geoapify rect wants "lon1,lat1,lon2,lat2" as
    # (west, south, east, north). Reorder to match.
    west, north, east, south = vb
    return f"rect:{west},{south},{east},{north}"


def _circle_filter(point: Coordinate, radius_km: float) -> str:
    return f"circle:{point.lon},{point.lat},{int(radius_km * 1000)}"


async def _search(
    client: httpx.AsyncClient,
    categories: str,
    filter_: str,
    key: str,
    *,
    limit: int = _LIMIT,
    conditions: str | None = None,
) -> list[dict[str, Any]]:
    """One Geoapify Places call. Returns the raw feature list;
    caller normalises to domain models. Never raises on HTTP
    error — logs and returns [] so a single failed chunk doesn't
    kill the whole plan.
    """
    params = {
        "categories": categories,
        "filter": filter_,
        "limit": str(limit),
        "apiKey": key,
    }
    if conditions:
        params["conditions"] = conditions
    try:
        response = await client.get(_URL, params=params)
    except httpx.HTTPError as exc:
        _log.warning("Geoapify %s failed: %r", categories, exc)
        return []
    if response.status_code >= 400:
        _log.warning(
            "Geoapify %s HTTP %d: %s",
            categories, response.status_code, response.text[:200],
        )
        return []
    try:
        body = response.json()
    except ValueError:
        return []
    features = list(body.get("features") or [])
    _log.info(
        "Geoapify %s filter=%s → %d features",
        categories, filter_[:60], len(features),
    )
    return features


def _coord(feature: dict[str, Any]) -> Coordinate | None:
    props = feature.get("properties") or {}
    lat = props.get("lat")
    lon = props.get("lon")
    if lat is None or lon is None:
        geom = feature.get("geometry") or {}
        coords = geom.get("coordinates")
        if isinstance(coords, (list, tuple)) and len(coords) >= 2:
            lon, lat = float(coords[0]), float(coords[1])
    if lat is None or lon is None:
        return None
    try:
        return Coordinate(lat=float(lat), lon=float(lon))
    except (TypeError, ValueError):
        return None


def _name(feature: dict[str, Any]) -> str:
    props = feature.get("properties") or {}
    name = props.get("name")
    if name:
        return str(name)
    line = props.get("address_line1") or props.get("formatted") or ""
    return str(line).split(",", 1)[0].strip() or "Unnamed"


def _raw_tags(feature: dict[str, Any]) -> dict[str, Any]:
    """Geoapify tucks OSM tags into `properties.datasource.raw` when
    available. Fall back to `properties` itself so we don't lose
    top-level fields like `stars`, `phone`, `website`.
    """
    props = feature.get("properties") or {}
    ds = props.get("datasource") or {}
    raw = ds.get("raw") if isinstance(ds, dict) else None
    return raw if isinstance(raw, dict) else props


def _tag(feature: dict[str, Any], *keys: str) -> str | None:
    tags = _raw_tags(feature)
    for k in keys:
        v = tags.get(k)
        if v not in (None, ""):
            return str(v)
    return None


def _yes(v: str | None) -> bool:
    return (v or "").lower() in {"yes", "designated", "true", "1"}


def _try_int(v: str | None) -> int | None:
    try:
        return int(str(v)) if v is not None else None
    except (TypeError, ValueError):
        return None


def _country_of(coord: Coordinate, route: Route) -> Country:
    from app.services.country_detection import detect_country
    return detect_country(coord) or (
        route.countries_crossed[0] if route.countries_crossed else Country.FR
    )


def _point_country(coord: Coordinate) -> Country:
    from app.services.country_detection import detect_country
    return detect_country(coord) or Country.FR


# Places whose OSM tags say "hostel" (or the price-conscious
# equivalents) still sometimes carry the `accommodation.hotel`
# Geoapify category — Geoapify normalises loosely. We drop them
# so a `min_stars=4` search never surfaces a hostel by mistake.
_HOSTEL_TOURISM_TAGS = frozenset(
    {"hostel", "chalet", "camp_site", "caravan_site"},
)


def _is_hostel_like(feature: dict[str, Any]) -> bool:
    tags = _raw_tags(feature)
    tourism = str(tags.get("tourism") or "").lower()
    if tourism in _HOSTEL_TOURISM_TAGS:
        return True
    # Category list is the Geoapify-canonical taxonomy — check
    # for hostel/camping/chalet slugs there too in case `tourism`
    # was stripped.
    cats = (feature.get("properties") or {}).get("categories") or []
    for c in cats:
        s = str(c).lower()
        if "hostel" in s or "camp" in s or "chalet" in s:
            return True
    # Some hostel chains embed the word in the name — cheap catch
    # for edge cases where the OSM tag was omitted.
    name = str(feature.get("properties", {}).get("name") or "").lower()
    if "hostel" in name or "youth hotel" in name:
        return True
    return False


class GeoapifyHotelsProvider:
    _CATEGORY_HOTEL_ONLY = "accommodation.hotel"
    _CATEGORY_ALL = (
        "accommodation.hotel,"
        "accommodation.guest_house,"
        "accommodation.motel,"
        "accommodation.apartment"
    )

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def hotels_along(
        self,
        route: Route,
        *,
        include_other: bool = False,
        conditions: str | None = None,
    ) -> tuple[Hotel, ...]:
        key = _api_key()
        if not key:
            return ()
        cat = self._CATEGORY_ALL if include_other else self._CATEGORY_HOTEL_ONLY
        boxes = _corridor_viewboxes(route)
        reference = _route_reference_points(route)
        features: list[dict[str, Any]] = []
        for vb in boxes:
            features.extend(await _search(
                self._client, cat, _rect_filter(vb), key,
                conditions=conditions,
            ))
        return tuple(self._hotels_from(features, route, reference))

    async def hotels_near(
        self, point: Coordinate, radius_km: float = 40.0,
        *, include_other: bool = False, conditions: str | None = None,
    ) -> tuple[Hotel, ...]:
        key = _api_key()
        if not key:
            return ()
        cat = self._CATEGORY_ALL if include_other else self._CATEGORY_HOTEL_ONLY
        features = await _search(
            self._client, cat,
            _circle_filter(point, max(radius_km, 5.0)), key,
            conditions=conditions,
        )
        hotels: list[Hotel] = []
        for f in features:
            if _is_hostel_like(f):
                continue
            coord = _coord(f)
            if coord is None:
                continue
            distance_km = _haversine_km(point, coord)
            if distance_km > radius_km:
                continue
            hotels.append(
                self._hotel_from(f, coord, distance_km, _point_country(coord)),
            )
        hotels.sort(key=lambda h: _haversine_km(point, h.coordinate))
        return tuple(hotels)

    def _hotels_from(
        self,
        features: list[dict[str, Any]],
        route: Route,
        reference: tuple[Coordinate, ...],
    ) -> list[Hotel]:
        hotels: list[Hotel] = []
        seen: set[tuple[float, float, str]] = set()
        for f in features:
            if _is_hostel_like(f):
                continue
            coord = _coord(f)
            if coord is None:
                continue
            key = (round(coord.lat, 4), round(coord.lon, 4), _name(f))
            if key in seen:
                continue
            seen.add(key)
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            hotels.append(
                self._hotel_from(
                    f, coord, distance_km, _country_of(coord, route),
                ),
            )
        hotels.sort(key=lambda h: h.detour_minutes)
        return hotels

    def _hotel_from(
        self,
        feature: dict[str, Any],
        coord: Coordinate,
        distance_km: float,
        country: Country,
    ) -> Hotel:
        detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
        stars = _try_int(_tag(feature, "stars"))
        anchor = COUNTRIES.get(country.value)
        base = anchor.hotel_anchor_eur if anchor else 120.0
        price = round(base * (1 + ((stars or 3) - 3) * 0.3), 2)
        raw = _raw_tags(feature)
        attrs = tuple(
            (k, str(v))
            for k, v in raw.items()
            if v not in (None, "") and isinstance(v, (str, int, float, bool))
        )[:12]
        return Hotel(
            name=_name(feature),
            coordinate=coord,
            country=country,
            price_eur_per_night=price,
            price_band=PriceBand.from_price_eur(price),
            distance_from_route_km=round(distance_km, 2),
            detour_minutes=round(detour_minutes, 1),
            kid_friendly=_yes(_tag(feature, "family_friendly")),
            pet_friendly=(
                _yes(_tag(feature, "dog")) or _yes(_tag(feature, "pets"))
            ),
            has_parking=_tag(feature, "parking") not in (None, "no"),
            attributes=attrs,
        )


class GeoapifyRestaurantsProvider:
    # Parent category `catering` covers restaurant + cafe + fast_food
    # + bar + pub + biergarten + ice_cream + everything else under
    # the Geoapify catering tree. Using the parent instead of the
    # three specific subcategories catches Alpine/rural eateries
    # tagged as biergarten or bar that serve food — testers hit
    # empty restaurant pools on mountain routes with narrow
    # subcategory matches.
    _CATEGORIES = "catering"

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def restaurants_along(
        self, route: Route, *, conditions: str | None = None,
    ) -> tuple[Restaurant, ...]:
        key = _api_key()
        if not key:
            return ()
        boxes = _corridor_viewboxes(route)
        reference = _route_reference_points(route)
        features: list[dict[str, Any]] = []
        for vb in boxes:
            features.extend(await _search(
                self._client, self._CATEGORIES, _rect_filter(vb), key,
                conditions=conditions,
            ))
        result = tuple(self._restaurants_from(features, route, reference))
        _log.info(
            "restaurants_along: %d raw features → %d after corridor filter",
            len(features), len(result),
        )
        return result

    async def restaurants_near(
        self, point: Coordinate, radius_km: float = 25.0,
        *, conditions: str | None = None,
    ) -> tuple[Restaurant, ...]:
        key = _api_key()
        if not key:
            return ()
        features = await _search(
            self._client, self._CATEGORIES,
            _circle_filter(point, max(radius_km, 5.0)), key,
            conditions=conditions,
        )
        rows: list[Restaurant] = []
        for f in features:
            coord = _coord(f)
            if coord is None:
                continue
            distance_km = _haversine_km(point, coord)
            if distance_km > radius_km:
                continue
            rows.append(
                self._restaurant_from(
                    f, coord, distance_km, _point_country(coord),
                ),
            )
        rows.sort(key=lambda r: _haversine_km(point, r.coordinate))
        return tuple(rows)

    def _restaurants_from(
        self,
        features: list[dict[str, Any]],
        route: Route,
        reference: tuple[Coordinate, ...],
    ) -> list[Restaurant]:
        rows: list[Restaurant] = []
        seen: set[tuple[float, float, str]] = set()
        for f in features:
            coord = _coord(f)
            if coord is None:
                continue
            key = (round(coord.lat, 4), round(coord.lon, 4), _name(f))
            if key in seen:
                continue
            seen.add(key)
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            rows.append(
                self._restaurant_from(
                    f, coord, distance_km, _country_of(coord, route),
                ),
            )
        rows.sort(key=lambda r: r.detour_minutes)
        if not rows:
            _log.warning(
                "Geoapify restaurants_from: %d features → 0 after corridor "
                "filter (MAX_OFF_CORRIDOR_KM=%s)",
                len(features), _MAX_OFF_CORRIDOR_KM,
            )
        return rows

    def _restaurant_from(
        self,
        feature: dict[str, Any],
        coord: Coordinate,
        distance_km: float,
        country: Country,
    ) -> Restaurant:
        detour_minutes = (distance_km * 2) / _AVG_DETOUR_SPEED_KMH * 60.0
        anchor = COUNTRIES.get(country.value)
        base = anchor.restaurant_anchor_eur if anchor else 25.0
        cats = (feature.get("properties") or {}).get("categories") or []
        if any("fast_food" in c for c in cats):
            price = base * 0.5
        elif any(c in ("catering.cafe",) for c in cats):
            price = base * 0.7
        else:
            price = base
        raw = _raw_tags(feature)
        attrs = tuple(
            (k, str(v))
            for k, v in raw.items()
            if v not in (None, "") and isinstance(v, (str, int, float, bool))
        )[:12]
        return Restaurant(
            name=_name(feature),
            coordinate=coord,
            country=country,
            price_eur_per_meal=round(price, 2),
            price_band=_classify_meal_price(price),
            distance_from_route_km=round(distance_km, 2),
            detour_minutes=round(detour_minutes, 1),
            kid_friendly=_yes(_tag(feature, "family_friendly")),
            pet_friendly=_yes(_tag(feature, "dog")),
            attributes=attrs,
        )


class GeoapifyFuelProvider:
    _CATEGORY = "service.vehicle.fuel"
    _CATEGORY_CHARGING = "service.vehicle.charging_station"
    # Public fast-charger average €/kWh across EU as of 2026. Serves
    # as the mock price when we don't have live tariff data — we
    # want the driver to see comparable numbers next to their fuel
    # budget without misleading precision.
    _CHARGING_EUR_PER_KWH = 0.42

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        key = _api_key()
        if not key:
            return ()
        vb = _route_viewbox(route)
        reference = _route_reference_points(route)
        is_ev = (fuel_type or "").lower() == "electric"
        category = self._CATEGORY_CHARGING if is_ev else self._CATEGORY
        features = await _search(
            self._client, category, _rect_filter(vb), key,
        )
        prices: list[FuelPrice] = []
        for f in features:
            coord = _coord(f)
            if coord is None:
                continue
            distance_km = _distance_to_points(coord, reference)
            if distance_km > _MAX_OFF_CORRIDOR_KM:
                continue
            country = _country_of(coord, route)
            anchor = COUNTRIES.get(country.value)
            if is_ev:
                base = self._CHARGING_EUR_PER_KWH
            else:
                base = anchor.fuel_petrol_anchor_eur if anchor else 1.75
            prices.append(
                FuelPrice(
                    station_name=_tag(f, "brand") or _name(f),
                    country=country,
                    price_eur_per_l=round(base, 3),
                    unit_label="€/kWh" if is_ev else "€/L",
                    is_charging_station=is_ev,
                    distance_from_origin_km=round(
                        _haversine_km(route.origin, coord), 1,
                    ),
                    coordinate=coord,
                    attributes=tuple(
                        (k, str(v))
                        for k, v in (_raw_tags(f) or {}).items()
                        if v not in (None, "")
                        and isinstance(v, (str, int, float, bool))
                    )[:12],
                )
            )
        prices.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(prices[:20])

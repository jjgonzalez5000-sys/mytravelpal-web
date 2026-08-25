from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from typing import Protocol

import httpx

from app.data.countries import COUNTRIES, all_nominatim_codes
from app.domain import Coordinate, Country

_log = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class GeocodeResult:
    display_name: str
    coordinate: Coordinate
    country: Country
    poi_class: str | None = None
    """OSM top-level class: `tourism`, `amenity`, `shop`, `natural`,
    `historic`, `place`, `leisure`, `railway`, `aeroway`, `office`,
    `building`, `highway`, `landuse`, `boundary`, `waterway`, `man_made`,
    `emergency`, `sport`, `craft`, `military`, `power`, `barrier`.
    None for mock catalogue entries (they're just cities).
    """
    poi_type: str | None = None
    """OSM subtype for the class. Examples:
    `amenity=restaurant`, `tourism=museum`, `shop=bakery`,
    `natural=peak`, `place=city`. See `mobile/lib/widgets/poi_icons.dart`
    for the full mapping the client uses to pick an icon.
    """


class GeocodingProvider(Protocol):
    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]: ...

    async def reverse(
        self, lat: float, lon: float,
    ) -> GeocodeResult | None:
        """Look up the human-readable place at `lat`,`lon`.

        Returns None when no populated place is close enough (open sea,
        remote wilderness) or when the provider can't answer (network
        error). Callers should always be prepared for None.
        """
        ...


# City catalogue built from `data.countries`. Anything not covered by
# the catalogue falls through to the Nominatim provider (via
# `HybridGeocodingProvider`), so small towns still work.
_CATALOGUE: tuple[GeocodeResult, ...] = tuple(
    GeocodeResult(
        display_name=name,
        coordinate=Coordinate(lat=lat, lon=lon),
        country=Country(data.code),
    )
    for data in COUNTRIES.values()
    for (name, lat, lon) in data.sample_cities
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

    async def reverse(
        self, lat: float, lon: float,
    ) -> GeocodeResult | None:
        # Mock returns the catalogue city closest to (lat, lon) if any is
        # within ~50 km — enough for demos, not for reality.
        best: GeocodeResult | None = None
        best_km = 50.0
        for entry in _CATALOGUE:
            dx = (entry.coordinate.lat - lat) * 111.0
            dy = (entry.coordinate.lon - lon) * 111.0 * max(0.1,
                (1 - abs(entry.coordinate.lat) / 90.0))
            km = (dx * dx + dy * dy) ** 0.5
            if km < best_km:
                best_km = km
                best = entry
        return best


class NominatimGeocodingProvider:
    """Real OpenStreetMap Nominatim geocoder.

    Free public service, covers every populated place worldwide. Rate
    limited to ~1 req/s; requires a descriptive User-Agent. Suitable for
    MVP scale (single-user demos with debounced typing on the client);
    switch to a self-hosted instance or a paid geocoder before scaling.
    """

    _URL = "https://nominatim.openstreetmap.org/search"
    _REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"
    _USER_AGENT = "MyTravelPal-dev/0.1 (contact@mytravelpal.example)"
    _COUNTRY_CODES = all_nominatim_codes()

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=5.0)

    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]:
        q = query.strip()
        if not q:
            return ()
        params = {
            "q": q,
            "format": "json",
            "limit": str(limit),
            "addressdetails": "1",
            "countrycodes": self._COUNTRY_CODES,
        }
        try:
            response = await self._client.get(
                self._URL,
                params=params,
                headers={
                    "User-Agent": self._USER_AGENT,
                    "Accept-Language": "en",
                },
            )
            response.raise_for_status()
        except httpx.HTTPError as exc:
            _log.warning("Nominatim request failed: %s", exc)
            return ()

        results: list[GeocodeResult] = []
        for item in response.json():
            address = item.get("address") or {}
            code = (address.get("country_code") or "").upper()
            try:
                country = Country(code)
            except ValueError:
                continue  # outside launch markets
            try:
                lat = float(item["lat"])
                lon = float(item["lon"])
            except (KeyError, ValueError):
                continue
            display = item.get("display_name") or ""
            if not display:
                continue
            poi_class = item.get("class") or None
            poi_type = item.get("type") or None
            results.append(
                GeocodeResult(
                    display_name=display,
                    coordinate=Coordinate(lat=lat, lon=lon),
                    country=country,
                    poi_class=poi_class,
                    poi_type=poi_type,
                )
            )
        return tuple(results)


    async def reverse(
        self, lat: float, lon: float,
    ) -> GeocodeResult | None:
        params = {
            "lat": f"{lat:.6f}",
            "lon": f"{lon:.6f}",
            "format": "json",
            "addressdetails": "1",
            "zoom": "12",  # town / suburb level — meaningful place labels
        }
        try:
            response = await self._client.get(
                self._REVERSE_URL, params=params,
                headers={
                    "User-Agent": self._USER_AGENT,
                    "Accept-Language": "en",
                },
            )
            response.raise_for_status()
        except httpx.HTTPError as exc:
            _log.warning("Nominatim reverse request failed: %s", exc)
            return None
        try:
            item = response.json()
        except ValueError:
            return None
        if not isinstance(item, dict) or "lat" not in item:
            return None
        address = item.get("address") or {}
        try:
            country = Country((address.get("country_code") or "").upper())
        except ValueError:
            return None
        try:
            r_lat = float(item["lat"])
            r_lon = float(item["lon"])
        except (KeyError, ValueError):
            return None
        display = (
            item.get("display_name")
            or f"{address.get('city') or address.get('town') or 'Unknown'}, "
            f"{country.value}"
        )
        return GeocodeResult(
            display_name=display,
            coordinate=Coordinate(lat=r_lat, lon=r_lon),
            country=country,
            poi_class=item.get("class") or None,
            poi_type=item.get("type") or None,
        )


class HybridGeocodingProvider:
    """Merges results from `primary` and `secondary`.

    For queries of 2 characters (city-prefix typing) we only hit the mock
    catalogue — cheap, deterministic, no external call. For longer queries
    (users looking for a specific place — a small town, a POI like the
    Musée du Louvre) we run both providers concurrently and merge the
    results, primary first, deduped by display name.

    Why: the mock catalogue only knows city centres. Searching for
    "louvre" or "colegio X" would return no mock hit and, under the old
    "primary-first-falls-through-if-empty" strategy, would defer to
    Nominatim only if the mock returned zero. With the merged strategy,
    even ambiguous queries like "lo" that hit a couple of mock cities
    still surface Nominatim's POI matches below.
    """

    _NOMINATIM_MIN_CHARS = 3

    def __init__(
        self,
        primary: GeocodingProvider,
        fallback: GeocodingProvider,
    ) -> None:
        self._primary = primary
        self._fallback = fallback

    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]:
        q = query.strip()
        if len(q) < self._NOMINATIM_MIN_CHARS:
            return await self._primary.search(q, limit=limit)
        primary_task = asyncio.create_task(self._primary.search(q, limit=limit))
        fallback_task = asyncio.create_task(self._fallback.search(q, limit=limit))
        primary, fallback = await asyncio.gather(
            primary_task, fallback_task, return_exceptions=True,
        )
        merged: list[GeocodeResult] = []
        seen: set[str] = set()
        for source in (primary, fallback):
            if isinstance(source, BaseException):
                _log.warning("geocoding provider failed: %s", source)
                continue
            for r in source:
                key = r.display_name.casefold()
                if key in seen:
                    continue
                seen.add(key)
                merged.append(r)
                if len(merged) >= limit:
                    return tuple(merged)
        return tuple(merged)

    async def reverse(
        self, lat: float, lon: float,
    ) -> GeocodeResult | None:
        result = await self._primary.reverse(lat, lon)
        if result is not None:
            return result
        return await self._fallback.reverse(lat, lon)

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
    async def search(
        self, query: str, *, limit: int = 5, lang: str | None = None,
    ) -> tuple[GeocodeResult, ...]: ...

    async def reverse(
        self, lat: float, lon: float, *, lang: str | None = None,
    ) -> GeocodeResult | None:
        """Look up the human-readable place at `lat`,`lon`.

        Returns None when no populated place is close enough (open sea,
        remote wilderness) or when the provider can't answer (network
        error). Callers should always be prepared for None.

        `lang` is a two-letter ISO 639-1 code that upstream geocoders
        use to localise `display_name` (Nominatim honours it via
        `Accept-Language`). None means default to English so existing
        callers don't break.
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

    async def search(
        self, query: str, *, limit: int = 5, lang: str | None = None,
    ) -> tuple[GeocodeResult, ...]:
        # `lang` is ignored: the catalogue only stores canonical
        # English city names and re-translating them would drift.
        # Nominatim (fallback) will provide localised names for
        # anything not in the hardcoded list.
        del lang
        q = query.strip().casefold()
        if not q:
            return ()
        matches = [r for r in _CATALOGUE if q in r.display_name.casefold()]
        # Prefix matches rank higher than mid-string matches.
        matches.sort(key=lambda r: (0 if r.display_name.casefold().startswith(q) else 1,
                                    r.display_name))
        return tuple(matches[:limit])

    async def reverse(
        self, lat: float, lon: float, *, lang: str | None = None,
    ) -> GeocodeResult | None:
        del lang
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

    async def search(
        self, query: str, *, limit: int = 5, lang: str | None = None,
    ) -> tuple[GeocodeResult, ...]:
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
                    "Accept-Language": _accept_language(lang),
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
        self, lat: float, lon: float, *, lang: str | None = None,
    ) -> GeocodeResult | None:
        params = {
            "lat": f"{lat:.6f}",
            "lon": f"{lon:.6f}",
            "format": "json",
            "addressdetails": "1",
            # Building-level precision (was 12 = town). Testers
            # reported "usar mi ubicación" only returned the
            # town name when they expected the actual street +
            # number. zoom=18 is Nominatim's finest granularity
            # and its display_name then reads e.g.
            # "12, Rathausgasse, Unterägeri, 6314, Zug, Suisse".
            "zoom": "18",
        }
        try:
            response = await self._client.get(
                self._REVERSE_URL, params=params,
                headers={
                    "User-Agent": self._USER_AGENT,
                    "Accept-Language": _accept_language(lang),
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
        # Build a compact display that reads "Road N, City" so the
        # mobile client's `.split(",").first` shows the street (not
        # just the house number, which is what Nominatim's raw
        # `display_name` returns as the first segment). Falls back
        # to the raw display when we don't have enough parts, and
        # to city+country when even that's missing.
        road = address.get("road")
        housenumber = address.get("house_number")
        city = (
            address.get("city")
            or address.get("town")
            or address.get("village")
            or address.get("suburb")
            or address.get("municipality")
        )
        if road and housenumber and city:
            display = f"{road} {housenumber}, {city}"
        elif road and city:
            display = f"{road}, {city}"
        else:
            display = (
                item.get("display_name")
                or f"{city or 'Unknown'}, {country.value}"
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

    async def search(
        self, query: str, *, limit: int = 5, lang: str | None = None,
    ) -> tuple[GeocodeResult, ...]:
        q = query.strip()
        if len(q) < self._NOMINATIM_MIN_CHARS:
            return await self._primary.search(q, limit=limit, lang=lang)
        primary_task = asyncio.create_task(
            self._primary.search(q, limit=limit, lang=lang),
        )
        fallback_task = asyncio.create_task(
            self._fallback.search(q, limit=limit, lang=lang),
        )
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
        self, lat: float, lon: float, *, lang: str | None = None,
    ) -> GeocodeResult | None:
        # For reverse geocoding, prefer the *fallback* (Nominatim)
        # because it returns the actual town/village at the GPS
        # coordinate, while the mock catalogue snaps to the nearest
        # big city in its hardcoded list — Unterägeri and Rotkreuz
        # both returned "Zürich" because it's within 50 km. Only
        # fall back to the catalogue when Nominatim is down or the
        # coord lands outside the supported country set.
        result = await self._fallback.reverse(lat, lon, lang=lang)
        if result is not None:
            return result
        return await self._primary.reverse(lat, lon, lang=lang)


# Two-letter ISO 639-1 codes we're willing to forward as-is to
# Nominatim's Accept-Language header. Guarded because upstream is a
# free public service and we don't want to become the ingress that
# lets a caller inject arbitrary header values.
_SUPPORTED_LANGS: frozenset[str] = frozenset({
    "en", "es", "fr", "de", "it", "pt", "ca", "eu", "gl",
    "nl", "pl", "cs", "sk", "sl", "hr", "sv", "no", "da",
    "fi", "el", "hu", "ro", "bg", "et", "lv", "lt", "ga", "mt",
})


def _accept_language(lang: str | None) -> str:
    """Return a safe Accept-Language header value.

    Defaults to `en` when no locale was requested. Unknown or
    non-ISO-639-1-looking codes fall back to `en` too — Nominatim
    silently ignores garbage but we want deterministic behaviour on
    our end. When the caller passes a locale-region form ("es-ES",
    "pt_BR"), we peel the region: Nominatim only keys on the
    language part.
    """
    if not lang:
        return "en"
    code = lang.strip().lower().replace("_", "-").split("-", 1)[0]
    if code in _SUPPORTED_LANGS:
        # Include `en` as a secondary preference so a place with no
        # translation in the primary language still returns a name
        # rather than blank.
        if code == "en":
            return "en"
        return f"{code},en;q=0.5"
    return "en"

"""HERE Fuel Prices provider — pan-European real prices via HERE.

Rationale: `GovFuelProvider` covers ES/FR/IT via free national feeds.
Everything else (DE, PT, BE, NL, AT, CH, PL, GR, Balkans, Nordics)
falls to the `NominatimFuelProvider` today, which returns
`price_available=False` — stations show but with no price to compare.

Two providers are exposed:

`HereFuelPricesProvider` — calls `fuel.hereapi.com/v3/stations`
  which returns actual pump prices per station. Preferred; tried first.
  Authenticates via OAuth 2.0 Bearer token (MYTRAVELPAL_HERE_APP_ID +
  MYTRAVELPAL_HERE_API_KEY) or plain apiKey when APP_ID is absent.

`HereFuelProvider` — calls `browse.search.hereapi.com/v1/browse`
  (HERE Places), which returns station locations. Falls back when the
  Fuel Prices endpoint returns nothing (new country rollout, quota).

HERE Fuel Prices covers 30+ European countries commercially, is
freemium (250 k requests/month across the platform), and gives real
€/L per station keyed by station id + brand. We call it for every
route corridor sample point covering countries the gov feeds do NOT
handle, so we don't burn quota on ES/FR/IT where we already have
open data.

Key acquisition: register at platform.here.com; the REST API key
lives in Fly secrets as `MYTRAVELPAL_HERE_API_KEY`. When the
environment variable is missing both providers return `()` — safe
for local dev without credentials.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any

import httpx

from app.domain import Coordinate, Country, Route
from app.services.country_detection import detect_country
from app.providers.fuel import FuelPrice

_log = logging.getLogger(__name__)

# HERE Places v7 endpoint. `browse` supports category + at + radius +
# limit; the `fuelStation` category (600-1200-0000) returns pumps
# with an `extended.fuelStation.prices` array carrying per-fuel-type
# per-litre EUR.
_ENDPOINT = "https://browse.search.hereapi.com/v1/browse"
_CATEGORY_FUEL = "700-7600-0116"  # Petrol / Diesel / Gas station
_MAX_RESULTS_PER_SAMPLE = 20
# Distance between corridor samples. Every 100 km covers most
# highways adequately without exhausting request quota on long
# trips (Zurich → Toledo ≈ 20 samples → 20 HERE requests).
_SAMPLE_STEP_KM = 150.0  # one sample per 150 km — adequate highway coverage
# Hard cap on samples per call. Adaptive formula gives n+1 total points:
#   <300 km → 1-2 samples (2-3 points), 600 km → 4 (5 points), 1800 km → 4 (5 points).
# Reduced from 12 → 4 to cap HERE Fuel requests at 5 per /plan regardless
# of route length. A 150 km spacing at 5 points covers up to 750 km without
# a gap; longer routes simply space samples further apart.
_MAX_SAMPLES = 4
# Radius per sample. 15 km catches highway-adjacent stations
# comfortably without pulling city-centre pumps that would never
# see a highway driver.
_SAMPLE_RADIUS_M = 15_000
_TIMEOUT_S = 6.0
# Wall-clock cap for the whole `prices_along` call. Individual
# samples run concurrently, so a slow HERE endpoint can no longer
# multiply out to `n_samples × _TIMEOUT_S` and starve the enrichment
# gather. On timeout we return whatever partial data has arrived.
_ALONG_BUDGET_S = 20.0

# Countries where the gov feeds already carry live prices. We skip
# HERE calls for these so the free-tier budget goes to the
# uncovered majority.
_SKIP_COUNTRIES: frozenset[Country] = frozenset(
    {Country.ES, Country.FR, Country.IT},
)

# HERE OAuth 2.0 token endpoint (client-credentials flow).
_HERE_TOKEN_ENDPOINT = "https://account.api.here.com/oauth2/token"


def _api_key() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_API_KEY") or None


def _app_id() -> str | None:
    return os.getenv("MYTRAVELPAL_HERE_APP_ID") or None


# Process-level Bearer token cache. Token is shared across all
# HereFuelPricesProvider instances so we fetch at most once per
# expiry window (default 24 h for HERE client-credentials tokens).
_token_cache: dict[str, Any] = {}

# Station-level response cache. Key: (lat_r2, lon_r2, fuel_type_str).
# 2-decimal rounding is ~1.1 km grid — adequate for fuel stations (the
# same stations appear within that box between price updates).
# TTL = 6 h: pump prices change at most twice a day; 6 h balances
# freshness against HERE API quota savings.
_FUEL_STATION_CACHE: dict[tuple[float, float, str], tuple[float, list[dict[str, Any]]]] = {}
_FUEL_STATION_CACHE_TTL_S = 6 * 3600  # 6 h


async def _fetch_bearer_token(client: httpx.AsyncClient) -> str | None:
    """Fetch a HERE OAuth 2.0 Bearer token using client credentials.

    Uses MYTRAVELPAL_HERE_APP_ID (client_id) and MYTRAVELPAL_HERE_API_KEY
    (client_secret). The token is cached until 60 s before expiry to avoid
    a fetch on every corridor sample batch.

    Returns None when credentials are absent or the token endpoint fails.
    """
    app_id = _app_id()
    api_key = _api_key()
    if not app_id or not api_key:
        return None

    now = time.monotonic()
    cached = _token_cache.get("token")
    expires_at = _token_cache.get("expires_at", 0.0)
    if cached and now < expires_at:
        return cached  # type: ignore[return-value]

    try:
        r = await client.post(
            _HERE_TOKEN_ENDPOINT,
            data={
                "grant_type": "client_credentials",
                "client_id": app_id,
                "client_secret": api_key,
            },
            timeout=8.0,
        )
    except Exception as exc:  # noqa: BLE001
        _log.warning("HERE OAuth token request failed: %r", exc)
        return None

    if r.status_code != 200:
        _log.warning(
            "HERE OAuth token HTTP %s: %s", r.status_code, r.text[:200],
        )
        return None

    try:
        payload = r.json()
    except ValueError:
        return None

    token = payload.get("access_token")
    expires_in = int(payload.get("expires_in") or 3600)
    if not token:
        _log.warning("HERE OAuth response missing access_token: %s", payload)
        return None

    _token_cache["token"] = token
    # Expire 60 s early to avoid using a token right as it lapses.
    _token_cache["expires_at"] = now + expires_in - 60
    _log.info(
        "HERE OAuth token obtained (expires in %ds)", expires_in,
    )
    return token  # type: ignore[return-value]


class HereFuelProvider:
    """FuelProvider backed by HERE Fuel Prices.

    Fills the gap for countries without a public government feed.
    Returns an empty tuple when no API key is configured.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        key = _api_key()
        if not key:
            return ()
        if route.distance_km <= 0:
            return ()
        # route.geometry may be empty on great-circle fallback routes —
        # _corridor_samples() handles that via waypoints, so don't bail here.
        # Diesel / gasoline default — HERE returns both when
        # available. EV fleet still routes through Geoapify EV.
        if (fuel_type or "").lower() == "electric":
            return ()
        sample_points = _corridor_samples(route)
        # Fire every sample concurrently — the old sequential loop
        # multiplied out to `n × _TIMEOUT_S` on long routes (17 samples
        # × 6 s = 102 s worst case) and was the single biggest reason a
        # CH → RO /plan blew past the client's 120 s timeout.
        skip_mask: list[Country | None] = []
        browse_coros: list = []
        for coord, _distance_km in sample_points:
            country = detect_country(coord)
            skip_mask.append(country)
            if country is None or country in _SKIP_COUNTRIES:
                # Placeholder coroutine that resolves to [] so the
                # gather stays aligned with `sample_points` — cheaper
                # than filtering the list twice.
                async def _skip() -> list[dict[str, Any]]:
                    return []
                browse_coros.append(_skip())
            else:
                browse_coros.append(self._browse(coord, key))
        try:
            gathered = await asyncio.wait_for(
                asyncio.gather(*browse_coros, return_exceptions=True),
                timeout=_ALONG_BUDGET_S,
            )
        except asyncio.TimeoutError:
            _log.warning(
                "HERE fuel prices_along exceeded %.0fs budget "
                "for %d samples; returning empty",
                _ALONG_BUDGET_S, len(sample_points),
            )
            return ()
        seen_ids: set[str] = set()
        out: list[FuelPrice] = []
        for (coord, distance_km), country, result in zip(
            sample_points, skip_mask, gathered,
        ):
            if country is None or country in _SKIP_COUNTRIES:
                continue
            if isinstance(result, BaseException):
                _log.warning("HERE fuel browse errored: %r", result)
                continue
            items = result
            for item in items:
                sid = str(item.get("id") or item.get("resultType") or "")
                if not sid or sid in seen_ids:
                    continue
                seen_ids.add(sid)
                pos = item.get("position") or {}
                lat = pos.get("lat")
                lon = pos.get("lng")
                if lat is None or lon is None:
                    continue
                price = _extract_price(item)
                price_ok = price is not None and _price_plausible(price, country)
                if not price_ok:
                    # HERE didn't return price data for this station
                    # (typical when the Browse endpoint has no price feed
                    # for this country). Include the station at the country
                    # anchor price so the driver can still see WHERE to stop.
                    from app.data.countries import COUNTRIES
                    anchor = COUNTRIES.get(country.value)
                    price = anchor.fuel_petrol_anchor_eur if anchor else 1.75
                out.append(FuelPrice(
                    station_name=str(item.get("title") or "Fuel station"),
                    country=country,
                    price_eur_per_l=round(float(price), 3),
                    distance_from_origin_km=round(distance_km, 1),
                    coordinate=Coordinate(lat=float(lat), lon=float(lon)),
                    attributes=_attributes(item),
                    price_available=price_ok,
                ))
        out.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(out)

    async def _browse(
        self, at: Coordinate, key: str,
    ) -> list[dict[str, Any]]:
        ck = (round(at.lat, 2), round(at.lon, 2), "browse")
        cached = _FUEL_STATION_CACHE.get(ck)
        if cached is not None:
            ts, data = cached
            if time.monotonic() - ts < _FUEL_STATION_CACHE_TTL_S:
                return data
        params = {
            "at": f"{at.lat:.5f},{at.lon:.5f}",
            "categories": _CATEGORY_FUEL,
            "in": f"circle:{at.lat:.5f},{at.lon:.5f};r={_SAMPLE_RADIUS_M}",
            "limit": _MAX_RESULTS_PER_SAMPLE,
            "apiKey": key,
        }
        try:
            r = await self._client.get(_ENDPOINT, params=params)
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE fuel browse failed: %r", exc)
            return []
        if r.status_code != 200:
            _log.warning(
                "HERE fuel browse HTTP %s: %s",
                r.status_code, r.text[:200],
            )
            return []
        try:
            payload = r.json()
        except ValueError:
            return []
        items = payload.get("items")
        result = items if isinstance(items, list) else []
        _FUEL_STATION_CACHE[ck] = (time.monotonic(), result)
        return result


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    import math
    R = 6371.0
    lat1, lon1 = math.radians(a.lat), math.radians(a.lon)
    lat2, lon2 = math.radians(b.lat), math.radians(b.lon)
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def _corridor_samples(route: Route) -> list[tuple[Coordinate, float]]:
    """Return `(coord, cumulative_km)` samples every ~100 km along
    the route geometry. Includes start and end so short trips still
    receive at least one probe.

    When route.geometry is empty (great-circle fallback), build samples
    from origin + waypoints + destination so long sparse routes still
    receive corridor probes.
    """
    if not route.geometry:
        waypoints = [route.origin, *(route.waypoints or ()), route.destination]
        if len(waypoints) < 2:
            return []
        samples: list[tuple[Coordinate, float]] = []
        cum_km = 0.0
        samples.append((waypoints[0], 0.0))
        for prev, cur in zip(waypoints, waypoints[1:]):
            cum_km += _haversine_km(prev, cur)
            samples.append((cur, cum_km))
        return samples
    total_km = route.distance_km
    if total_km <= 0:
        return [(route.geometry[0], 0.0)]
    samples: list[tuple[Coordinate, float]] = []
    # Adaptive spacing: aim for one sample per _SAMPLE_STEP_KM, but
    # hard-cap at _MAX_SAMPLES so a runaway route (or great-circle
    # fallback) can't blow up the fan-out. Long trips end up sampling
    # every ~total_km / _MAX_SAMPLES km instead of every 100 km.
    n_samples = max(1, min(_MAX_SAMPLES, int(total_km / _SAMPLE_STEP_KM)))
    step = 1.0 / max(1, n_samples)
    for i in range(n_samples + 1):
        fraction = min(1.0, i * step)
        idx = int(fraction * (len(route.geometry) - 1))
        samples.append((route.geometry[idx], fraction * total_km))
    return samples


# Approximate conversion rates to EUR for countries that don't use the euro.
# Values are fixed-point approximations — close enough for price comparisons.
# Updated periodically; minor drift has no meaningful effect on the
# "cheap vs expensive" ranking that drives the savings display.
_TO_EUR: dict[str, float] = {
    "EUR": 1.0,
    "NOK": 0.087,   # Norwegian krone
    "SEK": 0.087,   # Swedish krona
    "DKK": 0.134,   # Danish krone
    "CHF": 1.05,    # Swiss franc
    "GBP": 1.18,    # British pound
    "PLN": 0.23,    # Polish zloty
    "CZK": 0.040,   # Czech koruna
    "HUF": 0.0025,  # Hungarian forint
    "RON": 0.201,   # Romanian leu
    "BGN": 0.511,   # Bulgarian lev (pegged to EUR)
    "HRK": 0.133,   # Croatian kuna (legacy; Croatia now EUR)
    "RSD": 0.0085,  # Serbian dinar
    "MKD": 0.0162,  # Macedonian denar
    "TRY": 0.027,   # Turkish lira
    "ISK": 0.0069,  # Icelandic krona
}


def _to_eur(price: float, currency: str) -> float | None:
    rate = _TO_EUR.get(currency.upper())
    return round(price * rate, 4) if rate is not None else None


def _extract_price(item: dict[str, Any]) -> float | None:
    """Dig a per-litre EUR price out of the HERE Browse response.

    HERE's fuel-station schema exposes an `extended.fuelStation.prices`
    array with entries like `{"type": "diesel", "price": 1.789,
    "currency": "EUR", "unit": "l"}`. Prefer diesel (Europe's
    dominant road fuel) → SP95 → SP98 → any. Non-EUR currencies are
    converted using fixed-point rates so Scandinavian/Swiss prices
    (NOK, DKK, SEK, CHF) don't silently disappear.
    """
    ext = item.get("extended") or {}
    fs = ext.get("fuelStation") or {}
    prices = fs.get("prices") or []
    if not isinstance(prices, list):
        return None
    preferred = ("diesel", "petrol_95", "petrol_98", "e10", "sp95", "sp98")
    for want in preferred:
        for p in prices:
            if not isinstance(p, dict):
                continue
            if str(p.get("type", "")).lower() == want:
                val = p.get("price")
                cur = str(p.get("currency", "EUR")).upper()
                if isinstance(val, (int, float)):
                    return _to_eur(float(val), cur)
    # Fallback: first entry that is positively a petrol/diesel type. An
    # allow-list, not a block-list: a block-list lets every fuel nobody
    # thought of (GPLc, bio-ethanol, a local blend) through, and their
    # per-litre price is far below petrol/diesel, which fakes a saving.
    for p in prices:
        if not isinstance(p, dict) or not _is_road_fuel(str(p.get("type", ""))):
            continue
        val = p.get("price")
        cur = str(p.get("currency", "EUR")).upper()
        if isinstance(val, (int, float)):
            return _to_eur(float(val), cur)
    return None


_ROAD_FUEL_KEYWORDS = (
    "diesel", "gasoil", "gazole", "petrol", "gasoline", "unleaded",
    "super", "sp95", "sp98", "e10", "benz",
)
_NON_ROAD_FUEL_KEYWORDS = (
    "e85", "lpg", "gpl", "cng", "lng", "hydrogen", "h2", "adblue",
    "autogas", "ethanol", "bio", "electric",
)


def _is_road_fuel(type_name: str) -> bool:
    """True when a HERE fuel `type` name is positively petrol or diesel."""
    t = type_name.lower()
    if any(k in t for k in _NON_ROAD_FUEL_KEYWORDS):
        return False
    return any(k in t for k in _ROAD_FUEL_KEYWORDS)


_FUEL_PRICES_ENDPOINT = "https://fuel.hereapi.com/v3/stations"

# Map our internal fuel_type strings to HERE Fuel Prices API fuelType values.
_FUEL_TYPE_MAP: dict[str, str] = {
    "diesel": "diesel",
    "petrol": "unleaded",
    "gasoline": "unleaded",
    "lpg": "lpg",
    "e10": "e10",
    "sp95": "unleaded",
    "sp98": "sp98",
}


def _map_here_fuel_type(fuel_type: str | None) -> str:
    """Return the HERE Fuel Prices `fuelType` param for our fuel_type string.

    Defaults to 'diesel' — the dominant road fuel across Europe.
    """
    if not fuel_type:
        return "diesel"
    return _FUEL_TYPE_MAP.get(fuel_type.lower(), "diesel")


# Human-readable labels for HERE v3 fuelType numeric codes (names from HERE's
# own catalogue, GET /v3/fuelTypes).
_FUEL_TYPE_LABELS: dict[str, str] = {
    "1": "Diesel",
    "18": "Diesel",
    "55": "Premium Diesel",
    "10": "Diesel Plus",
    "32": "Super Diesel",
    "54": "Super E10",
    "53": "Super E5",
    "43": "E10",
    "33": "E5",
    "13": "E10",
    "56": "95",
    "66": "Super 95",
    "35": "Unleaded",
    "2": "Regular",
    "59": "Super 98",
    "60": "98",
    "40": "100",
    "14": "LPG",
    "24": "LPG",
    "21": "CNG",
    "16": "CNG",
    "5": "E85",
}

# Which HERE codes a driver's fuel reads, in order of preference.
_HERE_CODES_BY_FUEL: dict[str, tuple[str, ...]] = {
    "petrol": ("54", "53", "43", "33", "56", "13", "66", "35", "2", "59", "60", "40"),
    "diesel": ("1", "18", "55", "10", "32", "58", "76"),
    "lpg": ("14", "24", "95"),
    "e85": ("5", "75"),
    "cng": ("21", "16", "96"),
}
_HERE_CODES_BY_FUEL["gasoline"] = _HERE_CODES_BY_FUEL["petrol"]
_HERE_CODES_BY_FUEL["sp95"] = _HERE_CODES_BY_FUEL["petrol"]
_HERE_CODES_BY_FUEL["sp98"] = _HERE_CODES_BY_FUEL["petrol"]
# A hybrid burns petrol: never offer it a diesel station.
_HERE_CODES_BY_FUEL["hybrid"] = _HERE_CODES_BY_FUEL["petrol"]
_HERE_CODES_BY_FUEL["phev"] = _HERE_CODES_BY_FUEL["petrol"]

# Drivers of fuels that cost far less than petrol: no road-fuel price floor.
_ALT_FUEL_DRIVERS = frozenset({"lpg", "e85", "cng"})

# AdBlue (urea) products: for cars, for trucks, and the generic ones.
_ADBLUE_CAR_CODES = ("71", "19", "91")
_ADBLUE_TRUCK_CODES = ("72", "92")


# Sanity bounds for pump prices in EUR/L.
# Below 0.90 → almost certainly CNG/propane price or stale/wrong data.
# Above 4.00 → data error (even peak-crisis Swiss motorway prices stayed below this).
_MIN_PLAUSIBLE_EUR_PER_L = 0.90
_MAX_PLAUSIBLE_EUR_PER_L = 4.00

# Reject prices not updated within 7 days — HERE station data without
# a recent update is stale and misleading. We'd rather show no price
# than a wrong one (the station still appears as a location marker).
_MAX_PRICE_AGE_DAYS = 7


# A road-fuel price this far below the country's usual pump price is not a
# discount, it is another fuel (LPG, E85, CNG) or bad data. 0.969 EUR/L in
# France (usual ~1.75) passed the flat 0.90 floor and was shown as a 42 EUR
# saving.
_COUNTRY_FLOOR_FRACTION = 0.65


def _country_floor(country: Any) -> float:
    """Lowest believable EUR/L for `country`: the flat floor, raised to a
    fraction of the country's reference petrol price when we know it."""
    try:
        from app.data.countries import COUNTRIES

        ref = COUNTRIES.get(getattr(country, "value", country))
        if ref is not None and ref.fuel_petrol_anchor_eur:
            return max(
                _MIN_PLAUSIBLE_EUR_PER_L,
                _COUNTRY_FLOOR_FRACTION * ref.fuel_petrol_anchor_eur,
            )
    except Exception:  # noqa: BLE001 - never let a lookup break pricing
        pass
    return _MIN_PLAUSIBLE_EUR_PER_L


def _price_plausible(eur_per_l: float, country: Any = None) -> bool:
    """Return True when the price is within realistic bounds, tightened by
    the country's usual price level when `country` is given."""
    floor = _country_floor(country) if country is not None else _MIN_PLAUSIBLE_EUR_PER_L
    return floor <= eur_per_l <= _MAX_PLAUSIBLE_EUR_PER_L


def _extract_fuel_price_from_prices_api(
    station: dict[str, Any], fuel_type: str | None = None,
) -> tuple[float | None, str | None]:
    """Pick the best EUR-converted price from a HERE Fuel Prices v3 station.

    v3 station schema (field is 'prices', fuelType is a numeric code string):
        { "prices": [{"fuelType": "53", "price": 1.789, "currency": "EUR", "unit": "l"}] }

    HERE v3 fuelType numeric codes for common European road fuels:
        "53" = Diesel standard (most common in DE/AT/etc.)
        "54" = Diesel premium / V-Power Diesel
        "1"  = Super / E10 (petrol blend)
        "11" = Super Plus 98
        "55" = Super 95
        "59" = Super Plus 95
        "21" = LPG / Autogas
        "72" = LPG variant
        "14" = CNG / natural gas (very cheap, ~€1/kg)
        "40" = Premium petrol

    Preference: for petrol routes prefer codes 1/55/11; for diesel prefer 53/54.
    Skip LPG (21/72) and CNG (14) to avoid confusion with liquid fuel prices.
    """
    prices = station.get("prices") or []
    if not isinstance(prices, list):
        return None, None

    # Codes are HERE's own `fuelTypes` catalogue (GET /v3/fuelTypes), checked
    # against the live API: 1 is Diesel, 53/54 are Super E5/E10 petrol.
    # Each driver fuel only ever reads its own family; there is no fallback
    # to another family (a petrol driver is never quoted a diesel price).
    ft_lower = (fuel_type or "").lower()
    if ft_lower in _HERE_CODES_BY_FUEL:
        preferred_codes = _HERE_CODES_BY_FUEL[ft_lower]
    else:
        # Diesel default (also catches None / unknown).
        preferred_codes = _HERE_CODES_BY_FUEL["diesel"]

    for want in preferred_codes:
        for p in prices:
            if not isinstance(p, dict):
                continue
            ft = str(p.get("fuelType") or "")
            if ft == want:
                val = p.get("price")
                cur = str(p.get("currency") or "EUR").upper()
                if isinstance(val, (int, float)):
                    eur = _to_eur(float(val), cur)
                    # The believable-price floor is for road fuels; LPG, E85
                    # and CNG are legitimately far cheaper.
                    if eur is not None and (
                        ft_lower in _ALT_FUEL_DRIVERS or _price_plausible(eur)
                    ):
                        label = _FUEL_TYPE_LABELS.get(ft)
                        return eur, label

    # No fallback to "the cheapest price with any other code": an unlisted
    # code can be LPG, E85 or a local fuel, and the cheapest one is exactly
    # the one that looks like a bargain. Better no price than a wrong one.
    return None, None


def _price_for_codes(station: dict[str, Any], codes: tuple[str, ...]) -> float | None:
    """EUR price of the first of `codes` the station sells, or None."""
    for want in codes:
        for p in station.get("prices") or []:
            if not isinstance(p, dict) or str(p.get("fuelType") or "") != want:
                continue
            val = p.get("price")
            if isinstance(val, (int, float)) and val > 0:
                return _to_eur(float(val), str(p.get("currency") or "EUR").upper())
    return None


def _attributes_from_prices_api(
    station: dict[str, Any],
) -> tuple[tuple[str, str], ...]:
    """Curate display tags from a HERE Fuel Prices v3 station entry."""
    attrs: list[tuple[str, str]] = []
    brand = station.get("brand") or station.get("name", "")
    if brand:
        attrs.append(("brand", str(brand)))
    # AdBlue per litre, when the station sells it (separate for trucks).
    for key, codes in (("adblue", _ADBLUE_CAR_CODES), ("adblue_truck", _ADBLUE_TRUCK_CODES)):
        eur = _price_for_codes(station, codes)
        if eur is not None:
            attrs.append((key, f"{eur:.3f}"))
    # v3 exposes modification timestamp per-station
    modified = station.get("modified") or station.get("lastUpdated")
    if modified:
        # Trim to date+hour for display: "2026-10-04T21:37" → "2026-10-04 21:37"
        short = str(modified)[:16].replace("T", " ")
        attrs.append(("last_updated", short))
    return tuple(attrs)


class HereFuelPricesProvider:
    """FuelProvider backed by HERE Fuel Prices API (fuel.hereapi.com/v3/stations).

    Returns real pump prices (price_available=True) for the 25+ countries
    the government feeds do not cover. Each route corridor sample calls
    the `/v3/stations` endpoint with a 15 km radius; results are
    de-duplicated by station id and merged in kilometre order.

    Authentication priority:
    1. OAuth 2.0 Bearer token — fetched via client-credentials grant when
       MYTRAVELPAL_HERE_APP_ID is set (client_id=APP_ID,
       client_secret=HERE_API_KEY). Token is cached until 60 s before expiry.
    2. apiKey query parameter — used when only HERE_API_KEY is set (no APP_ID).

    Falls back gracefully when credentials are absent or the endpoint returns
    no stations — the HybridFuelProvider then tries HereFuelProvider
    (Browse) and finally Nominatim.
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=_TIMEOUT_S)

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        # Need at least the API key to proceed.
        if not _api_key() and not _app_id():
            return ()
        if route.distance_km <= 0:
            return ()
        if (fuel_type or "").lower() == "electric":
            return ()

        # Resolve auth once for the whole batch — OAuth fetches a token;
        # apiKey path just passes through the key string.
        bearer_token: str | None = None
        api_key_val: str | None = None
        if _app_id():
            bearer_token = await _fetch_bearer_token(self._client)
            if not bearer_token:
                _log.warning(
                    "HERE OAuth token fetch failed; falling back to apiKey",
                )
                api_key_val = _api_key()
        else:
            api_key_val = _api_key()

        if not bearer_token and not api_key_val:
            return ()

        here_fuel_type = _map_here_fuel_type(fuel_type)
        sample_points = _corridor_samples(route)

        skip_mask: list[Country | None] = []
        fetch_coros: list = []
        for coord, _distance_km in sample_points:
            country = detect_country(coord)
            skip_mask.append(country)
            if country is None or country in _SKIP_COUNTRIES:
                async def _skip() -> list[dict[str, Any]]:
                    return []
                fetch_coros.append(_skip())
            else:
                fetch_coros.append(
                    self._fetch(
                        coord,
                        here_fuel_type,
                        bearer_token=bearer_token,
                        api_key=api_key_val,
                    ),
                )

        try:
            gathered = await asyncio.wait_for(
                asyncio.gather(*fetch_coros, return_exceptions=True),
                timeout=_ALONG_BUDGET_S,
            )
        except asyncio.TimeoutError:
            _log.warning(
                "HERE fuel prices exceeded %.0fs budget for %d samples; "
                "returning empty",
                _ALONG_BUDGET_S, len(sample_points),
            )
            return ()

        seen_ids: set[str] = set()
        out: list[FuelPrice] = []
        for (coord, distance_km), country, result in zip(
            sample_points, skip_mask, gathered,
        ):
            if country is None or country in _SKIP_COUNTRIES:
                continue
            if isinstance(result, BaseException):
                _log.warning("HERE fuel prices fetch errored: %r", result)
                continue
            for station in result:
                sid = str(station.get("id") or "")
                if not sid or sid in seen_ids:
                    continue
                seen_ids.add(sid)
                pos = station.get("position") or {}
                lat = pos.get("lat")
                lng = pos.get("lng")
                if lat is None or lng is None:
                    continue
                # Reject stale prices: if the station hasn't been updated
                # within _MAX_PRICE_AGE_DAYS, treat as price_unavailable so
                # we fall back to the country anchor instead of misleading data.
                modified_str = station.get("modified") or station.get("lastUpdated")
                if modified_str:
                    try:
                        import datetime as _dt
                        modified_dt = _dt.datetime.fromisoformat(
                            str(modified_str)[:19].replace("Z", "")
                        )
                        age_days = (_dt.datetime.utcnow() - modified_dt).days
                        if age_days > _MAX_PRICE_AGE_DAYS:
                            station = dict(station)
                            station["prices"] = []  # force price_available=False
                    except (ValueError, TypeError):
                        pass
                raw_price, fuel_label = _extract_fuel_price_from_prices_api(station, fuel_type)
                if (
                    raw_price is not None
                    and (fuel_type or "").lower() not in _ALT_FUEL_DRIVERS
                    and not _price_plausible(raw_price, country)
                ):
                    # Far below this country's pump prices: another fuel or
                    # bad data. Show the station without a price instead.
                    raw_price, fuel_label = None, None
                price_ok = raw_price is not None
                if raw_price is None:
                    # No live price from HERE for this station. Use the
                    # country anchor ONLY as a display placeholder so the
                    # station appears on the map; mark price_available=False
                    # so the savings calculation ignores it. The anchor is
                    # intentionally 0.0 here — we prefer showing no price
                    # to showing a potentially wrong one.
                    price_eur: float = 0.0
                else:
                    price_eur = raw_price
                base_name = str(station.get("name") or "Fuel station")
                display_name = (
                    f"{base_name} · {fuel_label}" if fuel_label else base_name
                )
                out.append(FuelPrice(
                    station_name=display_name,
                    country=country,
                    price_eur_per_l=round(price_eur, 3),
                    distance_from_origin_km=round(distance_km, 1),
                    coordinate=Coordinate(lat=float(lat), lon=float(lng)),
                    attributes=_attributes_from_prices_api(station),
                    price_available=price_ok,
                ))
        # Post-process: same brand + same fuel label + km within 5 km →
        # keep only the cheaper one (same junction, same direction).
        out.sort(key=lambda p: p.distance_from_origin_km)
        deduped: list[FuelPrice] = []
        seen_brand_km: dict[tuple[str, float], int] = {}  # key → index in deduped
        for p in out:
            km_bucket = round(p.distance_from_origin_km / 5.0) * 5.0
            key = (p.station_name.lower(), km_bucket)
            if key in seen_brand_km:
                idx = seen_brand_km[key]
                if p.price_available and p.price_eur_per_l < deduped[idx].price_eur_per_l:
                    deduped[idx] = p
            else:
                seen_brand_km[key] = len(deduped)
                deduped.append(p)
        deduped.sort(key=lambda p: p.distance_from_origin_km)
        return tuple(deduped)

    async def _fetch(
        self,
        at: Coordinate,
        fuel_type: str,
        *,
        bearer_token: str | None,
        api_key: str | None,
    ) -> list[dict[str, Any]]:
        """Fetch stations near `at` from the HERE Fuel Prices v3 endpoint.

        Sends an OAuth 2.0 Bearer token when available; falls back to the
        `apiKey` query parameter. Both are supported by fuel.hereapi.com.
        Results are cached 6 h keyed on a ~1.1 km grid + fuel_type.
        """
        ck = (round(at.lat, 2), round(at.lon, 2), fuel_type or "diesel")
        cached = _FUEL_STATION_CACHE.get(ck)
        if cached is not None:
            ts, data = cached
            if time.monotonic() - ts < _FUEL_STATION_CACHE_TTL_S:
                return data

        params: dict[str, str] = {
            "in": f"circle:{at.lat:.5f},{at.lon:.5f};r={_SAMPLE_RADIUS_M}",
        }
        headers: dict[str, str] = {}
        if bearer_token:
            headers["Authorization"] = f"Bearer {bearer_token}"
        elif api_key:
            params["apiKey"] = api_key
        else:
            return []

        try:
            r = await self._client.get(
                _FUEL_PRICES_ENDPOINT, params=params, headers=headers,
            )
        except Exception as exc:  # noqa: BLE001
            _log.warning("HERE fuel prices request failed: %r", exc)
            return []
        if r.status_code != 200:
            _log.warning(
                "HERE fuel prices HTTP %s: %s",
                r.status_code, r.text[:200],
            )
            return []
        try:
            payload = r.json()
        except ValueError:
            return []
        stations = payload.get("stations") or []
        result = stations if isinstance(stations, list) else []
        _FUEL_STATION_CACHE[ck] = (time.monotonic(), result)
        return result


def _attributes(item: dict[str, Any]) -> tuple[tuple[str, str], ...]:
    """Curate a small set of user-visible tags for the mobile
    detail sheet — brand and opening hours are the two the driver
    actually looks at when choosing a station.
    """
    ext = item.get("extended") or {}
    fs = ext.get("fuelStation") or {}
    brand = fs.get("brandName") or item.get("chains", [{}])[0].get(
        "name",
    ) if isinstance(item.get("chains"), list) else None
    hours = fs.get("openingHours") or item.get("openingHours")
    attrs: list[tuple[str, str]] = []
    if brand:
        attrs.append(("brand", str(brand)))
    if isinstance(hours, str):
        attrs.append(("opening_hours", hours))
    elif isinstance(hours, list) and hours:
        first = hours[0]
        if isinstance(first, dict) and first.get("text"):
            attrs.append(("opening_hours", str(first["text"])))
    return tuple(attrs)

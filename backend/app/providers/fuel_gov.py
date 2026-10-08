"""Real fuel prices from public government feeds.

Spain (Ministerio para la Transición Ecológica) and France (Roulez-Éco)
publish every fuel station's current per-litre price under an open
licence — no API key, no per-request cost. This module wraps both,
caches the full national datasets in-process (12 h TTL — the feeds
themselves refresh once a day for Spain / periodically for France),
and filters by route corridor on each request.

Design notes:
- One HTTP call per country per 12 h. Spain returns ~15 MB JSON,
  France ~1 MB gzipped XML. Fits comfortably in a 512 MB Fly VM.
- Concurrent /plan requests share the same cache via an asyncio Lock
  so we never double-fetch on a cold cache.
- Fuel type: the feeds carry diesel, SP95, SP98, E10, LPG, E85. We
  expose the diesel price as the primary `price_eur_per_l` (Europe's
  majority fuel), and stash the full breakdown into `attributes` so
  the mobile detail sheet renders every available column.
- Non-diesel-only stations fall back through SP95 → SP98 → first
  available so we never emit a nonsense €0/L entry.
"""

from __future__ import annotations

import asyncio
import io
import logging
import time
import xml.etree.ElementTree as ET
import zipfile

import httpx

from app.domain import Coordinate, Country, Route
from app.providers.fuel import FuelPrice

_log = logging.getLogger(__name__)

_TTL_S = 12 * 3600
# Aggressive timeout: government endpoints that don't respond within
# 8 s aren't going to respond, and every second past that is starving
# the event loop for concurrent requests. Failure triggers the
# `_failed_at` backoff so we don't hammer them.
_TIMEOUT = httpx.Timeout(connect=15.0, read=20.0, write=5.0, pool=5.0)
_USER_AGENT = "MyTravelPal/1.0 (+https://mytravelpal.app)"

# Off-corridor cap. Fuel stations further than this are dropped —
# nobody detours 30 km for petrol.
_MAX_OFF_CORRIDOR_KM = 8.0
# Per-country cap on the raw list handed to `curate_stations`. Sorted
# BY DISTANCE from origin globally, a 500-item cap threw out every
# French station on a Madrid→Zurich trip because the first 500 by
# distance were all Spanish (the trip starts inside Spain). Capping
# per country keeps every crossed country represented before the
# downstream curator picks the final N per country.
_PER_COUNTRY_RAW_CAP = 150


def _new_client() -> httpx.AsyncClient:
    # `local_address="0.0.0.0"` binds the outgoing socket to IPv4 on
    # Linux — Fly egress out of CDG sometimes attempts IPv6 first,
    # hangs on AAAA to the ministry hosts and surfaces as an empty
    # `ConnectError('')`. IPv4-only side-steps the resolver dance.
    transport = httpx.AsyncHTTPTransport(
        retries=2, local_address="0.0.0.0",
    )
    return httpx.AsyncClient(
        transport=transport,
        timeout=_TIMEOUT,
        headers={"User-Agent": _USER_AGENT, "Accept": "*/*"},
        follow_redirects=True,
    )


# Cool-off before re-attempting a failed dataset fetch. Without it the
# prewarm loop and every /plan request would re-hit a broken endpoint
# repeatedly, filling fly logs and slowing every response by the full
# _TIMEOUT_S wait.
_FAILURE_BACKOFF_S = 300.0


def _haversine_km(a: Coordinate, b: Coordinate) -> float:
    from app.providers.routing import _haversine_km as f
    return f(a, b)


def _distance_from_route_km(point: Coordinate, route: Route) -> float:
    """Distance from a POI to the route corridor, in km.

    Iterates `route.geometry` — for accuracy DO NOT decimate the
    reference points here. When filtering many POIs against the same
    route, downsample once with `_route_reference_points()` and pass
    an already-sampled tuple through `_distance_to_points()` instead.
    """
    dense = route.geometry or (route.origin, *route.waypoints, route.destination)
    return min(_haversine_km(point, p) for p in dense)


# Corridor sampling density. We downsample the OSRM polyline (which
# can be 2 600+ vertices for a 200 km trip and 15 000+ for a
# 1 500 km trip) so the nearest-vertex loop stays cheap. Target
# spacing: `_TARGET_SAMPLE_KM` km between adjacent samples, so a
# station lying anywhere in the `_MAX_OFF_CORRIDOR_KM`-wide corridor
# is still within the corridor of at least one sample. Clamped to
# `_MIN`/`_MAX` so tiny trips get enough anchors and enormous ones
# don't explode.
_TARGET_SAMPLE_KM = 5.0
_MIN_ROUTE_REFERENCE_POINTS = 30
_MAX_ROUTE_REFERENCE_POINTS = 300


def _route_reference_points(route: Route) -> tuple[Coordinate, ...]:
    dense = route.geometry or (route.origin, *route.waypoints, route.destination)
    if len(dense) <= _MIN_ROUTE_REFERENCE_POINTS:
        return tuple(dense)
    target = int(route.distance_km / _TARGET_SAMPLE_KM) or _MIN_ROUTE_REFERENCE_POINTS
    target = max(_MIN_ROUTE_REFERENCE_POINTS,
                 min(_MAX_ROUTE_REFERENCE_POINTS, target))
    if len(dense) <= target:
        return tuple(dense)
    step = max(1, len(dense) // target)
    sampled = list(dense[::step])
    if sampled[0] is not dense[0]:
        sampled.insert(0, dense[0])
    if sampled[-1] is not dense[-1]:
        sampled.append(dense[-1])
    return tuple(sampled)


def _distance_to_points(
    point: Coordinate, reference: tuple[Coordinate, ...],
) -> float:
    return min(_haversine_km(point, p) for p in reference)


class _Station:
    """In-memory station record shared by all country providers."""
    __slots__ = ("coord", "name", "brand", "prices")

    def __init__(
        self, coord: Coordinate, name: str, brand: str | None,
        prices: dict[str, float],
    ) -> None:
        self.coord = coord
        self.name = name
        self.brand = brand
        self.prices = prices


_FUEL_TYPE_MAP: dict[str, tuple[str, ...]] = {
    "diesel": ("diesel",),
    "petrol": ("sp95", "e10", "sp98"),
    "lpg": ("lpg",),
    "electric": (),
}
# E85 deliberately last — its ~0.70 €/L price would distort savings
# calculations when used as a fallback for regular petrol stations.
_DEFAULT_ORDER = ("diesel", "sp95", "e10", "sp98", "lpg", "e85")


def _pick_primary_price(
    prices: dict[str, float],
    preferred: str | None = None,
) -> tuple[str, float] | None:
    """Choose which fuel type to expose as `price_eur_per_l`.

    When `preferred` matches a profile fuel type, try those keys
    first. Falls back to the default order so a diesel station
    still appears (with its diesel price) for a petrol driver.
    """
    order = _DEFAULT_ORDER
    if preferred:
        pref_keys = _FUEL_TYPE_MAP.get(preferred.lower(), ())
        if pref_keys:
            order = (*pref_keys, *(k for k in _DEFAULT_ORDER if k not in pref_keys))
    for key in order:
        val = prices.get(key)
        if val and val > 0:
            return (key, val)
    return None


def _station_to_fuel_price(
    st: _Station, route: Route, distance_km: float, country: Country,
    preferred_fuel: str | None = None,
) -> FuelPrice | None:
    primary = _pick_primary_price(st.prices, preferred=preferred_fuel)
    if primary is None:
        return None
    fuel_type_key, unit = primary
    label = st.brand or st.name
    attrs: list[tuple[str, str]] = [("primary_fuel", fuel_type_key)]
    for k, v in st.prices.items():
        attrs.append((k, f"{v:.3f}"))
    return FuelPrice(
        station_name=label,
        country=country,
        price_eur_per_l=round(unit, 3),
        distance_from_origin_km=round(
            _haversine_km(route.origin, st.coord), 1,
        ),
        coordinate=st.coord,
        attributes=tuple(attrs),
    )


# --------------------------------------------------------------------
# Country: Spain (Ministerio para la Transición Ecológica y el Reto Demográfico)
# --------------------------------------------------------------------

_SPAIN_URL = (
    "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
    "PreciosCarburantes/EstacionesTerrestres/"
)
# Mapping from the feed's Spanish column names to our canonical fuel
# keys. Only the ones a passenger car / motorbike / camper cares
# about; industrial diesel, biodiesel etc. are ignored.
_SPAIN_PRICE_COLS: dict[str, str] = {
    "Precio Gasoleo A": "diesel",
    "Precio Gasolina 95 E5": "sp95",
    "Precio Gasolina 98 E5": "sp98",
    "Precio Gases licuados del petróleo": "lpg",
}


def _parse_es_number(raw: str) -> float | None:
    """Spain writes numbers with a comma decimal separator."""
    if not raw or raw == "-":
        return None
    try:
        return float(raw.replace(",", "."))
    except ValueError:
        return None


class SpainMinisterioFuelDataset:
    """12 h in-process cache of the whole Spain fuel dataset."""

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()
        self._stations: tuple[_Station, ...] = ()
        self._loaded_at: float = 0.0
        self._failed_at: float = 0.0
        self._lock = asyncio.Lock()

    async def stations(self) -> tuple[_Station, ...]:
        if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
            return self._stations
        # Recent failure? Skip the retry until backoff elapses — return
        # whatever we had cached (empty tuple on first cold start).
        if (
            self._failed_at
            and time.monotonic() - self._failed_at < _FAILURE_BACKOFF_S
        ):
            return self._stations
        async with self._lock:
            if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
                return self._stations
            try:
                response = await self._client.get(_SPAIN_URL)
                response.raise_for_status()
                raw = response.content
            except httpx.HTTPError as exc:
                _log.warning("Spain fuel feed fetch failed: %r", exc)
                self._failed_at = time.monotonic()
                # If we had a previous good snapshot, keep serving it
                # even if past TTL — beats returning nothing.
                return self._stations
            # Parse off-thread: the 15 MB JSON blocks the asyncio loop
            # long enough for the Fly health check to time out and kill
            # the machine. `to_thread` sends it to the default executor
            # so other requests keep flowing.
            try:
                stations = await asyncio.to_thread(_parse_spain, raw)
            except (ValueError, KeyError) as exc:
                _log.warning("Spain fuel feed parse failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            self._stations = tuple(stations)
            self._loaded_at = time.monotonic()
            _log.info(
                "Spain fuel dataset loaded: %d stations",
                len(self._stations),
            )
            return self._stations


def _parse_spain(raw: bytes) -> list[_Station]:
    """Pure parse of the Ministerio JSON. Called from `to_thread` so
    the JSON decode + iteration doesn't block the asyncio loop.
    """
    import json
    body = json.loads(raw)
    stations: list[_Station] = []
    for entry in body.get("ListaEESSPrecio") or []:
        lat = _parse_es_number(entry.get("Latitud", ""))
        lon = _parse_es_number(entry.get("Longitud (WGS84)", ""))
        if lat is None or lon is None:
            continue
        prices: dict[str, float] = {}
        for src, key in _SPAIN_PRICE_COLS.items():
            v = _parse_es_number(entry.get(src, ""))
            if v is not None and v > 0:
                prices[key] = v
        if not prices:
            continue
        name = str(entry.get("Rótulo") or "").title() or "Estación"
        brand = str(entry.get("Rótulo") or "").title() or None
        try:
            coord = Coordinate(lat=lat, lon=lon)
        except ValueError:
            continue
        stations.append(_Station(coord, name, brand, prices))
    return stations


# --------------------------------------------------------------------
# Country: France (Roulez-Éco / prix-carburants)
# --------------------------------------------------------------------

_FRANCE_URL = "https://donnees.roulez-eco.fr/opendata/instantane"
_FRANCE_PRICE_NAMES: dict[str, str] = {
    "Gazole": "diesel",
    "SP95": "sp95",
    "SP98": "sp98",
    "E10": "e10",
    "GPLc": "lpg",
    "E85": "e85",
}


class FranceRoulezEcoFuelDataset:
    """12 h in-process cache of the whole France fuel dataset."""

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()
        self._stations: tuple[_Station, ...] = ()
        self._loaded_at: float = 0.0
        self._failed_at: float = 0.0
        self._lock = asyncio.Lock()

    async def stations(self) -> tuple[_Station, ...]:
        if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
            return self._stations
        if (
            self._failed_at
            and time.monotonic() - self._failed_at < _FAILURE_BACKOFF_S
        ):
            return self._stations
        async with self._lock:
            if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
                return self._stations
            try:
                response = await self._client.get(_FRANCE_URL)
                response.raise_for_status()
                zbytes = response.content
            except httpx.HTTPError as exc:
                _log.warning("France fuel feed fetch failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            # Unzip + XML parse off-thread — same reason as Spain.
            try:
                stations = await asyncio.to_thread(_parse_france, zbytes)
            except (zipfile.BadZipFile, ET.ParseError, OSError) as exc:
                _log.warning("France fuel feed parse failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            self._stations = tuple(stations)
            self._loaded_at = time.monotonic()
            _log.info(
                "France fuel dataset loaded: %d stations",
                len(self._stations),
            )
            return self._stations


def _parse_france(zbytes: bytes) -> list[_Station]:
    """Pure parse of the Roulez-Éco ZIP. Called from `to_thread`."""
    with zipfile.ZipFile(io.BytesIO(zbytes)) as zf:
        inner = zf.namelist()[0]
        xml_bytes = zf.read(inner)
    text = xml_bytes.decode("iso-8859-1", errors="replace")
    root = ET.fromstring(text)
    stations: list[_Station] = []
    for pdv in root.findall("pdv"):
        try:
            lat = int(pdv.get("latitude") or "0") / 100000.0
            lon = int(pdv.get("longitude") or "0") / 100000.0
        except ValueError:
            continue
        if lat == 0 and lon == 0:
            continue
        prices: dict[str, float] = {}
        for prix in pdv.findall("prix"):
            key = _FRANCE_PRICE_NAMES.get(prix.get("nom") or "")
            if not key:
                continue
            try:
                val = float(prix.get("valeur") or "0")
            except ValueError:
                continue
            if val > 0:
                prices[key] = val
        if not prices:
            continue
        city_el = pdv.find("ville")
        city = (city_el.text or "").strip() if city_el is not None else ""
        name = city.title() or f"Station {pdv.get('id')}"
        try:
            coord = Coordinate(lat=lat, lon=lon)
        except ValueError:
            continue
        stations.append(_Station(coord, name, None, prices))
    return stations


# --------------------------------------------------------------------
# Country: Italy (MITE — Ministero delle Imprese e del Made in Italy)
# --------------------------------------------------------------------

_ITALY_STATIONS_URL = (
    "https://www.mimit.gov.it/images/exportCSV/anagrafica_impianti_attivi.csv"
)
_ITALY_PRICES_URL = (
    "https://www.mimit.gov.it/images/exportCSV/prezzo_alle_8.csv"
)
_ITALY_FUEL_NAMES: dict[str, str] = {
    "Gasolio": "diesel",
    "Benzina": "sp95",
    "GPL": "lpg",
    "Metano": "cng",
}


class ItalyMimitFuelDataset:
    """12 h in-process cache of Italy's MITE fuel dataset.

    Two CSVs joined by `idImpianto`: a station registry with lat/lon
    and a per-fuel-type price feed. Both use `|` as separator and
    dot-decimal (unlike Spain).
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()
        self._stations: tuple[_Station, ...] = ()
        self._loaded_at: float = 0.0
        self._failed_at: float = 0.0
        self._lock = asyncio.Lock()

    async def stations(self) -> tuple[_Station, ...]:
        if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
            return self._stations
        if (
            self._failed_at
            and time.monotonic() - self._failed_at < _FAILURE_BACKOFF_S
        ):
            return self._stations
        async with self._lock:
            if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
                return self._stations
            try:
                registry_r, prices_r = await asyncio.gather(
                    self._client.get(_ITALY_STATIONS_URL),
                    self._client.get(_ITALY_PRICES_URL),
                )
                registry_r.raise_for_status()
                prices_r.raise_for_status()
            except httpx.HTTPError as exc:
                _log.warning("Italy fuel feed fetch failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations

            # Two CSVs, 22 k rows each — parse off-thread so the
            # asyncio loop stays free for /health and concurrent
            # requests.
            try:
                stations = await asyncio.to_thread(
                    _parse_italy, registry_r.text, prices_r.text,
                )
            except (ValueError, KeyError) as exc:
                _log.warning("Italy fuel feed parse failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            self._stations = tuple(stations)
            self._loaded_at = time.monotonic()
            _log.info(
                "Italy fuel dataset loaded: %d stations",
                len(self._stations),
            )
            return self._stations


def _parse_italy(registry_text: str, prices_text: str) -> list[_Station]:
    """Pure parse of the two MITE CSVs. Called from `to_thread`."""
    registry: dict[int, tuple[Coordinate, str, str | None]] = {}
    for row in _iter_csv(registry_text, header_lines=2, sep="|"):
        if len(row) < 10:
            continue
        try:
            id_impianto = int(row[0])
            lat = float(row[8])
            lon = float(row[9])
            coord = Coordinate(lat=lat, lon=lon)
        except (ValueError, IndexError):
            continue
        name = (row[4] or row[1] or "").strip().title() or "Stazione"
        brand = (row[2] or "").strip().title() or None
        registry[id_impianto] = (coord, name, brand)

    prices_by_id: dict[int, dict[str, float]] = {}
    for row in _iter_csv(prices_text, header_lines=2, sep="|"):
        if len(row) < 3:
            continue
        try:
            id_impianto = int(row[0])
            val = float(row[2])
        except ValueError:
            continue
        if val <= 0:
            continue
        key = _ITALY_FUEL_NAMES.get(row[1] or "")
        if not key:
            continue
        bucket = prices_by_id.setdefault(id_impianto, {})
        existing = bucket.get(key)
        if existing is None or val < existing:
            bucket[key] = val

    stations: list[_Station] = []
    for id_impianto, (coord, name, brand) in registry.items():
        prices = prices_by_id.get(id_impianto)
        if not prices:
            continue
        stations.append(_Station(coord, name, brand, prices))
    return stations


def _iter_csv(text: str, *, header_lines: int, sep: str):
    """Line-by-line CSV iterator that skips a fixed number of header
    lines. We avoid the `csv` module because both Italy files carry a
    non-standard "Estrazione del …" banner as the first line and a
    normal header on the second.
    """
    for i, line in enumerate(text.splitlines()):
        if i < header_lines:
            continue
        if not line.strip():
            continue
        yield line.split(sep)


# --------------------------------------------------------------------
# Country: Portugal (DGEG — Direção-Geral de Energia e Geologia)
# --------------------------------------------------------------------

_DGEG_URL = "https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PesquisarPostos"
# The DGEG API hard-caps results at 50 per page. With ~14 000 records
# (all fuel types combined, one row per station×fuel) we fetch all
# pages in parallel under a semaphore. A 12h TTL means this happens at
# most twice a day — acceptable for a government endpoint.
_DGEG_PAGE_SIZE = 50
# Maximum concurrent DGEG page requests. 10 keeps the VM IO-budget
# under control while still pulling all 280+ pages in under 30 s.
_DGEG_MAX_CONCURRENCY = 10

_DGEG_FUEL_NAMES: dict[str, str] = {
    "Gasóleo simples": "diesel",
    "Gasóleo especial": "diesel",          # premium diesel → same key, lower gets kept
    "Gasóleo colorido e marcado": None,    # agricultural/industrial, skip
    "Gasolina simples 95": "sp95",
    "Gasolina especial 95": "sp95",
    "Gasolina 98": "sp98",
    "Gasolina especial 98": "sp98",
    "GPL Auto": "lpg",
    "GNV": "cng",
    "Adblue": None,                        # additive, not a fuel
}


def _parse_pt_price(raw: str) -> float | None:
    """Parse DGEG price strings like '1,549 €' to float."""
    if not raw:
        return None
    raw = raw.replace("\xa0", " ").replace("€", "").replace(",", ".").strip()
    try:
        v = float(raw)
        return v if v > 0 else None
    except ValueError:
        return None


async def _dgeg_fetch_all_pages(client: httpx.AsyncClient) -> list[dict]:
    """Fetch the full DGEG dataset by paging through all records.

    First request probes the total count, then all remaining pages are
    fetched concurrently under a semaphore. Returns the raw JSON
    record list (one entry per station×fuel).
    """
    params_page1 = {"qtd": _DGEG_PAGE_SIZE, "pagina": 1}
    try:
        r = await client.get(_DGEG_URL, params=params_page1)
        r.raise_for_status()
        body = r.json()
    except (httpx.HTTPError, ValueError) as exc:
        _log.warning("DGEG Portugal: first-page fetch failed: %r", exc)
        return []

    records: list[dict] = list(body.get("resultado") or [])
    if not records:
        return records

    total: int = records[0].get("Quantidade", 0)
    if total <= _DGEG_PAGE_SIZE:
        return records

    n_pages = (total + _DGEG_PAGE_SIZE - 1) // _DGEG_PAGE_SIZE
    sem = asyncio.Semaphore(_DGEG_MAX_CONCURRENCY)

    async def _fetch_page(page: int) -> list[dict]:
        async with sem:
            try:
                resp = await client.get(
                    _DGEG_URL, params={"qtd": _DGEG_PAGE_SIZE, "pagina": page},
                )
                resp.raise_for_status()
                return list(resp.json().get("resultado") or [])
            except (httpx.HTTPError, ValueError) as exc:
                _log.debug("DGEG Portugal: page %d fetch failed: %r", page, exc)
                return []

    pages = await asyncio.gather(*[_fetch_page(p) for p in range(2, n_pages + 1)])
    for page_records in pages:
        records.extend(page_records)
    return records


def _parse_portugal(raw_records: list[dict]) -> list[_Station]:
    """Build _Station objects from the raw DGEG record list.

    Multiple rows per station (one per fuel type) are merged into a
    single _Station with a `prices` dict. When the same fuel key
    appears twice (e.g. 'Gasóleo simples' and 'Gasóleo especial' both
    map to 'diesel'), we keep the lower price — which is what the
    driver actually cares about.
    """
    by_id: dict[int, dict] = {}  # station_id → {coord, name, brand, prices}

    for entry in raw_records:
        station_id = entry.get("Id")
        if station_id is None:
            continue
        lat = entry.get("Latitude")
        lon = entry.get("Longitude")
        if lat is None or lon is None:
            continue
        try:
            lat = float(lat)
            lon = float(lon)
            coord = Coordinate(lat=lat, lon=lon)
        except (ValueError, TypeError):
            continue

        raw_price = entry.get("Preco") or ""
        price_val = _parse_pt_price(raw_price)
        if price_val is None:
            continue

        combustivel = entry.get("Combustivel") or ""
        fuel_key = _DGEG_FUEL_NAMES.get(combustivel)
        if fuel_key is None:
            continue

        if station_id not in by_id:
            name = (entry.get("Nome") or "").strip().title() or "Posto"
            brand = (entry.get("Marca") or "").strip().title() or None
            by_id[station_id] = {
                "coord": coord,
                "name": name,
                "brand": brand,
                "prices": {},
            }
        # Keep the lower price when the same key appears twice
        existing = by_id[station_id]["prices"].get(fuel_key)
        if existing is None or price_val < existing:
            by_id[station_id]["prices"][fuel_key] = price_val

    stations: list[_Station] = []
    for info in by_id.values():
        if not info["prices"]:
            continue
        stations.append(_Station(
            info["coord"], info["name"], info["brand"], info["prices"],
        ))
    return stations


class PortugalDGEGFuelDataset:
    """12 h in-process cache of Portugal's DGEG fuel dataset.

    The DGEG API (precoscombustiveis.dgeg.gov.pt) is a public
    government service — no API key required — that publishes current
    pump prices for every licensed station in Portugal. Records update
    when stations report new prices (typically daily).
    """

    def __init__(self, http_client: httpx.AsyncClient | None = None) -> None:
        self._client = http_client or _new_client()
        self._stations: tuple[_Station, ...] = ()
        self._loaded_at: float = 0.0
        self._failed_at: float = 0.0
        self._lock = asyncio.Lock()

    async def stations(self) -> tuple[_Station, ...]:
        if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
            return self._stations
        if (
            self._failed_at
            and time.monotonic() - self._failed_at < _FAILURE_BACKOFF_S
        ):
            return self._stations
        async with self._lock:
            if self._stations and time.monotonic() - self._loaded_at < _TTL_S:
                return self._stations
            try:
                raw_records = await _dgeg_fetch_all_pages(self._client)
            except Exception as exc:
                _log.warning("Portugal DGEG fuel dataset fetch failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            if not raw_records:
                _log.warning("Portugal DGEG fuel dataset: empty response")
                self._failed_at = time.monotonic()
                return self._stations
            try:
                stations = await asyncio.to_thread(_parse_portugal, raw_records)
            except Exception as exc:
                _log.warning("Portugal DGEG fuel dataset parse failed: %r", exc)
                self._failed_at = time.monotonic()
                return self._stations
            self._stations = tuple(stations)
            self._loaded_at = time.monotonic()
            _log.info(
                "Portugal DGEG fuel dataset loaded: %d stations",
                len(self._stations),
            )
            return self._stations


# --------------------------------------------------------------------
# Composite: dispatch by country detected on the route
# --------------------------------------------------------------------

_SPAIN = SpainMinisterioFuelDataset()
_FRANCE = FranceRoulezEcoFuelDataset()
_ITALY = ItalyMimitFuelDataset()
_PORTUGAL = PortugalDGEGFuelDataset()

# Countries for which we can quote real prices. Update whenever a new
# per-country dataset lands (next expected: Germany via Tankerkönig).
COVERED_COUNTRIES: frozenset[Country] = frozenset({
    Country.ES, Country.FR, Country.IT, Country.PT,
})


class GovFuelProvider:
    """FuelProvider backed by per-country public feeds.

    Selects datasets by `route.countries_crossed`. When the route
    doesn't cross any covered country (yet) the provider returns `()`
    and the caller can choose to hide the section or fall back to
    Nominatim (which has station coordinates but no prices).
    """

    async def prices_along(
        self, route: Route, *, fuel_type: str | None = None,
    ) -> tuple[FuelPrice, ...]:
        datasets: list[tuple[Country, SpainMinisterioFuelDataset
                              | FranceRoulezEcoFuelDataset
                              | ItalyMimitFuelDataset
                              | PortugalDGEGFuelDataset]] = []
        for c in route.countries_crossed or ():
            if c is Country.ES:
                datasets.append((c, _SPAIN))
            elif c is Country.FR:
                datasets.append((c, _FRANCE))
            elif c is Country.IT:
                datasets.append((c, _ITALY))
            elif c is Country.PT:
                datasets.append((c, _PORTUGAL))
        # No fallback here: previously we tried all three datasets when
        # `countries_crossed` was empty, which fired 3 concurrent 15 MB
        # downloads + CSV parses and OOM/CPU-starved the single-vCPU
        # Fly VM enough that the health check died. Empty result is
        # honest and lets the `HybridFuelProvider` above degrade to
        # Nominatim (station names without prices).

        # Sample the route geometry ONCE upfront. Iterating the full
        # ~2600-point OSRM polyline against 11k Spanish stations used
        # to burn ~28 seconds of synchronous CPU on the event loop.
        reference = _route_reference_points(route)

        # Do the whole per-station distance loop off-thread. Even at
        # 60 sample points × ~30k stations (ES+FR+IT combined) the
        # inner haversine loop is CPU-bound Python; keeping it out of
        # the event loop protects concurrent requests and the health
        # check probe.
        gathered: list[tuple[Country, tuple[_Station, ...]]] = []
        for country, ds in datasets:
            stations = await ds.stations()
            gathered.append((country, stations))

        _pref = fuel_type

        def _filter_and_dedupe() -> list[FuelPrice]:
            seen_coords: set[tuple[int, int]] = set()
            per_country: dict[str, list[FuelPrice]] = {}
            for country, stations in gathered:
                bucket = per_country.setdefault(country.value, [])
                for st in stations:
                    distance_km = _distance_to_points(st.coord, reference)
                    if distance_km > _MAX_OFF_CORRIDOR_KM:
                        continue
                    key = (
                        round(st.coord.lat * 10000),
                        round(st.coord.lon * 10000),
                    )
                    if key in seen_coords:
                        continue
                    seen_coords.add(key)
                    fp = _station_to_fuel_price(
                        st, route, distance_km, country,
                        preferred_fuel=_pref,
                    )
                    if fp is not None:
                        bucket.append(fp)
            # Per-country cap: sample EVENLY along each country's leg
            # instead of taking the first-N-by-distance. The naive
            # `sort by distance asc then [:N]` dropped the entire tail
            # of every long leg — on Madrid→Rome, only Spanish
            # stations in the first ~100 km survived because Spain
            # alone had 800+ corridor stations. Even sampling
            # preserves the far end of each leg so the downstream
            # bucketed curator has candidates in every km segment.
            out: list[FuelPrice] = []
            for bucket in per_country.values():
                bucket.sort(key=lambda p: p.distance_from_origin_km)
                if len(bucket) <= _PER_COUNTRY_RAW_CAP:
                    out.extend(bucket)
                    continue
                step = len(bucket) / _PER_COUNTRY_RAW_CAP
                sampled = [
                    bucket[int(i * step)]
                    for i in range(_PER_COUNTRY_RAW_CAP)
                ]
                out.extend(sampled)
            return out

        result = await asyncio.to_thread(_filter_and_dedupe)
        return tuple(result)

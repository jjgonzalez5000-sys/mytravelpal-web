"""Public attributions catalogue.

Serves the same list documented in `docs/attributions.md` as a
machine-readable JSON so the mobile app renders it without a rebuild
every time we add a source. Grouping is coarse (data vs code vs
weather) — the client uses `group` to render collapsible sections.

Compliance obligations that MUST match the corresponding rendering:
- `attribution_required=True` means the source's licence requires the
  attribution text to appear wherever the data is *shown*, not just in
  this catalogue. Enforce at the render site (map overlay, list
  footer) as well.
"""

from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/attributions", tags=["attributions"])


class Attribution(BaseModel):
    id: str
    group: str
    name: str
    description: str
    license: str
    attribution_text: str
    attribution_required: bool = False
    url: str | None = None


class AttributionList(BaseModel):
    items: list[Attribution] = Field(default_factory=list)
    version: str = "1"


_ATTRIBUTIONS: tuple[Attribution, ...] = (
    Attribution(
        id="osm",
        group="map",
        name="OpenStreetMap contributors",
        description=(
            "Map tiles, POI data, geocoding and routing base map."
        ),
        license="ODbL 1.0",
        attribution_text="© OpenStreetMap contributors",
        attribution_required=True,
        url="https://www.openstreetmap.org/copyright",
    ),
    Attribution(
        id="nominatim",
        group="map",
        name="Nominatim (OSM Foundation)",
        description=(
            "Geocoding, reverse geocoding, and POI discovery along the "
            "route (hotels, restaurants, fuel stations)."
        ),
        license="ODbL 1.0 (downstream of OSM)",
        attribution_text="Geocoding: Nominatim / © OpenStreetMap contributors",
        attribution_required=True,
        url="https://operations.osmfoundation.org/policies/nominatim/",
    ),
    Attribution(
        id="osrm",
        group="map",
        name="OSRM (Open Source Routing Machine)",
        description="Route computation on OSM road geometry.",
        license="BSD-2-Clause (software) / ODbL 1.0 (data)",
        attribution_text="Routing: Project OSRM / © OpenStreetMap contributors",
        attribution_required=False,
        url="https://project-osrm.org/",
    ),
    Attribution(
        id="fuel-es",
        group="fuel",
        name="Ministerio para la Transición Ecológica (España)",
        description=(
            "Real fuel prices for every Spanish service station, "
            "updated daily."
        ),
        license="Spanish public sector reuse (Ley 37/2007)",
        attribution_text=(
            "Precios: Ministerio para la Transición Ecológica y el "
            "Reto Demográfico (España)"
        ),
        attribution_required=False,
        url=(
            "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
            "PreciosCarburantes/EstacionesTerrestres/"
        ),
    ),
    Attribution(
        id="fuel-fr",
        group="fuel",
        name="Roulez-Éco / prix-carburants (France)",
        description="Real-time fuel prices for every French station.",
        license="Licence Ouverte / Open Licence (Etalab) v2.0",
        attribution_text=(
            "Prix : data.gouv.fr / Ministère de l'Économie – "
            "prix-carburants.gouv.fr"
        ),
        attribution_required=True,
        url="https://donnees.roulez-eco.fr/",
    ),
    Attribution(
        id="fuel-it",
        group="fuel",
        name="MIMIT — Osservaprezzi Carburanti (Italia)",
        description=(
            "Fuel prices for every Italian station reported to the "
            "Osservaprezzi system, updated daily."
        ),
        license="IODL 2.0 / CC-BY 4.0",
        attribution_text=(
            "Prezzi carburanti: Ministero delle Imprese e del Made in "
            "Italy — Osservaprezzi Carburanti"
        ),
        attribution_required=True,
        url="https://www.mimit.gov.it/it/open-data",
    ),
    Attribution(
        id="firms",
        group="hazards",
        name="NASA FIRMS",
        description="Active wildfire hotspots along the route.",
        license="NASA data policy — free public use",
        attribution_text=(
            "Fire data: NASA FIRMS "
            "(https://firms.modaps.eosdis.nasa.gov/)"
        ),
        attribution_required=False,
        url="https://firms.modaps.eosdis.nasa.gov/",
    ),
    Attribution(
        id="open-meteo",
        group="weather",
        name="Open-Meteo",
        description=(
            "Hour-level weather forecasts for departure-window scoring "
            "(underlying data from DWD, Météo-France, AEMET, Met Office)."
        ),
        license="CC-BY 4.0",
        attribution_text="Weather: Open-Meteo.com",
        attribution_required=True,
        url="https://open-meteo.com/",
    ),
    Attribution(
        id="flutter-oss",
        group="software",
        name="Flutter & Dart open-source packages",
        description=(
            "The mobile app uses many third-party packages under BSD, "
            "MIT and Apache-2.0 licences. The complete list is shown "
            "in the app under Settings → Licenses & data."
        ),
        license="BSD / MIT / Apache-2.0 (per package)",
        attribution_text=(
            "Open-source packages listed under Settings → Licenses & data."
        ),
        attribution_required=False,
        url="https://pub.dev/",
    ),
)


@router.get("", response_model=AttributionList)
async def list_attributions() -> AttributionList:
    """Return every data source and OSS library the app depends on.

    Grouped by `group` (`map`, `fuel`, `hazards`, `weather`,
    `software`). The client should render `attribution_text` verbatim
    in a Settings screen — items with `attribution_required=True` must
    also appear near the rendered data (e.g. OSM overlay on the map).
    """
    return AttributionList(items=list(_ATTRIBUTIONS))

"""Copernicus EMS (Emergency Management Service) — landslide + avalanche stub.

Copernicus EMS Rapid Mapping publishes activation-based products (each
"activation" corresponds to a declared emergency: floods, wildfires,
landslides, avalanches, etc.). The public catalog is browsable at:

    https://emergency.copernicus.eu/mapping/list-of-activations-rapid

There's no continuous JSON/GeoJSON polling endpoint like USGS for
earthquakes — activations are discrete, low frequency, and the
metadata sits behind an interactive portal + RSS. A production
integration needs one of:

- Parsing the RSS feed at
  `https://emergency.copernicus.eu/mapping/backend/rss/all/all/all`
  and geocoding the "location" text.
- Signing up for the Copernicus EMS mailing list webhook (asks for
  organisation affiliation).

Until either is wired, this provider returns `()` and logs once at
startup so operators know why landslide / avalanche never appear
from an "official" source. User-marked events (`AdverseEventSource.USER`)
still surface those types through `UserMarkedAdverseEventsProvider`.
"""

from __future__ import annotations

import logging
from datetime import datetime

from app.domain import AdverseEvent, Route

_log = logging.getLogger(__name__)


class CopernicusEmsProvider:
    """Stub — emits nothing until we wire the RSS or the webhook."""

    _NAME = "Copernicus EMS"
    _logged = False

    async def events_along(
        self, route: Route, *, now: datetime,  # noqa: ARG002
    ) -> tuple[AdverseEvent, ...]:
        if not CopernicusEmsProvider._logged:
            _log.info(
                "Copernicus EMS not yet wired (landslide/avalanche will only "
                "surface via user-marked events)",
            )
            CopernicusEmsProvider._logged = True
        return ()

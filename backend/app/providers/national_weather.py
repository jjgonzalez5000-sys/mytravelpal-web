"""National weather feeds — placeholders for country-specific extensions.

Open-Meteo (`providers/weather.OpenMeteoWeatherProvider`) already covers
all 30 supported countries with unified data, so these providers exist
mainly as extension slots: some national services (AEMET for Spain,
Météo-France for France, DWD for Germany, MET Office for the UK) publish
*advisories* — human-authored warnings for storms, snow, floods — that
Open-Meteo's model output doesn't include.

They're implemented as `AdverseEventsProvider` stubs that require an
API key each and simply return an empty tuple when unconfigured. When
we contract each service, the real client body goes in the `_fetch`
method; the composite already wires them in when their env var is set.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime

from app.domain import AdverseEvent, Route

_log = logging.getLogger(__name__)


class _StubWeatherProvider:
    """Base implementation that returns nothing when unconfigured."""

    _ENV_KEY: str = ""
    _NAME: str = ""

    def __init__(self) -> None:
        self._api_key = os.environ.get(self._ENV_KEY, "").strip()

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    async def events_along(
        self, route: Route, *, now: datetime,
    ) -> tuple[AdverseEvent, ...]:  # noqa: ARG002
        if not self.configured:
            return ()
        # Real integration slots in here.
        _log.info("%s configured but no client wired yet", self._NAME)
        return ()


class AemetWeatherProvider(_StubWeatherProvider):
    """AEMET — Spain's national meteorology service.

    https://opendata.aemet.es/  (free API, requires an application key).
    """

    _ENV_KEY = "AEMET_API_KEY"
    _NAME = "AEMET"


class MeteoFranceWeatherProvider(_StubWeatherProvider):
    """Météo-France public warnings feed.

    https://donneespubliques.meteofrance.fr/  (free, application key).
    """

    _ENV_KEY = "METEOFRANCE_API_KEY"
    _NAME = "Météo-France"


class DwdWeatherProvider(_StubWeatherProvider):
    """Deutscher Wetterdienst (Germany) warnings feed.

    https://www.dwd.de/DE/leistungen/opendata/opendata.html
    """

    _ENV_KEY = "DWD_API_KEY"
    _NAME = "DWD"


class MetOfficeWeatherProvider(_StubWeatherProvider):
    """UK Met Office DataPoint warnings feed."""

    _ENV_KEY = "MET_OFFICE_API_KEY"
    _NAME = "Met Office"

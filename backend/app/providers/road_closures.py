"""Road closure feeds — stub for national road authority integrations.

Each country publishes its own feed (format, frequency, auth), so a
production integration is a per-country adapter fan-out rather than a
single provider. Known feeds:

- ES: DGT `https://infocar.dgt.es/etraffic/` (public JSON, ~5 min refresh).
- FR: DIRIF / Bison Futé `https://www.bison-fute.gouv.fr/donnees-libres.html`
  (open data portal, per-region ZIPs).
- IT: ANAS `https://www.stradeanas.it/it/traffico` (HTML, needs scraping).
- DE: MDM Mobilitäts Daten Marktplatz (DATEX II XML, requires free registration).
- Unified: DATEX II across EU corridors via NAP (National Access Points).

MVP: stub that returns `()`. User-marked closures still surface via
`UserMarkedAdverseEventsProvider`, and the mock provider carries one
demo closure so end-to-end rendering can be verified without keys.
"""

from __future__ import annotations

import logging
from datetime import datetime

from app.domain import AdverseEvent, Route

_log = logging.getLogger(__name__)


class RoadClosureProvider:
    """Stub — real per-country adapters land in a follow-up sprint."""

    _NAME = "Road closures"
    _logged = False

    async def events_along(
        self, route: Route, *, now: datetime,  # noqa: ARG002
    ) -> tuple[AdverseEvent, ...]:
        if not RoadClosureProvider._logged:
            _log.info(
                "Road-closure provider not yet wired (DGT/DIRIF/ANAS/DATEX II)",
            )
            RoadClosureProvider._logged = True
        return ()

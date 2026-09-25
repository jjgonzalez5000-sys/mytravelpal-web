"""Heatwave provider — synthesizes HEATWAVE events from Open-Meteo daily max.

Thin `AdverseEventsProvider` adapter over the helper in
`app.services.weather_summary.heatwave_events_along_route`. The helper
lives in the services layer because it reuses the same route-sampling
and Open-Meteo plumbing as the friendly forecast strip; this module
just satisfies the provider protocol so the composite can wire it.

`now` is used as the departure timestamp — Open-Meteo daily windows
are dates, so hour precision doesn't matter for the heatwave
threshold check.

Enable with `MYTRAVELPAL_HEATWAVE=on` (off by default to avoid the
extra Open-Meteo round-trip on every /plan call).
"""

from __future__ import annotations

from datetime import datetime

import httpx

from app.domain import AdverseEvent, Route
from app.services.weather_summary import heatwave_events_along_route


class HeatwaveProvider:
    """Emit HEATWAVE `AdverseEvent`s along the route from Open-Meteo daily max."""

    def __init__(
        self,
        http_client: httpx.AsyncClient | None = None,
        *,
        threshold_c: float = 38.0,
    ) -> None:
        self._client = http_client or httpx.AsyncClient(timeout=6.0)
        self._threshold_c = threshold_c

    async def events_along(
        self, route: Route, *, now: datetime,
    ) -> tuple[AdverseEvent, ...]:
        return await heatwave_events_along_route(
            route,
            departure_at=now,
            client=self._client,
            threshold_c=self._threshold_c,
        )

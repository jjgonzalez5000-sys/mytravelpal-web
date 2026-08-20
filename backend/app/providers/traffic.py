from __future__ import annotations

from datetime import datetime
from typing import Protocol

from app.domain import Country, Route


class TrafficProvider(Protocol):
    async def factor_at(self, route: Route, when: datetime) -> float:
        """Return a multiplier applied to free-flow duration at `when`.

        1.0 = free flow. > 1.0 = slower than free flow. Real historic
        providers (HERE Traffic Stats, TomTom Traffic Stats) return exactly
        this shape aggregated per road segment; we return one factor for the
        whole route in the MVP.
        """
        ...


# Weekday hour-of-day multipliers per country. Chosen to be plausible for
# European motorway traffic patterns — peaks around 07-09 and 17-19.
_WEEKDAY_PROFILE: dict[Country, tuple[float, ...]] = {
    Country.FR: (
        1.00, 1.00, 1.00, 1.00, 1.00, 1.05,
        1.20, 1.55, 1.65, 1.35, 1.10, 1.05,
        1.10, 1.05, 1.05, 1.10, 1.30, 1.60,
        1.70, 1.40, 1.15, 1.05, 1.00, 1.00,
    ),
    Country.IT: (
        1.00, 1.00, 1.00, 1.00, 1.00, 1.05,
        1.15, 1.50, 1.60, 1.30, 1.10, 1.05,
        1.15, 1.10, 1.05, 1.10, 1.25, 1.55,
        1.65, 1.35, 1.15, 1.05, 1.00, 1.00,
    ),
    Country.ES: (
        1.00, 1.00, 1.00, 1.00, 1.00, 1.05,
        1.15, 1.45, 1.55, 1.30, 1.10, 1.05,
        1.10, 1.10, 1.05, 1.10, 1.25, 1.50,
        1.65, 1.45, 1.20, 1.10, 1.05, 1.00,
    ),
    Country.CH: (
        1.00, 1.00, 1.00, 1.00, 1.00, 1.10,
        1.30, 1.60, 1.55, 1.20, 1.05, 1.05,
        1.10, 1.05, 1.05, 1.10, 1.35, 1.65,
        1.60, 1.25, 1.10, 1.05, 1.00, 1.00,
    ),
}


class MockTrafficProvider:
    """Deterministic historic-traffic mock.

    Combines per-country weekday profiles above with a weekend dampening.
    Same inputs → same outputs.
    """

    _WEEKEND_DAMPENING = 0.6  # weekend peaks are ~60% of weekday peaks

    async def factor_at(self, route: Route, when: datetime) -> float:
        hour = when.hour
        is_weekend = when.weekday() >= 5

        factors = []
        for country in route.countries_crossed:
            profile = _WEEKDAY_PROFILE.get(country)
            if profile is None:
                factors.append(1.0)
                continue
            base = profile[hour]
            if is_weekend:
                # pull toward 1.0 by the dampening amount
                base = 1.0 + (base - 1.0) * self._WEEKEND_DAMPENING
            factors.append(base)

        # If the route crosses multiple countries, take the worst factor —
        # real HERE Traffic Stats aggregates per segment; this is our coarse
        # MVP approximation.
        return max(factors) if factors else 1.0

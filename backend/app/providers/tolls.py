from __future__ import annotations

from typing import Protocol

from app.domain import Route


class TollsProvider(Protocol):
    async def cost_eur(self, route: Route) -> float: ...


class MockTollsProvider:
    """Mock toll provider. Returns the toll_cost_eur already computed by
    the routing mock. A real TollGuru integration will recompute per
    vehicle class, discounts, subscriptions, etc.
    """

    async def cost_eur(self, route: Route) -> float:
        return route.toll_cost_eur

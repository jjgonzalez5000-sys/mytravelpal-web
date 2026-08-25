"""Compute alternative route variants for a side-by-side comparison.

Given the primary route (the one the plan endpoint already computed),
this service asks the routing provider for the same origin/destination
under different constraints so the driver can see them together on
`ResultScreen`. Deliberately kept to three named variants — comparing
more would overwhelm the UI without adding decision value:

- **fastest** — the default (usually via motorway with tolls). Emitted
  by echoing the primary route.
- **toll_free** — `avoid_tolls=True`. Saves money at the cost of time.
- **scenic** — `prefer_scenic=True`. Slower but nicer roads.

The service is a thin orchestrator; each variant delegates to the
existing `RoutingProvider.route()`.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain import Coordinate, Country, Route
from app.providers.routing import RoutingProvider


@dataclass(frozen=True, slots=True)
class RouteVariant:
    """One row of the comparison table."""
    key: str                # "fastest" | "toll_free" | "scenic"
    label: str
    route: Route


_VARIANTS: tuple[tuple[str, str, dict[str, bool]], ...] = (
    ("toll_free", "Toll-free", {"avoid_tolls": True}),
    ("scenic", "Scenic", {"prefer_scenic": True}),
)


async def compute_variants(
    *,
    provider: RoutingProvider,
    primary: Route,
    origin: Coordinate,
    destination: Coordinate,
    countries: tuple[Country, ...] | None,
) -> tuple[RouteVariant, ...]:
    """Return the 3-variant comparison for a trip.

    The primary route is echoed as `fastest` (no extra provider call).
    The other two variants each cost one extra `RoutingProvider.route()`
    call — acceptable because the endpoint only computes them when the
    client opts in with `include_route_comparison`.
    """
    out: list[RouteVariant] = [
        RouteVariant(key="fastest", label="Fastest", route=primary),
    ]
    for key, label, kwargs in _VARIANTS:
        alt = await provider.route(origin, destination, countries, **kwargs)
        out.append(RouteVariant(key=key, label=label, route=alt))
    return tuple(out)

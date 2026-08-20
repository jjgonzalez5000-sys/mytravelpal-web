# Mock Data Strategy

External data providers are expensive and slow to contract. The MVP ships
with deterministic mock implementations that behave like the real thing so
we can build and demo the product end-to-end without them.

## Rules

1. **Every provider is an interface.** Real and mock implementations live
   side by side. Consumers never import mocks directly — they depend on the
   `Provider` protocol and get an instance from the DI factory.
2. **Mocks are deterministic.** Same inputs → same outputs. Randomness is
   seeded from the input (e.g. origin/destination hash) so calling twice
   returns identical data. This makes tests reproducible and demos honest.
3. **Mocks look realistic per country.** Toll costs, fuel prices, and traffic
   patterns should be roughly plausible for CH, FR, IT, ES respectively —
   not identical placeholder values.
4. **Mocks simulate the shape of real APIs.** A `MockRoutingProvider` returns
   the same fields a real HERE Routing v8 response would populate (distance,
   duration, geometry as a polyline). Swap to `HereRoutingProvider` later
   without touching callers.

## Traffic model (mock)

Historic travel-time factor per hour of day, per country. Weekday morning
and evening rush hours get a multiplier > 1.0 applied to the free-flow
duration returned by routing. Weekends and off-peak hours stay near 1.0.

The mock is intentionally coarse — the goal is to demonstrate the
optimal-window algorithm, not to predict real traffic. Real HERE Traffic
Stats data slots in behind the same interface later.

## Swapping to a real provider

1. Add a new class next to the mock (e.g. `HereRoutingProvider`).
2. Add its config to `settings` (API key, base URL).
3. Wire it in the DI factory behind a country flag or a feature flag so we
   can roll out per market.
4. Delete the mock **only** when the real provider covers all four launch
   countries with production-quality data.

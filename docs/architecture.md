# Architecture

## Goal

MyTravelPal helps drivers **plan** road trips better than Google Maps / Waze /
Sygic. The MVP focuses on pre-trip planning only — no live turn-by-turn
navigation. See [MVP Scope](mvp_scope.md).

## System components (MVP)

```
+---------------------+         +-------------------------+
|  Flutter app        |  HTTPS  |  FastAPI backend        |
|  (iOS + Android)    +-------->+  /v1/trips/plan         |
+---------------------+         |                         |
                                |  services/              |
                                |    time_window          |  <-- killer feature
                                |                         |
                                |  providers/             |
                                |    routing              |
                                |    traffic (historic)   |
                                |    tolls                |
                                |    fuel                 |
                                +-----------+-------------+
                                            |
                                            v
                                +-------------------------+
                                |  Postgres + PostGIS     |
                                |  Redis (cache)          |
                                +-------------------------+
```

## Key design decisions

### 1. Provider abstraction, mocks first

Every external data source (routing, traffic, tolls, fuel prices) lives behind
a `Provider` interface in `backend/app/providers/`. The MVP ships with mock
implementations that return realistic-looking data for the four launch
countries (CH, FR, IT, ES). When we contract HERE / TomTom / TollGuru / etc.,
we add a real implementation next to the mock and swap it via configuration.

Consumers (services, API handlers) only depend on the interface. See
[mock_data_strategy.md](mock_data_strategy.md).

### 2. Time-window optimization lives in a service, not an endpoint

The differentiating logic — "when should I leave to minimize travel time?" —
lives in `backend/app/services/time_window.py`. The `/v1/trips/plan` endpoint
is a thin wrapper. This keeps the algorithm testable in isolation and lets us
reuse it later for group planning, notifications, etc.

### 3. Domain entities are pure

`backend/app/domain/` holds plain dataclasses (`Trip`, `Route`, `TimeWindow`,
`Coordinate`). No ORM, no framework imports. This makes the core business
logic trivially unit-testable.

### 4. Launch markets

CH, FR, IT, ES — chosen for the MVP. Country is a first-class parameter on
every provider call so mock data can differ per country (e.g. Swiss vignette
vs. French toll-per-km) and so we can gate real-provider rollout country by
country.

## Non-goals for the MVP

- Live turn-by-turn navigation.
- Real traffic data — mocked.
- Authentication / user accounts — anonymous trip planning first.
- Payments / freemium gating — comes after product-market fit.
- Bookings, AR, gamification, social features — post-MVP.

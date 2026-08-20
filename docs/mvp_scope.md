# MVP Scope

## In scope

- **Trip planning API** — `POST /v1/trips/plan` takes an origin, destination,
  desired departure time, and returns a suggested route plus **optimal
  departure windows**.
- **Optimal-departure-window computation** — the differentiator. Given a
  ±3-hour range around the desired departure, sample travel time at 30-minute
  intervals using historic traffic data and return the top-N windows.
- **Provider abstraction** for routing, traffic (historic), tolls, and fuel
  prices, with **mock implementations** for CH, FR, IT, ES.
- **Flutter app** (next sprint) — planning screen, results screen with map and
  a "best time to leave" chart, saved trips.
- **Local dev environment** via `docker compose up`.

## Out of scope (MVP)

- Turn-by-turn navigation.
- Real routing / traffic / tolls / fuel providers (HERE, TomTom, TollGuru,
  etc.) — behind flags; still mocked in the MVP.
- User accounts, social login, sharing.
- Payments and freemium gating.
- Bookings (hotels, restaurants, EV charging reservations).
- Group planning, gamification, AR, autonomous vehicles.
- Countries other than CH, FR, IT, ES.

## Success criteria for Sprint 1 (backend only)

1. `docker compose up` boots api + postgres + redis in one command.
2. `POST /v1/trips/plan` returns a valid response with mock data for any
   origin/destination in the four launch countries.
3. The returned `timeWindows` list is sorted by estimated travel time
   ascending, with the top window flagged `recommended: true`.
4. Unit tests cover `time_window` service: window ordering, tie-breaking,
   edge cases (window equal to desired time, all windows identical).

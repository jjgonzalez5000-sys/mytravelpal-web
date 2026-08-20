# Sprint history

Chronological summaries of the work delivered in each sprint. Written at
sprint close, not updated retroactively — the source-of-truth for current
state is the code, [architecture.md](architecture.md), and
[mvp_scope.md](mvp_scope.md).

---

## Sprint 1 — Backend vertical slice

**Goal:** stand up a working `POST /v1/trips/plan` end-to-end with mocked
external providers, so the differentiator (optimal-departure-window
computation) can be demoed with `curl` before any UI exists.

**Delivered**

- FastAPI backend under [backend/app/](../backend/app/) with:
  - Pure-dataclass domain entities ([domain/entities.py](../backend/app/domain/entities.py)):
    `Coordinate`, `Country`, `Route`, `TimeWindow`, `Trip`, `TripPlan`.
  - Provider protocols and deterministic mocks for **routing**, **historic
    traffic**, **tolls**, and **fuel** ([providers/](../backend/app/providers/)).
    Every consumer depends on the protocol; real HERE/TomTom/TollGuru
    integrations slot in later without touching callers.
  - `time_window` service ([services/time_window.py](../backend/app/services/time_window.py))
    — the killer feature. Samples travel time in a ±3h window at 30-minute
    intervals, sorts by total duration ascending, breaks ties by proximity
    to the desired time, flags the top result `recommended`.
  - `POST /v1/trips/plan` endpoint returning route, top-N time windows,
    and fuel prices along the route.
- `docker compose up` local environment: Postgres+PostGIS, Redis, API
  ([backend/docker-compose.yml](../backend/docker-compose.yml)).
- Initial docs: [architecture.md](architecture.md),
  [mvp_scope.md](mvp_scope.md), [mock_data_strategy.md](mock_data_strategy.md).
- Root [README.md](../README.md) with quickstart.

**Validation**

- 16/16 backend tests passing (unit + API).
- Smoke test: Paris→Madrid returns 1316 km, best window at 05:30 h (avoids
  rush hour), tolls ~210 €, mixed FR/ES fuel stations.

**Deliberately out**

- Turn-by-turn navigation, real provider integrations, user accounts,
  payments, persistence beyond schema, and mobile client — all deferred.

---

## Sprint 2 — Flutter app (planning UI)

**Goal:** put the planning flow in front of a user. A Flutter app that
calls the Sprint-1 backend and visualizes the plan.

**Delivered**

- Cross-platform Flutter app under [mobile/](../mobile/) targeting iOS +
  Android (cross-platform chosen over native to avoid 2× codebase cost
  during a pre-navigation MVP).
- API layer ([lib/api/](../mobile/lib/api/)): DTOs mirroring the backend
  contract, HTTP client with `planTrip()`, base URL from
  `--dart-define=API_BASE_URL`.
- Screens:
  - `PlanScreen` — form for origin/destination lat-lon, countries
    (manual FilterChips at this point), and desired departure via
    date+time pickers.
  - `ResultScreen` — MapLibre map (free OpenFreeMap tiles), summary row
    (distance / free-flow / tolls), "best time to leave" card, bar chart
    of candidate departure windows, list of fuel stations.
- Widgets: `TimeWindowChart` (fl_chart bar chart with recommended slot
  highlighted), `RouteMap`, `CountrySelector` (removed in Sprint 3).
- Material 3 theme, light + dark, seeded from a brand blue.
- Riverpod `ProviderScope` for DI (`ApiClient`).
- Tests for models, API client (with `MockClient`), and the country
  selector widget.

**Validation**

- Flutter was not installed on the development machine during Sprint 2;
  code written blind against the SDK. Sprint 3 later verified it with
  `flutter analyze` (clean) and `flutter test` (all passing).

**Deliberately out**

- No geocoding — users had to enter raw lat/lon.
- No local persistence, no auth, no push notifications.

---

## Sprint 3 — Geocoding, country auto-detection, chart polish

**Goal:** kill the "enter raw coordinates and pick countries manually"
friction from the Sprint-2 UX, and make the chart tell a story instead
of just showing numbers.

**Delivered — backend**

- New `GeocodingProvider` protocol + deterministic
  `MockGeocodingProvider` with ~30 major cities across CH/FR/IT/ES
  ([providers/geocoding.py](../backend/app/providers/geocoding.py)).
  Case-insensitive, prefix-matches rank first.
- Country auto-detection service
  ([services/country_detection.py](../backend/app/services/country_detection.py))
  using axis-aligned bounding boxes per launch country. Overlap
  precedence: CH → ES → IT → FR (smaller countries win at borders).
- New endpoint `GET /v1/geocode?q=&limit=`
  ([api/v1/geocode.py](../backend/app/api/v1/geocode.py)).
- `POST /v1/trips/plan`: `countries` is now optional; when omitted, the
  backend infers it from origin + destination.

**Delivered — mobile**

- `GeocodeResult` model and `ApiClient.geocode()` method.
- `LocationSearchField` widget replacing manual lat/lon input — Material
  3 `SearchAnchor` with 250 ms debounce; the user searches "Barcelona",
  picks from the dropdown, coordinate and country are locked in.
- `PlanScreen` rewritten around the two search fields; country selector
  removed (backend infers now). Both `CountrySelector` and its test
  deleted as unused.
- `ResultScreen`: header shows the two chosen city names, detected
  countries appear as chips, and the recommendation card now surfaces
  the *shift* from the user's desired time ("2h 30m earlier from your
  desired time · +41 vs free flow").
- `TimeWindowChart`: the bar nearest the user's desired time is outlined
  and its axis label is bold, so users can visually compare "what I
  wanted" vs "what the app recommends" at a glance.

**Validation**

- Backend: 29/29 tests passing (16 previous + 13 new: geocoding,
  country detection, `/geocode` endpoint, auto-detect on `/plan`).
- Backend smoke test: Milano→Madrid without `countries` auto-detects
  `["IT", "ES"]`; `/v1/geocode?q=bar` returns Barcelona first.
- Mobile: `flutter analyze` clean, `flutter test` 10/10 passing.

**Deliberately out**

- Only origin + destination are checked for country detection — a route
  that passes through a country not adjacent to either endpoint (e.g.
  Milano→Madrid through France) will miss that intermediate country
  until we get real polyline geometry. Deferred to a future sprint.
- No local persistence yet.
- Fuel prices are still fully mocked; no real provider integration.

---

## Sprint 4 — Waypoint-aware country detection + saved trips

**Goal:** close the "intermediate country" gap flagged at the end of
Sprint 3, and let users keep trips they care about across sessions.

**Delivered — backend**

- `Route` domain entity now carries `waypoints: tuple[Coordinate, ...]`
  ([domain/entities.py](../backend/app/domain/entities.py)).
- `MockRoutingProvider` interpolates 10 evenly-spaced points along the
  great circle between origin and destination
  ([providers/routing.py](../backend/app/providers/routing.py)).
- `RoutingProvider.route()` signature changed: `countries` is now an
  optional override; when omitted, the provider itself infers countries
  from `(origin, *waypoints, destination)` via the country-detection
  service. This moved the "which countries does this route cross" answer
  behind the routing interface where it belongs.
- `POST /v1/trips/plan` simplified accordingly — it no longer duplicates
  inference logic, just passes `countries_override` through.
- Milano→Madrid now correctly returns `["IT", "FR", "ES"]`.

**Delivered — mobile**

- `SavedTrip` model + `TripStorage` service under
  [lib/storage/](../mobile/lib/storage/), backed by `shared_preferences`
  (chosen over `sqflite` for MVP simplicity and free testability via
  `SharedPreferences.setMockInitialValues`). Storage caps at 100 entries,
  newest-first, dedupes by trip id (origin|destination|desired-time).
- `tripStorageProvider` (Riverpod), overridden at boot from `main.dart`
  with the singleton instance so the async open completes before any
  screen builds.
- `ResultScreen` — Save action in the AppBar, disables and swaps its
  icon after save, confirms with a SnackBar.
- New `HistoryScreen` — list of saved trips (newest first), each tile
  shows route + distance + best-departure time + when it was wanted;
  tap re-plans by hitting the backend again with the same request;
  delete button removes the entry. Empty state guides new users to the
  bookmark action. Reached from an icon in `PlanScreen`'s AppBar.

**Validation**

- Backend: 35/35 tests passing (29 previous + 6 new: great-circle
  interpolation shape, waypoint population on the mock, intermediate
  country detection Milano→Madrid, and endpoint-override precedence).
- Mobile: `flutter analyze` clean, `flutter test` 20/20 passing
  (previous 10 + roundtrip and ordering for `TripStorage`, plus three
  widget tests for `HistoryScreen`: empty state, rendering, delete).

**Deliberately out**

- No real fuel provider yet (Spain's public API is the natural next
  target since it's free and public; deferred to Sprint 5 to keep this
  sprint focused on internal correctness + UX).
- Saved-trip re-plan re-hits the backend rather than caching the last
  response — deliberate, so users see fresh traffic data when they
  reopen a trip.
- Waypoints are still great-circle approximations; a real router will
  give us actual road geometry and much more accurate country crossings
  (relevant for e.g. detecting a brief Andorran detour).

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

---

## Sprint 5 — Hotels + Nominatim geocoding fallback + web target

**Goal:** three interleaved shifts — (1) unblock the "small town" search
gap the user hit while testing (Unterägeri wasn't in the mock catalogue),
(2) add a first "add-on" filter to the plan (hotels along the route),
and (3) make the app runnable in a browser so we could actually see it
without native tooling.

**Delivered — infrastructure**

- Flutter web platform generated (`web/` folder from
  `flutter create --platforms=web`).
- Swapped the map library from `maplibre_gl` 0.20 (which broke on modern
  Flutter web with `ui.platformViewRegistry` undefined) to
  `flutter_map` + `latlong2`. Pure Dart, first-class web support, no
  external JS assets. OpenStreetMap tiles.
- FastAPI backend gained `CORSMiddleware` with a permissive MVP allow-list
  so Chrome on any localhost port can call the API. Documented as
  "tighten before going public".

**Delivered — geocoding**

- New `NominatimGeocodingProvider`
  ([providers/geocoding.py](../backend/app/providers/geocoding.py)) that
  hits the free OSM Nominatim service with a proper User-Agent and
  restricts to launch-country codes (`ch,fr,it,es`). Handles
  `httpx.HTTPError` gracefully by returning an empty tuple.
- New `HybridGeocodingProvider(primary, fallback)`: tries the fast
  in-memory mock catalogue first, only falls back to Nominatim when the
  primary returns nothing. Keeps demo latency low for well-known cities
  while covering every populated place worldwide.
- Wired in [providers/factory.py](../backend/app/providers/factory.py)
  as the default geocoding stack. No existing tests needed updating —
  they all query cities the mock already covers.

**Delivered — hotels**

- `Hotel` entity + `PriceBand` enum (budget < 80 €/night, mid 80-160 €,
  lux > 160 €, any) in
  [domain/entities.py](../backend/app/domain/entities.py).
- `HotelsProvider` protocol + `MockHotelsProvider`
  ([providers/hotels.py](../backend/app/providers/hotels.py)): three
  synthesised hotels per waypoint, prices spread around a per-country
  anchor (CH 180 €, FR 120 €, IT 110 €, ES 95 €), deterministic from the
  route polyline.
- Filter service
  ([services/hotel_search.py](../backend/app/services/hotel_search.py))
  — filters by max detour + band; sorts by detour asc then price asc;
  top 10.
- `POST /v1/trips/plan` takes two new optional params
  (`hotel_max_detour_minutes`, `hotel_price_band`); response gains a
  `hotels: [...]` list (empty if the search wasn't requested).
- Mobile: `PriceBand`, `Hotel` models; new `HotelPreferences` widget in
  [widgets/hotel_preferences.dart](../mobile/lib/widgets/hotel_preferences.dart)
  — a collapsible section with a switch to enable, then a 15-120 min
  detour slider and a 4-way `SegmentedButton` for the band. `ResultScreen`
  shows a "Hotels near your route" section with tiles (name, country,
  €/night, minutes of detour, band chip).

**Validation**

- Backend: 51/51 tests passing (35 previous + 3 hybrid geocoder +
  13 hotels).
- Mobile: `flutter analyze` clean, `flutter test` 29/29 passing
  (previous 20 + 9 hotels).
- Live: Unterägeri now resolves via the Nominatim fallback. Chrome
  demoable end-to-end.

**Deliberately out**

- `SavedTrip` does not persist hotel preferences yet — re-plan starts
  clean. Simple, and matches how travellers actually re-open a trip
  ("show me current traffic; I'll pick hotels again").
- Nominatim is a public service rate-limited to ~1 req/s. Fine at MVP
  scale with the 250 ms debounce; switch to a paid geocoder or
  self-hosted instance before scaling.

---

## Sprint 6 — Rest stops + restaurants

**Goal:** two more "on-the-way" recommendations. Rest stops are a safety
default; restaurants are an opt-in filter parallel to hotels.

**Delivered — backend**

- `RestStop` and `Restaurant` entities in
  [domain/entities.py](../backend/app/domain/entities.py). `Restaurant`
  reuses the `PriceBand` enum; a restaurant-specific classifier lives
  in the provider (budget < 20 €/meal, mid 20-50 €, lux > 50 €).
- Extracted `point_at_fraction(a, b, f)` as a public helper in
  [providers/routing.py](../backend/app/providers/routing.py). Now used
  both by the waypoint interpolator (via
  `_great_circle_interpolate`) and by the rest-stops service.
- Rest stops service
  ([services/rest_stops.py](../backend/app/services/rest_stops.py)):
  pure function that emits one stop per 2 h of driving (ADAC / DGT /
  FIA recommendation). Skips the last candidate when < 15 min remain to
  destination. Returns `()` for trips under 2 h — nothing to recommend.
  Coordinates computed by interpolating along the origin→destination
  great circle at each stop's time-fraction.
- `RestaurantsProvider` + `MockRestaurantsProvider`
  ([providers/restaurants.py](../backend/app/providers/restaurants.py)):
  two synthesised restaurants per waypoint, priced around country anchors
  (CH 40 €, FR 28 €, IT 25 €, ES 22 €). Deterministic.
- Filter service
  ([services/restaurant_search.py](../backend/app/services/restaurant_search.py))
  — mirrors hotels: max detour + optional band; sort by detour then
  price; top 10.
- `POST /v1/trips/plan` gains two more optional params
  (`restaurant_max_detour_minutes`, `restaurant_price_band`) and two new
  response fields: `rest_stops: [...]` (always populated when the trip
  is long enough) and `restaurants: [...]` (populated only when the
  search was requested).

**Delivered — mobile**

- `Restaurant` and `RestStop` models added to
  [api/models.dart](../mobile/lib/api/models.dart); response parsing
  defaults both lists to empty if the field is missing, keeping the
  client tolerant to earlier API versions.
- New `RestaurantPreferences` widget in
  [widgets/restaurant_preferences.dart](../mobile/lib/widgets/restaurant_preferences.dart)
  — deliberately duplicated from hotel preferences rather than
  parameterised into a shared widget: defaults differ (5-60 min detour
  slider vs 15-120 min for hotels), and the two are likely to diverge
  further (cuisine filters, meal type, etc.).
- `PlanScreen` now shows both sections stacked under the departure
  picker; both default off.
- `ResultScreen` shows three new sections in order:
  "Suggested rest stops" (always when trip ≥ 2 h; no toggle — safety
  feature), "Hotels near your route", "Restaurants near your route".

**Validation**

- Backend: 67/67 tests passing (51 previous + 7 rest stops + 9
  restaurants).
- Mobile: `flutter analyze` clean, `flutter test` 35/35 passing
  (previous 29 + 6).
- Live: Paris→Madrid returns 6 rest stops (every 2 h from 2 h to 12 h)
  and 8 mid-band restaurants under 15 min detour.

**Deliberately out**

- Rest stops are always shown when applicable — no toggle. May become
  optional later if user feedback finds them noisy.
- Restaurants have no cuisine filter yet — parity with hotels was the
  scope goal ("nada más" was the user's phrase).
- Neither hotels nor restaurants are drawn on the map yet — they only
  appear as tile lists under it. Map markers come naturally when we
  wire real POI providers.

---

## Sprint 7 — Revenue calculators, adverse events, and an AI trip assistant

**Goal:** three unrelated tracks in one sprint — (1) tooling to model
monetization, (2) a safety/awareness layer surfacing dangers along the
route, and (3) a Premium narrative assistant powered by Claude.

**Delivered — revenue-modeling tools**

- [tools/ad_revenue_calculator.py](../tools/ad_revenue_calculator.py) —
  ad revenue by format (banner / native / interstitial / rewarded /
  app-open), calibrated for Travel/Nav in EU-4, with three preset
  scenarios and a MAU sensitivity sweep.
- [tools/subscription_revenue_calculator.py](../tools/subscription_revenue_calculator.py)
  — premium subscription revenue: monthly + annual pricing blend,
  Apple/Google store cut, intro discounts, per-user LTV.
- [tools/funnel_calculator.py](../tools/funnel_calculator.py) —
  end-to-end funnel that composes the two above: monthly installs →
  activation → steady-state MAU → total revenue. Preset `--scenario`
  fixes funnel + ads + subs to the same tier; overrides per-layer.
- All three ship with CLI, presets, sensitivity tables, and full unit
  tests (68 tests total, deterministic, no network).
- Documented in [tools/README.md](../tools/README.md) with usage
  examples and the parameters that matter.

**Delivered — adverse events (fires, strikes, weather, more)**

- New domain: `AdverseEvent`, `AdverseEventType` (fire, strike,
  weather, accident, roadwork, flood, snow, protest, other),
  `AdverseEventSeverity` (info / warning / critical), `AdverseEventSource`
  (user / mock / weather / official) in
  [domain/entities.py](../backend/app/domain/entities.py).
- Providers under
  [providers/adverse_events.py](../backend/app/providers/adverse_events.py):
  `MockAdverseEventsProvider` (deterministic demo events near common
  EU-4 corridors),
  `UserMarkedAdverseEventsProvider` (in-memory registry with 24 h
  default TTL and auto-purge; Postgres migration is a future sprint),
  `CompositeAdverseEventsProvider` (fans out to several sources). Real
  EFFIS/Open-Meteo/national-authority feeds slot in behind the same
  protocol later.
- Filter service
  ([services/adverse_events_filter.py](../backend/app/services/adverse_events_filter.py))
  — great-circle distance from every route point (origin + waypoints +
  destination), keeps events within 25 km by default, sorts critical →
  warning → info, then by proximity.
- `POST /v1/trips/plan` extended with `include_adverse_events: bool`
  and `adverse_events_max_distance_km` (5-200 km); response gains
  `adverse_events: [...]`.
- New endpoint `POST /v1/adverse-events` for user-submitted reports
  (crowd-sourced hazards). Validates coordinates, description length,
  and TTL; auto-expires after 24 h unless overridden.
- Mobile: `AdverseEventType`/`AdverseEventSeverity`/`AdverseEvent` models
  with icon + display metadata; new "Alert me about adverse events"
  switch on `PlanScreen`; new "Alerts along your route" section on
  `ResultScreen` with severity-coloured tiles.

**Delivered — AI trip assistant (Premium)**

- New `LlmProvider` protocol + two implementations in
  [providers/llm.py](../backend/app/providers/llm.py):
  `ClaudeLlmProvider` uses **Claude Opus 5** (Anthropic's most capable
  current model) with server-side refusal fallbacks
  (`server-side-fallback-2026-07-01` beta) and `effort: low` — enough
  quality for narrative generation at a materially lower cost than the
  default. `MockLlmProvider` echoes the prompt for tests and demos
  without an API key.
- Auto-selection in `default_llm_provider()`: if
  `ANTHROPIC_API_KEY` is present in the environment, use Claude; else
  fall back to Mock. Keeps CI and offline demos green.
- Prompt template in
  [services/trip_narrative.py](../backend/app/services/trip_narrative.py)
  — a pure function that formats the plan (route, best window, rest
  stops, hotels, restaurants, adverse events) into a structured brief
  and asks the model for 3-5 short paragraphs + 3-5 bulleted
  recommendations.
- New endpoint `POST /v1/trips/narrative` — accepts the same request
  shape as `/plan` plus city display names, runs the planner
  internally, then calls the LLM. Separated from `/plan` so the fast
  planner isn't blocked by LLM latency and Premium gating can be
  reasoned about at the route level.
- Mobile: `NarrativeResponse` model, `ApiClient.tripNarrative()`,
  new `NarrativeScreen` with loading / error / retry states, launched
  from a sparkle icon in `ResultScreen`'s AppBar labelled
  "Explain my trip (Premium)". Premium gate is placeholder for now
  (no auth) — the button always works so the feature is demoable.
- Voice output (TTS) deliberately deferred to a follow-up.

**Validation**

- Backend: 88/88 tests passing (67 previous + 8 adverse events +
  13 narrative + provider selection).
- Tools: 68/68 tests passing (23 ads previous + 45 subs + funnel).
- Mobile: `flutter analyze` clean, `flutter test` 46/46 passing
  (previous 35 + 11 adverse events + narrative).
- Live: `POST /v1/trips/plan` with `include_adverse_events=true` for
  Paris→Madrid returns 1 nearby event (the Paris rail-strike demo);
  narrative endpoint returns a placeholder when `ANTHROPIC_API_KEY`
  is unset and would switch to real Claude Opus 5 output when set.

**Deliberately out**

- Real external adverse-event feeds (EFFIS for wildfires, Open-Meteo
  for severe weather, national roadwork APIs) — the mock is enough for
  demo; the provider interface is ready.
- Real Premium gating (subscription check server-side; RevenueCat /
  StoreKit / Play Billing on device). Today the AI button is always
  available and marked Premium via label only.
- Voice narrative (TTS). The text narrative is the MVP; adding TTS is a
  small follow-up (Flutter `flutter_tts` on device, plus a "Play" button
  on `NarrativeScreen`).
- User-marked events UI in mobile — backend endpoint exists but no
  submission screen shipped yet. That's the natural next mobile task.

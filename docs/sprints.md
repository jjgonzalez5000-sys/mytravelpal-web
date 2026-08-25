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

---

## Sprint 8 — UI polish (Nordic redesign)

**Goal:** move the app from "default Material 3" to a coherent visual
system that reads as premium — same information density, meaningfully
better hierarchy, typography, colour, and motion.

**Delivered — design system**

- [design/tokens.dart](../mobile/lib/design/tokens.dart) — colour
  ("Nordic warm neutrals + forest green primary + terracotta accent"),
  8pt spacing scale, radii, three levels of soft shadows, motion
  durations, and easing.
- [design/components.dart](../mobile/lib/design/components.dart) —
  `SoftCard`, `SectionHeader` (with eyebrow), `StatTile`, `PrimaryCta`,
  `SoftBadge`, `EmptyState`. Used across every screen so a change to
  tokens ripples through the app.
- [theme.dart](../mobile/lib/theme.dart) rewritten with full Material 3
  overrides for AppBar / Card / Chip / Divider / InputDecoration /
  Buttons / ListTile / Switch / Slider / SnackBar. Typography: Inter
  via `google_fonts`.

**Delivered — new screens**

- [splash_screen.dart](../mobile/lib/screens/splash_screen.dart) —
  animated brand mark then routes to onboarding (first launch) or
  planner (returning users).
- [onboarding_screen.dart](../mobile/lib/screens/onboarding_screen.dart)
  — 3-slide intro (killer feature, honest planning, alerts), animated
  page dots, "Skip / Continue / Get started" flow. `onboarding_shown`
  flag persisted via new `AppPrefs`.

**Delivered — screen refactors**

- `PlanScreen`: hero "Where are we going today?" (display 32pt Inter),
  form grouped in a `SoftCard`, preferences grouped in a second card,
  full-width `PrimaryCta`, staggered fade-in on load.
- `ResultScreen`: hero recommendation card with gradient + 3 stat
  chips (shift / traffic / total), StatTile row for distance / free-flow
  / tolls, section groups in cards with divider separators, avatar-style
  leading icons on tiles.
- `HistoryScreen`: cards instead of dense list tiles, badges for
  distance / best time / countries, better empty state with CTA.
- `NarrativeScreen`: editorial layout (eyebrow + display title + body),
  pulsing brand mark on loading, error state via shared `EmptyState`.

**Micro-animations** via `flutter_animate` — staggered fade + moveY on
entry across every screen, `easeOutBack` scale on splash mark, pulse on
AI loading, animated onboarding dots, zoom page transitions.

**Validation**

- `flutter analyze` clean.
- 46/46 mobile tests passing (updated 3 for new layouts).

**Deliberately out**

- No custom app icon / launcher assets yet.
- No haptics — nice-to-have but not required for the visual polish.
- Voice narrative still deferred.

---

## Sprint 9 — Real routes on the map, theme toggle, toll savings

**Goal:** three related tracks — (1) let users switch between system /
light / dark, (2) draw the actual road-following route on the map (not
a straight great-circle line), (3) show a toll-free alternative with a
concrete money-vs-minutes comparison.

**Delivered — theme toggle**

- `AppPrefs` gains `themeMode` (system/light/dark) persisted in
  SharedPreferences.
- `ThemeModeNotifier` + `themeModeProvider` in Riverpod; `MyTravelPalApp`
  becomes `ConsumerWidget` and passes the mode to `MaterialApp`.
- [design/theme_toggle.dart](../mobile/lib/design/theme_toggle.dart) —
  `PopupMenuButton` with sun / moon / auto icons; live in
  `PlanScreen`'s AppBar.

**Delivered — real map routes (OSRM)**

- `Route` domain entity extended with `geometry: tuple[Coordinate, ...]`
  and `avoid_tolls: bool`.
- `RoutingProvider.route()` protocol takes an `avoid_tolls` keyword.
- [providers/routing.py](../backend/app/providers/routing.py) now ships
  three implementations behind the protocol:
  - `MockRoutingProvider` (unchanged behaviour + toll-free variant
    approximation: +15 % distance, 78 km/h secondary-road speed).
  - `OsrmRoutingProvider` — hits public OSRM
    (`router.project-osrm.org`; override via `MYTRAVELPAL_OSRM_URL`).
    Parses GeoJSON geometry, distance, duration; supports
    `?exclude=toll`; falls back to the mock via
    `FallbackRoutingProvider` when unreachable or `NoRoute`.
- `default_routing_provider()` chooses OSRM by default; tests set
  `MYTRAVELPAL_ROUTING=mock` (in [conftest.py](../backend/tests/conftest.py))
  so no test hits the internet.
- Response gets `route.geometry: [[lon, lat], …]`; empty when the
  fallback ran.
- Mobile: `RouteInfo.geometry`, `RouteMap` now draws the real polyline
  (solid) when available and a dashed straight line otherwise, with a
  small "Straight-line approx." badge over the map so the user knows
  what they're seeing.

**Delivered — toll savings**

- [services/toll_savings.py](../backend/app/services/toll_savings.py) —
  pure `compare(main, alt) → TollAlternative` with savings, time
  penalty, extra distance, and a `worth_it` heuristic (savings ≥ 5 € AND
  penalty ≤ 30 min).
- `POST /v1/trips/plan` accepts `include_toll_alternative: bool`;
  response gains `toll_alternative: TollAlternativeOut | null`.
- Mobile: `PlanScreen` gets a "Show toll-free alternative" switch; on
  the result screen the alternative is a full card ("Save €X for +Y
  min") with a "Worth it / Marginal" chip and, when geometry exists,
  is drawn dashed and dimmed on the same map layer.

**Validation**

- Backend: 101/101 tests (previous 88 + 13 new — OSRM parsing, mock
  avoid-tolls, fallback, toll-savings comparison, endpoint).
- Mobile: `flutter analyze` clean, 54/54 tests passing.
- Live: Paris → Madrid via public OSRM returns 17,833 geometry
  points. Toll alternative: saves 203 € but +356 min (Pyrenees
  detour) — correctly labelled "Marginal".

**Deliberately out**

- No time-varying toll skipping ("skip this toll during commute
  hours" — user's Premium-track suggestion). Belongs in a later sprint
  with real traffic data and a per-toll model; the current mock returns
  route-level pricing.
- No dedicated self-hosted OSRM. The public demo server has fair-use
  limits and offers no SLA — good for the MVP demo, needs replacing
  before scale.
- The toll-free polyline is often unavailable on the public server for
  long transcontinental routes (OSRM returns `NoRoute` when
  toll-avoidance would require exotic secondary paths). We degrade
  gracefully to the mock, so the *comparison numbers* still work; the
  alternative just isn't drawn.

---

## Sprint 10 — Trip profile, vehicle-aware costs, trip optimizations, hourly toll, event submission, geometry simplification

**Goal:** four short-list candidates (polyline simplification, route
options, hourly-toll analysis, user-marked event UI) plus a bigger
theme — a persistent **trip profile** that captures vehicle + travellers
+ meals and drives smarter POI ranking and a new "Optimized for your
trip" section that binds specific meal/sleep stops. Design intent:
users configure the profile *once*, plans absorb it silently, and the
result screen shows a small number of clear recommendations instead of
long lists.

**Delivered — backend**

- [services/polyline_simplify.py](../backend/app/services/polyline_simplify.py)
  — iterative Ramer-Douglas-Peucker (no recursion, safe for 17k+
  point OSRM outputs). `POST /v1/trips/plan` applies it (ε=0.2 km) to
  main and toll-free geometries before serialisation — Paris → Madrid
  drops from ~800 KB to a few hundred points with no visual difference
  at any usable map zoom.
- Route options extended: `avoid_motorways` and `prefer_scenic` join
  `avoid_tolls` on the `RoutingProvider.route()` protocol. OSRM combines
  `exclude=toll,motorway`; the mock applies proportional distance / speed
  penalties. `prefer_scenic` bumps the duration by 8 % (curvier
  secondaries; no OSRM native equivalent yet).
- New domain: [`Vehicle`, `FuelType`, `VehicleType`, `MealPreferences`,
  `TripProfile`, `MealSlot`](../backend/app/domain/entities.py). Kept in
  the pure domain layer, no ORM.
- [services/fuel_cost.py](../backend/app/services/fuel_cost.py) —
  distance × consumption × unit price, with per-fuel-type multipliers
  applied to the mock's petrol prices and a separate EV branch (kWh at
  €0.35, range check + note when the trip exceeds one charge).
- Hotels + Restaurants gained `kid_friendly`, `pet_friendly`, and
  parking / meal-slot metadata (deterministic from the mock seed).
  `filter_hotels` / `filter_restaurants` now accept an optional
  `TripProfile`; when set they *demote* (not exclude) hotels/restaurants
  that don't advertise the profile trait — the list stays populated
  even when the mock catalogue is small.
- [services/trip_optimizations.py](../backend/app/services/trip_optimizations.py)
  — pure function that binds each meal slot in scope to the closest
  rest stop within ±90 min of the target hour, then picks the nearest
  matching restaurant. Adds a sleep stop if the driver would still be
  on the road at 22:00 local. Returns at most 4 items (3 meals + 1
  sleep) so the UI stays legible.
- [services/hourly_toll_analysis.py](../backend/app/services/hourly_toll_analysis.py)
  — 24-hour verdict table using the traffic provider: for each hour
  compares toll-route minutes (with hour-specific traffic factor) to
  toll-free minutes (dampened traffic sensitivity, secondary roads
  suffer less commuter congestion). Reports best/worst 3 hours to
  skip. Premium.
- `POST /v1/trips/plan` extended with `trip_profile`, `avoid_motorways`,
  `prefer_scenic`, `include_hourly_toll_analysis`. Response gains
  `optimizations: {meal_stops, sleep_stop, fuel_cost}` and
  `hourly_toll_report`.

**Delivered — mobile**

- [domain/trip_profile.dart](../mobile/lib/domain/trip_profile.dart) —
  Dart mirror of the backend profile with JSON roundtrip, enum labels
  and icons.
- `AppPrefs` persists the profile as one JSON blob; new
  `tripProfileProvider` (Riverpod StateNotifier) exposes it.
- New [ProfileScreen](../mobile/lib/screens/profile_screen.dart) — one
  form, three sections (People / Vehicle / Meal times), designed so a
  user can complete it in under a minute. EV branch swaps to kWh + range
  inputs.
- `PlanScreen` gets a **compact profile chip** at the top: tap → open
  `ProfileScreen`. If no profile is set, the chip invites the user to
  create one; otherwise it summarises `Car · Petrol · kids · pets` etc.
  The plan flow itself does not add any new questions.
- `PlanScreen` preferences card gains 4 new switches: hourly toll
  analysis (Premium badge, only visible when toll-alternative is on),
  avoid motorways, prefer scenic.
- `ResultScreen` gains an **"Optimized for your trip"** section (fuel
  budget hero + meal-stop rows + optional sleep-stop row) — rendered
  only when a profile is present. Hourly toll verdict shows as a
  compact 24-column strip with a highlight of best/worst hours.
- New [MarkEventScreen](../mobile/lib/screens/mark_event_screen.dart)
  — form for the user to submit an adverse event they've spotted
  (type / severity / location / description). Launched from a new
  bell-plus icon in `PlanScreen`'s AppBar. Hits the existing
  `POST /v1/adverse-events`.

**Validation**

- Backend: **120/120** tests passing (previous 101 + 19 new —
  Douglas-Peucker properties, route options, fuel cost, profile-aware
  filtering, trip optimizations binding, hourly toll table, endpoint
  integration for profile + hourly + motorways).
- Mobile: `flutter analyze` clean, **61/61** tests (previous 54 + 7
  new — TripProfile roundtrip, AppPrefs persistence, request/response
  serialisation for the new fields, Optimizations + HourlyTollReport
  parsing).
- Live smoke: Paris → Madrid with a profile
  `{diesel, kids: true, pets: true}` returns 3 meal stops matched to
  timing, sleep stop at ~22:00, fuel budget ~€93 for a diesel car,
  and the response is ~50 KB down from ~800 KB thanks to polyline
  simplification.

**Deliberately out**

- No dedicated "settings" tab yet — profile is reached from the plan
  screen chip. If more per-user settings accumulate we split it out
  into its own drawer/tab.
- Real fuel-type-specific prices — the mock still returns "petrol"
  prices and we apply approximate per-type multipliers. A real provider
  will report diesel/LPG/EV prices directly and we can drop the
  multipliers.
- Hourly toll analysis uses the same traffic mock as the rest of the
  planner; when we contract HERE Traffic Stats, the same shape works
  with real data.
- Save memory captured: realtime weather alerts and sudden/emerging
  risk events (fires, emergencies, accidents) are deferred to the
  future navigation-mode sprint. See
  [`project_navigation_phase`](../../../.claude/projects/-home-blu3-Apps-MyTravelPal/memory/project_navigation_phase.md)
  memory.

---

## Sprint 11 — Full-Europe coverage, real weather forecasts, Premium gating, per-trip overrides, voice narrative, partial toll skipping

**Goal:** grow the app from launch-four countries to **all of the
supported European market** (30 countries: EU-27 + UK + NO + IS + CH),
turn the four remaining sprint-10 candidates into shipped features, and
add the "skip only some tolls" behaviour the user asked about.

**Delivered — full-Europe expansion**

- New [`app/data/countries.py`](../backend/app/data/countries.py) with one
  `CountryData` row per country: bounding box, toll-per-km and vignette,
  hotel / restaurant / fuel anchors, Nominatim country code, sample
  cities. Single source of truth; providers stopped hard-coding per-country
  dicts.
- `Country` enum extended to 31 members. `country_detection`,
  `routing._apply_toll_pricing`, `hotels`, `restaurants`, `fuel` and
  `geocoding._CATALOGUE` all read from the table.
- Country-detection priority hand-tuned so Norway's very wide bbox
  doesn't spuriously claim Stockholm.
- Nominatim requests now cover all 30 nominatim codes so users searching
  Berlin / Dublin / Warszawa / Reykjavik land results from the fallback
  when the mock catalogue misses.
- Mobile `Country` enum mirrored — 31 members with display names.

**Delivered — real weather feed (Open-Meteo)**

- New [`providers/weather.py`](../backend/app/providers/weather.py) —
  `OpenMeteoWeatherProvider` implements `AdverseEventsProvider`. Samples
  5 waypoints along the route, requests hourly forecasts, maps WMO
  weather codes (thunderstorm / heavy rain / snow / freezing rain / fog)
  to `AdverseEvent`s with `source=WEATHER`.
- Time-aware: for each sample point we ask "what's the weather when the
  driver will be *here*", not "at trip start".
- Opt-in via `MYTRAVELPAL_WEATHER=openmeteo` env var. Off by default in
  tests and CI to avoid the network hop.
- Graceful degradation: any HTTP error returns an empty tuple; the
  composite pipeline continues with mock + user-submitted events.

**Delivered — Premium gating**

- New [`api/premium.py`](../backend/app/api/premium.py) dependencies:
  `is_premium` (soft check for opt-in features) and `require_premium`
  (hard 402 when required).
- `POST /v1/trips/plan` returns 402 with `{error: "premium_required"}`
  when the client requests `include_hourly_toll_analysis` without the
  Premium header.
- `POST /v1/trips/narrative` requires Premium unconditionally.
- MVP transport: `X-MyTravelPal-Premium: true` request header — this
  is *not* production security; a follow-up sprint will replace it with
  proper receipt verification (RevenueCat webhook + StoreKit / Play
  Billing).
- Mobile: `AppPrefs.isPremium` (persisted bool), `premiumProvider`
  (Riverpod), a "Simulate Premium" section at the bottom of
  `ProfileScreen`, new `apiClientWithPremiumProvider` that injects the
  header on every outgoing request when Premium is on.

**Delivered — per-trip profile override**

- `ProfileScreen` gained an `override_` mode. In this mode the "Use"
  button pops with the edited profile via `Navigator.pop(profile)`
  without touching global prefs.
- `PlanScreen` shows a small "Override for this trip" text button below
  the profile chip; when active, the chip shows an "OVERRIDE ACTIVE"
  eyebrow and a border in the accent colour. Plan requests use the
  override; nothing is written to the global profile.

**Delivered — voice narrative**

- `flutter_tts` added; `NarrativeScreen` gains a "Read aloud" button
  in the header row that toggles TTS playback of the narrative. Stops
  automatically on dispose and on completion.

**Delivered — partial toll skipping**

- New backend service
  [`services/partial_toll_skips.py`](../backend/app/services/partial_toll_skips.py)
  — heuristic that chops the route into 5 segments, attributes each a
  weighted share of the total toll, estimates a small detour penalty,
  and flags the ones where savings-per-minute is high as "Skip".
- Response gains `partial_toll_skips: [...]` when
  `include_toll_alternative` is on. The whole-route toll_alternative and
  the per-segment skips are shown side by side in the UI.
- Mobile: `PartialTollSkip` model + a dedicated card on `ResultScreen`
  with per-stretch "Skip / Keep" chips.
- Honest limitation documented in the service: proper booth-level
  savings need a paid provider (HERE/TomTom/TollGuru); the current
  numbers are a planning-phase heuristic that gets *replaced* — not
  merely refined — once real toll data is available. Interface stays
  the same.

**Validation**

- Backend: **141/141** tests passing (previous 120 + 21 new —
  country table integrity, DE/AT/GR/IE/LU/SE detection, partial toll
  skips ranking + endpoint, Premium 402 vs 200 with header,
  OpenMeteo parsing + benign-code short-circuit + HTTP error graceful).
- Mobile: `flutter analyze` clean, **70/70** tests (previous 61 + 9
  new — Country enum size, PartialTollSkip parsing, TripPlanResponse
  default, ApiClient premium header presence/absence, AppPrefs premium
  persistence).
- Smoke: `curl` for Berlin lands DE via the extended mock;
  `include_hourly_toll_analysis` returns 402 without header and 200 with
  it; `include_toll_alternative` returns the whole-route comparison plus
  5 `partial_toll_skips` with "worth_it" flags.

**Deliberately out**

- No real IAP integration yet. RevenueCat + StoreKit + Play Billing
  are the natural next-sprint work; the header contract already lets
  the mobile client send verified state without touching endpoint code.
- Weather feed limited to Open-Meteo — richer providers (AEMET, MeteoFR)
  will layer in without changing the `AdverseEventsProvider` protocol.
- Partial toll skipping is heuristic, as noted above.
- Balkans / Turkey / Belarus / Russia / Ukraine and micro-states not in
  the country table — deferred until a real routing provider handles
  their quirks (partial motorway networks, non-EU vignette systems).

---

## Sprint 12 — User accounts, real POIs, real wildfires, real toll pricing, personal dashboard, trip sharing

**Goal:** move from "everything is mock or local" to a proper account
model and real external data where a free feed exists. Adds sign-in,
personal dashboard, share, and real providers for wildfires, POIs
(hotels + fuel), and toll pricing.

**Delivered — backend auth**

- New [`app/auth/`](../backend/app/auth/) package: JWT helpers
  (HS256, 30-day TTL, `MYTRAVELPAL_JWT_SECRET`), OAuth verifiers for
  Google (`google-auth`), Facebook (Graph API), and a **strict demo
  provider** for dev/preview; FastAPI dependencies for optional and
  required user context.
- Endpoints: `POST /v1/auth/session` (exchange provider id-token for
  app JWT), `GET /v1/auth/me` (bearer-only, returns current user).
- Demo mode ships enabled — real Google/Facebook require
  `GOOGLE_CLIENT_ID` + `google-auth` / `FACEBOOK_APP_SECRET` before they
  accept live tokens.

**Delivered — real emergencies (EFFIS wildfires)**

- New [`providers/effis.py`](../backend/app/providers/effis.py) —
  `EffisFireProvider` implements `AdverseEventsProvider`. Queries the
  **EFFIS VIIRS 24h hotspots** WFS layer (Copernicus, public, no key)
  bounded by the route's bbox, maps hotspots to `AdverseEvent`s with
  `source=OFFICIAL` and severity derived from FRP (fire radiative
  power ≥100 MW = critical).
- Opt-in via `MYTRAVELPAL_FIRES=effis`. Graceful empty return on HTTP
  errors — planner keeps working.
- **Direct answer to the user's question about the emergency source
  stack**: before this sprint, adverse events were 100 % mock +
  user-submitted. Now: mock + user-submitted + **Open-Meteo weather
  (real)** + **EFFIS wildfires (real)**. Police / traffic-agency feeds
  are country-specific and mostly gated by agreements — see
  `national_weather.py` stubs for the same pattern applied to
  Météo-France / AEMET / DWD / MetOffice for advisories, off by
  default until each key is set.

**Delivered — real POIs (Overpass)**

- New [`providers/overpass.py`](../backend/app/providers/overpass.py):
  - `OverpassHotelsProvider` queries OSM `tourism=hotel|guest_house|
    motel` in the route corridor, parses `family_friendly`, `dog`,
    `pets`, `parking`, and `stars` tags → `Hotel` with kid/pet/parking
    flags and a star-based price.
  - `OverpassFuelProvider` queries `amenity=fuel`, synthesises a price
    from the country anchor (no free per-station price feed exists
    outside the Spanish government API yet).
  - `FallbackHotelsProvider` / `FallbackFuelProvider` compose real +
    mock so an empty or slow Overpass response still ships a plan.
- Opt-in via `MYTRAVELPAL_HOTELS=overpass` and
  `MYTRAVELPAL_FUEL=overpass`. Off in tests to avoid the fair-use hit
  on the Overpass servers.

**Delivered — real toll pricing (TollGuru)**

- New [`providers/tollguru.py`](../backend/app/providers/tollguru.py):
  `TollGuruProvider` encodes the route geometry as a Google polyline
  and posts to `apis.tollguru.com/toll/v2/complete-polyline-…`, parses
  `costs.tag` / `costs.cash` and per-booth positions.
- Requires `TOLLGURU_API_KEY`; returns `None` without it or when the
  route has no geometry (mock routing). When a quote arrives, the
  existing whole-route heuristic and `partial_toll_skips` service will
  swap to real numbers in a follow-up wiring pass — this sprint ships
  the client + tests so the API contract is locked.

**Delivered — national weather stubs**

- [`providers/national_weather.py`](../backend/app/providers/national_weather.py)
  ships AEMET / Météo-France / DWD / MetOffice stubs. Each becomes an
  active `AdverseEventsProvider` when its env var is set. Honest note in
  docstring: Open-Meteo already covers all 30 countries with model
  forecasts; the national feeds add *advisory bulletins* (human-authored
  storm/snow warnings) that model output doesn't include.

**Delivered — mobile auth + dashboard + share**

- `AuthUser` domain model + `AuthSessionResponse`, `AuthNotifier`
  (Riverpod), `AppPrefs.setAuthSession` for persistence, JWT attached
  as `Authorization: Bearer …` on every request via
  `apiClientWithPremiumProvider`.
- New [LoginScreen](../mobile/lib/screens/login_screen.dart) — Google /
  Facebook OAuth buttons (require host-app configuration to fire) plus a
  demo login dialog that works out of the box.
- `SplashScreen` routing extended: **onboarding → login → planner**.
  Returning authenticated users skip straight to the planner.
- New [DashboardScreen](../mobile/lib/screens/dashboard_screen.dart)
  aggregating saved trips into headline stats (trips, km, hours,
  best-time savings estimate, top-5 countries with progress bars,
  most-recent trip). Sign-out button live here.
- `share_plus` wired via
  [services/trip_sharing.dart](../mobile/lib/services/trip_sharing.dart)
  — `ResultScreen` gets an `ios_share` button in the AppBar that opens
  the OS share sheet with a plain-text summary (origin, distance,
  countries, best time, toll savings if worth it).

**Validation**

- Backend: **154/154** tests passing (previous 141 + 13 new — JWT
  helpers, demo/google-401/me endpoints, EFFIS parsing + graceful
  errors, Overpass hotels/fuel parsing + fallback, TollGuru payload
  parsing + missing-key short-circuit).
- Mobile: `flutter analyze` clean, **75/75** tests (previous 70 + 5
  new — AuthUser roundtrip, AppPrefs auth session persistence,
  createSession POST body + response parsing, Authorization header
  presence, compose share text).

**Deliberately out**

- Real Google/Facebook sign-in requires host-app configuration (Google
  Cloud Console OAuth client IDs, SHA-1 fingerprints, `Info.plist` URL
  schemes, Meta developer app + `strings.xml` entries). The buttons
  attempt the real flow — bring your own client IDs.
- No deep links yet; shared trips are text-only. When a real
  `mytravelpal://` URL scheme + universal-link setup lands, the share
  message includes the URL.
- Dashboard's "best-time savings" is a conservative estimate — we
  don't persist `desired − recommended` per saved trip yet. Documented
  in the `_Stats` factory.
- National weather feeds beyond Open-Meteo are stubs until each service
  is subscribed and wired.
- Apple Sign In deferred — mandatory on iOS App Store when other social
  sign-ins are present; add before submission.

---

## Sprint 13 — Apple Sign-In, TollGuru wired into `/trips/plan`, trip sharing with deep links

**Goal:** close three follow-ups from Sprint 12: (1) add Apple as the
third real OAuth provider, (2) actually *use* the TollGuru client
we shipped by feeding real per-booth prices into the planner, and (3)
turn trip sharing from plain text into a deep link that reopens the
plan in the recipient's app.

**Delivered — Apple Sign-In**

- New `AppleOAuthProvider` in
  [`auth/providers.py`](../backend/app/auth/providers.py) — verifies
  Apple's `id_token` via the public JWKS at
  `https://appleid.apple.com/auth/keys`, validates `aud=APPLE_APP_ID`
  and `iss=https://appleid.apple.com`. No app secret needed on the
  server; only the bundle ID.
- Registered in `get_provider("apple")`. Returns 401 with a clear
  message when `APPLE_APP_ID` isn't configured, same shape as Google.
- Apple only surfaces the user's name on **first** login and outside
  the id_token — the mobile client forwards `givenName + familyName`
  via the `demo_name` channel and the backend picks it up when the
  id_token has no name claim.
- Mobile: `sign_in_with_apple` package + a black Apple button at the
  top of `LoginScreen`.

**Delivered — TollGuru wired into `/trips/plan`**

- `Providers` dataclass gained an optional `tollguru: TollProvider |
  None` slot. Factory instantiates the real client whenever
  `TOLLGURU_API_KEY` is set; otherwise `None` and the plan endpoint
  keeps its heuristic pricing.
- `POST /v1/trips/plan` handler now: after routing, if `tollguru is
  not None` **and** the route has geometry (i.e. OSRM ran), post the
  encoded polyline to TollGuru; on a valid `TollQuote`, replace
  `route.toll_cost_eur` with the real total and stash the per-booth
  list.
- `services/partial_toll_skips.compute()` grows an optional
  `real_tolls` kwarg. When present it emits one recommendation per
  real booth with a low, fixed ~5 min penalty — a huge improvement
  over the heuristic's 6-10 min per made-up segment. The API's
  `partial_toll_skips` field automatically carries the real booth
  names (e.g. "Fleury", "Poitiers") when TollGuru data flowed through.

**Delivered — trip sharing with deep links**

- New URL scheme `mytravelpal://trip?o=lat,lon&d=lat,lon&t=ISO&on=…&dn=…`
  encoded/decoded in
  [`services/trip_sharing.dart`](../mobile/lib/services/trip_sharing.dart).
  Stateless — every field is in the URL, no backend endpoint needed.
- `shareTrip()` now appends the deep link to the share message so the
  recipient can tap it and land back in the app.
- `AndroidManifest.xml` gets an `intent-filter` matching
  `scheme=mytravelpal` + `host=trip` on the `MainActivity`.
- New [`services/deep_link_handler.dart`](../mobile/lib/services/deep_link_handler.dart)
  wires `app_links` to listen for both cold-start URLs and warm links
  while the app is running, decodes them, and pushes a `PlanScreen`
  with the shared trip prefilled.
- `PlanScreen` gains an optional `initialShared` constructor param —
  when present, origin/destination search fields and the departure
  time are prefilled from the shared link so the recipient just taps
  Plan. Deliberate: no auto-submit (avoid planning things the user
  didn't ask for).
- `main.dart` sets up the deep-link handler after the widget tree has
  a navigator to push into (`rootNavigatorKey`).

**Validation**

- Backend: **162/162** tests passing (previous 154 + 8 new — Apple
  registration + missing-app-id, endpoint 401 for Apple without config,
  real-booth partial-skip count / worth-it flag / penalty magnitude,
  `/plan` uses TollGuru total when quote arrives, `/plan` degrades to
  heuristic without a key).
- Mobile: `flutter analyze` clean, **80/80** tests (previous 75 + 5
  new — trip URL roundtrip, foreign-scheme rejection, missing-coord
  rejection, out-of-range coord rejection, composed share text).

**Deliberately out**

- Universal links (`https://mytravelpal.app/trip/…`) — needs an
  `apple-app-site-association` file hosted on a real domain +
  `.well-known/assetlinks.json`. Custom scheme covers native today.
- iOS platform folder — not generated yet, so the Apple button only
  fires when `flutter create . --platforms=ios` is added and the iOS
  project configured with Apple's capability + bundle ID.
- No cloud sync of trips — the recipient of a shared link plans it
  locally; there's no "accept" flow that stores the trip in a shared
  space. Follow-up sprint if trips move to the cloud.
- TollGuru wiring today replaces `toll_cost_eur` and feeds real booths
  into `partial_toll_skips`. The whole-route `toll_alternative`
  (alternative avoiding all tolls) still uses the heuristic because
  TollGuru gives us tolled-route pricing, not tolled-vs-toll-free
  route pairs. That's a follow-up where we ask TollGuru for the
  alternative geometry too.

---

## Sprint 14 — Savings surfaced everywhere

**Goal:** the user's core value prop — "how much time and money did the
app save you?" — was implicit. Make it explicit: the plan preview, the
best-time recommendation card, saved trips, and the personal dashboard
now all quote real minutes-saved and euros-saved based on data we
already computed.

**Delivered — backend**

- New pure helper in
  [`services/time_window.py::minutes_saved_vs_desired`](../backend/app/services/time_window.py)
  — compares the recommended window vs the sample closest to the
  desired departure and returns positive minutes when the recommendation
  is faster. Zero when there's no better option. No new provider calls.
- New response block `savings: {time_saved_minutes_vs_desired,
  money_saved_eur_vs_tolls}` on `POST /v1/trips/plan`. Time savings come
  from the helper above. Money savings are the `toll_alternative`
  savings when the heuristic flagged the alternative as *worth it* —
  zero otherwise. Always present on the response so clients don't need
  to handle nulls.

**Delivered — mobile**

- Mirror models: `TripSavings` in
  [api/models.dart](../mobile/lib/api/models.dart); `TripPlanResponse`
  gets a `savings` field with a zero default so older-shape responses
  parse cleanly.
- [SavedTrip](../mobile/lib/storage/saved_trip.dart) persists
  `savedMinutesVsDesired` and `savedEurVsTolls`, defaulting to 0 when
  reading trips saved before the schema change (backwards-compatible).
  `ResultScreen._save` populates both from the plan response.
- `ResultScreen`:
  - New **"YOUR SAVINGS ON THIS TRIP"** card at the top (below the map,
    above the recommendation hero) with two big stats — time saved and
    money saved — with a short caption explaining where the savings
    come from (departure shift / toll-free alternative / both).
  - The **Best-time hero** now shows a pill badge *"X min saved"* right
    next to the "BEST TIME TO LEAVE" eyebrow when the recommendation
    beats the desired-time sample.
- `DashboardScreen`:
  - Replaces the old "BEST-TIME SAVINGS" placeholder with a two-card row:
    **TIME SAVED** (primary tone) and **MONEY SAVED** (tertiary tone),
    values summed honestly from persisted `SavedTrip` fields.
  - The "across N nudged trips" subtitle counts real trips where either
    time or money was saved, not a proxy.

**Validation**

- Backend: **169/169** tests passing (previous 162 + 7 new — 4 for the
  `minutes_saved_vs_desired` helper covering equal/faster/empty/closest
  cases, 3 for the endpoint contract).
- Mobile: `flutter analyze` clean, **85/85** tests (previous 80 + 5
  new — TripSavings parsing, default-zero when field missing,
  SavedTrip roundtrip + legacy fallback for the two new fields).

**Deliberately out**

- Fuel-cost savings (from picking a cheaper station or a better vehicle
  route) aren't in the aggregate yet — the persisted `SavedTrip` only
  knows what was on the plan, not what the driver actually spent.
  Requires a "log actual trip" flow first.
- No comparison across time periods on the dashboard ("this month vs
  last") — needs cloud sync so trips carry a canonical timestamp; noted
  in [`project_deferred_features`](../../../.claude/projects/-home-blu3-Apps-MyTravelPal/memory/project_deferred_features.md).

---

## Sprint 15 — Route comparison, fuel in dashboard, ranking, local reminders

**Goal:** four accretive features around the plan and the dashboard.
Each is small on its own, all rest on existing infra.

**Delivered — backend**

- [`services/route_variants.py`](../backend/app/services/route_variants.py)
  — pure orchestrator that returns 3 named variants: **fastest**
  (echoes primary), **toll-free** (`avoid_tolls=True`), **scenic**
  (`prefer_scenic=True`). Two extra `RoutingProvider.route()` calls
  when opted in.
- `POST /v1/trips/plan` gets `include_route_comparison: bool` and a
  `route_variants: [{key, label, distance_km, free_flow_minutes,
  toll_cost_eur}]` field on the response.

**Delivered — mobile**

- `TripPlanRequest` mirrors `includeRouteComparison`.
- `RouteVariant` model + parse. New `_RouteVariantsSection` on
  `ResultScreen` renders the three rows with icon (speed / savings /
  landscape) and per-row summary (km · time · tolls). "PRIMARY" chip
  next to the fastest row so the driver sees which one the rest of the
  plan is based on.
- New switch **"Compare route variants"** in `PlanScreen` preferences,
  wired into the request.
- `SavedTrip` grows three fields (all defaulted for backwards
  compatibility): `fuelCostEur`, `reminderMinutesBefore`,
  `notificationId`. `ResultScreen._save` populates all three at
  save-time — fuel comes from the optimizations block, reminder from
  the trip profile, notification id from the scheduling call.
- New `MealPreferences.reminderMinutesBefore` (default 30) — the
  cleanest existing home for the setting; `ProfileScreen` gains a
  "Reminders" section with a stepper 0-120.
- [`services/notifications.dart`](../mobile/lib/services/notifications.dart)
  wraps `flutter_local_notifications`: init (Android channel +
  timezone data + permission requests), `scheduleDepartureReminder`
  bound to the SavedTrip id (`String.hashCode` → int notification
  id, deterministic so we can cancel/reschedule), `cancel`. On
  web/desktop every method is a no-op — the rest of the app doesn't
  have to guard `kIsWeb`.
- `main.dart` initialises the service before `runApp` so
  ResultScreen's Save flow can schedule without race.
- History screen's delete now cancels the associated notification.
- **Dashboard extended**:
  - New "ESTIMATED FUEL BUDGET" card when trips carry fuel costs
    (sum of persisted `fuelCostEur` across trips + count).
  - New **"Top savers"** section — ranks the 5 best-saving saved trips
    by `savedEurVsTolls + 0.10 × savedMinutesVsDesired` (common
    time-value heuristic).
  - Per-country row extended with a small right-aligned "€X" showing
    the toll savings attributed to that country (split equally across
    countries a trip crosses — coarse but honest without booth-level
    data).

**Validation**

- Backend: **174/174** tests (previous 169 + 5 new — service returns
  three keys, toll-free zeroes toll cost, scenic is slower, endpoint
  empty by default, endpoint returns the three variants when opted in).
- Mobile: `flutter analyze` clean, **94/94** tests (previous 85 + 9 new —
  RouteVariant parsing, request field serialisation on/off,
  route_variants default when missing, SavedTrip roundtrip of new
  fields, legacy fallback, MealPreferences reminder default + roundtrip).

**Deliberately out**

- Reminders don't survive a device reboot on Android — needs a
  `BOOT_COMPLETED` receiver + rescheduling service to be truly
  robust. Fine for MVP; the trip's `notificationId` is persisted so
  we can restore on next launch when we add the receiver.
- Notifications on iOS/macOS wait for the platform folders to exist
  (still web + Android only in this repo).
- Route variants ship as summary rows — no map overlay of the two
  extra polylines yet; the current map already gets busy with primary
  + toll-alt dashed. When we add layer toggles it's a natural spot.
- Per-country savings attribution splits equally across countries in
  the route. A real booth-level attribution requires the TollGuru
  booth country codes (TollGuru's response has them; not wired yet).

---

## Sprint 16 — Localisation (EN/ES/FR/IT/DE) + shareable APK

**Goal:** two things the user asked for: run the app in the user's own
language, and produce a distributable Android APK for family testers.

**Delivered — localisation**

- `flutter_localizations` + `intl` 0.20 wired in.
- `l10n.yaml` config + ARB files for **English, Spanish, French,
  Italian and German** in [`lib/l10n/`](../mobile/lib/l10n/). ~50
  strings each — the app's first-touch surface plus critical labels.
- `MaterialApp` gains `localizationsDelegates` + `supportedLocales`;
  device-language wins (fall back to English if unsupported).
- First-touch surface refactored to `AppLocalizations`: **onboarding
  slides** (3), **login screen** (Apple/Google/Facebook/demo +
  divider + terms + tagline), **plan screen** (hero eyebrow +
  headline, intro, From/To labels, CTA, error, AppBar tooltips,
  bottom note). The result / dashboard / profile screens keep their
  keys in the ARB — those refactors are a follow-up sweep noted in
  the deferred-features memory.

**Delivered — Android APK**

- Fixed Android build: `isCoreLibraryDesugaringEnabled = true` +
  `desugar_jdk_libs 2.1.4` so `flutter_local_notifications`'
  `zonedSchedule` compiles for release. `multiDexEnabled = true` for
  the growing dependency graph. `minSdk = 21` (already the default but
  now explicit).
- `flutter build apk --release --split-per-abi` produces three
  architecture-specific APKs under
  `mobile/build/app/outputs/flutter-apk/`:
  - `app-arm64-v8a-release.apk` — 22 MB, ~95 % of modern phones.
  - `app-armeabi-v7a-release.apk` — 20 MB, older devices.
  - `app-x86_64-release.apk` — 24 MB, emulators.
- New [`docs/apk_distribution.md`](apk_distribution.md) covers build,
  signing (debug keystore is fine for family; Play needs a real one),
  three ways to solve the backend URL problem (LAN, ngrok tunnel,
  deploy), share channels (WhatsApp / email / Drive / adb), and the
  recipient's install flow (unknown sources dialog + MIUI's Install
  via USB toggle).

**Validation**

- `flutter analyze` clean.
- **94/94** mobile tests still passing after the l10n refactor.
- Release APKs built without errors on all three ABIs.

**Deliberately out**

- **Full string sweep** across result / dashboard / profile /
  history / narrative / mark-event / restaurant + hotel preferences.
  The ARB has the keys, only the widget-side substitutions are
  pending. Deferred to a "polish pass" so we don't rush translation
  quality on 100+ strings.
- No pluralisation or gender-agreement rules yet — Spanish/French/German
  have edge cases (viajero/viajera; les/le; der/die/das) that need
  ICU plural/select forms in the ARBs. Fine while every user-visible
  string is agnostic.
- Signed release keystore, Play Console setup, obfuscation
  (`--obfuscate --split-debug-info`) — all deferred until we actually
  publish. Debug-signed APK is fine for family sideloading.
- Backend deployment — apk_distribution.md documents the tunnel /
  LAN-IP workarounds, but a real production URL is a separate
  infrastructure sprint.

---

## Sprint 17 — Backend deployment (Fly.io) with API-key gate

**Goal:** move from "backend runs on your laptop" to "backend runs on a
stable HTTPS URL your family can hit any time" — **without** exposing
the codebase or letting internet strangers use your compute.

**Delivered — API-key gate**

- New [`app/api/api_key.py`](../backend/app/api/api_key.py) middleware.
  When `MYTRAVELPAL_API_KEY` is set in the environment, every incoming
  request to `/v1/*` must carry `X-MyTravelPal-Api-Key` matching it.
  `/health` and `/docs` remain open (infra probes + OpenAPI). Missing
  or wrong key → 401 `{error: "api_key_required"}`.
- Middleware is a **no-op in dev** (env var unset) — existing tests
  and local `uvicorn --reload` continue working without headers.

**Delivered — Fly.io deployment config**

- Production-ready `backend/Dockerfile` — multi-stage
  friendly base, only runtime deps installed (`pip install -e .`, no
  `[dev]` extras), no `--reload` in `CMD`, no test/docs files in the
  image.
- `backend/.dockerignore` — keeps venv, tests, docs, docker-compose,
  git metadata out of the image.
- `backend/fly.toml` — deployment config: primary region `mad`
  (Madrid, closest to launch markets), auto-stop when idle to save
  free-tier hours, `/health` check, non-secret env vars set inline
  (`MYTRAVELPAL_ROUTING=osrm`, `MYTRAVELPAL_WEATHER=openmeteo`,
  `MYTRAVELPAL_FIRES=effis`).

**Delivered — mobile API-key wiring**

- `ApiConfig` reads `--dart-define=API_KEY=…` at build time. Empty
  default keeps local dev working.
- `ApiClient._headers()` adds `X-MyTravelPal-Api-Key` on every request
  when the key is set — beside the existing Premium and Authorization
  headers.

**Delivered — docs**

- New [`docs/deployment.md`](deployment.md) with the full Fly.io
  walkthrough: install, `fly launch --no-deploy`, seed secrets
  (`MYTRAVELPAL_API_KEY`, `MYTRAVELPAL_JWT_SECRET`, optional
  `ANTHROPIC_API_KEY`, `TOLLGURU_API_KEY`, `GOOGLE_CLIENT_ID`,
  `FACEBOOK_APP_SECRET`, `APPLE_APP_ID`), `fly deploy`, verify with
  curl, wire APK. Also explains what "not exposing" means at three
  levels (source, URL, usage) and where each is handled. Covers
  provider alternatives (Railway / Render / Hetzner) and lists what
  the setup deliberately does NOT include (custom domain, DB backup,
  rate limiting beyond the gate, CI deploy).
- [`docs/apk_distribution.md`](apk_distribution.md) Option 3 updated
  to point at the new deployment guide + shows the double `--dart-define`
  (both URL and key).

**Validation**

- Backend: **179/179** tests passing (previous 174 + 5 new — gate
  off by default, health always exempt, rejects without header,
  rejects wrong key, passes with correct key).
- Mobile: `flutter analyze` clean, **94/94** tests (unchanged surface,
  new header only added when `API_KEY` is provided).
- Docker image builds locally without warnings that matter.

**Deliberately out**

- Custom domain — buy a real one and `fly certs create` when ready.
- Persistent DB — nothing needs it yet (user-marked events and
  auth are in-memory today). Fly Postgres or external Postgres when
  cloud-sync of trips lands.
- Rate limiting beyond the key gate — `slowapi` or Cloudflare in
  front if a real leak happens.
- CI-based deployment — `fly deploy` from a laptop covers the current
  release cadence; GitHub Actions is a follow-up once we have a git
  host.

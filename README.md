# MyTravelPal

Innovative road-trip planning app for the European market. Fills the gaps left
by Google Maps / Waze / Sygic by focusing on **pre-trip planning**: optimal
departure windows, toll savings, cheapest fuel and EV charging along the
route, and smart rest stops.

Freemium model, launch markets: **Switzerland, France, Italy, Spain** — full
Europe scope thereafter.

> Original brief (Spanish): [Prompt:.yml](Prompt:.yml)

## Project state — Sprints 1-17

Backend + Flutter app slice with mocked external providers (plus real
Nominatim as a geocoding fallback, and real Claude Opus 5 for the AI
assistant when `ANTHROPIC_API_KEY` is set). See
[docs/mvp_scope.md](docs/mvp_scope.md) for what's in and out and
[docs/sprints.md](docs/sprints.md) for per-sprint delivery notes.

- [x] FastAPI backend: `POST /v1/trips/plan`, `POST /v1/trips/narrative`, `GET /v1/geocode`, `POST /v1/adverse-events`
- [x] Optimal-departure-window service (killer feature)
- [x] Waypoint-aware country auto-detection along the route
- [x] Hotels + restaurants along the route (max detour + price band)
- [x] Recommended rest stops every 2 h of driving
- [x] Adverse-event alerts (fires, strikes, weather, accidents, roadwork, floods, snow, protests) — mock catalogue + user-submitted
- [x] AI trip assistant (Premium): Claude Opus 5 narrative with recommendations, mock fallback for offline dev
- [x] Hybrid geocoding: mock catalogue with Nominatim fallback for any place worldwide
- [x] Real road-following routes via OSRM (`router.project-osrm.org`) with graceful mock fallback + Douglas-Peucker polyline simplification (~10× smaller payloads)
- [x] Toll-free alternative with money-vs-minutes comparison, "Worth it / Marginal" heuristic, and Premium hourly toll analysis (24-hour verdict of best/worst hours to skip tolls)
- [x] Route options: avoid motorways, prefer scenic
- [x] Trip profile (vehicle type + fuel + consumption + travellers + kids/pets + meal times) — configured once, drives POI ranking and cost estimates silently
- [x] Trip optimizations: meal-stop matching (breakfast/lunch/dinner), sleep-stop suggestion, fuel-cost estimate (€ + L or kWh) with EV range check
- [x] User-submitted adverse events with type/severity picker + description
- [x] **Full European coverage** — EU-27 + UK + NO + IS + CH (31 countries) with per-country bounding boxes, toll pricing, price anchors and sample cities
- [x] Real weather forecasts along the route via **Open-Meteo** (opt-in, mock fallback for CI)
- [x] Partial toll skipping — per-stretch recommendations to exit before an expensive toll and rejoin after (heuristic; real booth-level data comes with paid provider)
- [x] Premium gating (`X-MyTravelPal-Premium` header) for AI briefing + hourly toll analysis; local "Simulate Premium" toggle in mobile until real IAP lands
- [x] Per-trip profile override — change vehicle/travellers for a single trip without touching the global profile
- [x] Voice narrative — TTS "Read aloud" on the AI briefing via `flutter_tts`
- [x] User accounts (JWT sessions) — Apple / Google / Facebook / demo sign-in; backend auth endpoints + `Authorization: Bearer` on all requests
- [x] Personal dashboard — headline stats (trips, km, hours, best-time savings estimate, top countries) with sign-out
- [x] Share trip via the OS share sheet with a **deep link** (`mytravelpal://trip?…`) that reopens the plan on the recipient's device
- [x] Real wildfires via **EFFIS** (Copernicus, free) — first real emergency source alongside Open-Meteo weather
- [x] Real hotels via **Overpass API** (OSM `tourism=hotel|guest_house|motel` with kid/pet/parking tags) — graceful mock fallback
- [x] Real fuel stations via **Overpass API** — graceful mock fallback
- [x] Real toll pricing via **TollGuru** — booth-level prices wired into `/trips/plan`, replace heuristic and feed per-booth partial-toll-skip recommendations
- [x] National weather feed stubs (AEMET / Météo-France / DWD / MetOffice) — activate per-key when subscribed
- [x] Nordic/Airbnb-style UI system with light/dark theme toggle, onboarding, splash, and reusable design components
- [x] Time-saved and money-saved surfaced on the plan preview (hero + summary card), on saved-trip persistence, and aggregated on the personal dashboard
- [x] Route comparison (fastest / toll-free / scenic) side-by-side on the result screen
- [x] Dashboard fuel budget, top-savers ranking, and per-country savings breakdown
- [x] Local reminder notifications X minutes before the recommended departure (configurable per-user)
- [x] App localised to **EN / ES / FR / IT / DE** — onboarding, login and planner surfaces translated; ARB has full key set for remaining screens
- [x] Release Android APK build documented in [docs/apk_distribution.md](docs/apk_distribution.md) — build, sign, backend-URL options, share, install flow
- [x] Backend deployment recipe (Fly.io, HTTPS, secrets, API-key gate) in [docs/deployment.md](docs/deployment.md) — source stays local, strangers can't use the URL
- [x] `docker compose up` local environment
- [x] Backend tests: 174 passing
- [x] Revenue-modeling tools (ads, subs, funnel): 68 passing — see [tools/README.md](tools/README.md)
- [x] Flutter mobile app: sign-in, onboarding, city search across all EU countries, real-road map, best-departure chart with per-trip savings, saved trips, dashboard with time+money+fuel totals and top-savers ranking, share via deep link, trip profile + per-trip override + reminder setting, hotels/restaurants profile-aware filters, rest stops, adverse-event alerts + submission, toll savings, partial toll skips, hourly toll (Premium), route options + variants comparison, trip optimizations, AI briefing + voice — see [mobile/README.md](mobile/README.md)
- [x] Mobile tests: 94 passing (`flutter analyze` clean)
- [ ] Real paid provider integrations (HERE / TomTom / TollGuru / EFFIS / Open-Meteo / Spanish fuel API / …) — on hold; OSRM + Nominatim + Claude cover the MVP
- [ ] Real auth + Premium subscription gating (RevenueCat / StoreKit / Play Billing) — placeholder today

Architecture: [docs/architecture.md](docs/architecture.md).
Mock strategy: [docs/mock_data_strategy.md](docs/mock_data_strategy.md).
Sprint history: [docs/sprints.md](docs/sprints.md).

## Quickstart

### With Docker (recommended)

```bash
cd backend
docker compose up --build
```

API on <http://localhost:8000>. OpenAPI docs at <http://localhost:8000/docs>.

### Local Python (no Docker)

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/uvicorn app.main:app --reload
```

### Try it

```bash
curl -X POST http://localhost:8000/v1/trips/plan \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"lat": 48.8566, "lon": 2.3522},
    "destination": {"lat": 40.4168, "lon": -3.7038},
    "desired_departure_at": "2026-08-24T08:00:00",
    "countries": ["FR", "ES"]
  }'
```

### Run tests

```bash
cd backend
.venv/bin/pytest
```

## Configuration

Environment variables (see `backend/docker-compose.yml` for defaults):

| Variable       | Default                                                                | Purpose                     |
|----------------|------------------------------------------------------------------------|-----------------------------|
| `DATABASE_URL` | `postgresql+asyncpg://mytravelpal:mytravelpal@localhost:5432/…`        | Postgres + PostGIS DSN      |
| `REDIS_URL`    | `redis://localhost:6379/0`                                             | Redis cache DSN             |
| `LOG_LEVEL`    | `INFO`                                                                 | Uvicorn / app logging level |

## Repo layout

```
MyTravelPal/
├── docs/                    architecture, MVP scope, mock strategy
├── backend/
│   ├── app/
│   │   ├── api/v1/          FastAPI routers
│   │   ├── domain/          pure dataclass entities (Trip, Route, TimeWindow)
│   │   ├── providers/       Provider protocol + mock implementations
│   │   └── services/        time_window and future planning services
│   └── tests/               unit + API tests
└── mobile/                  Flutter app (next sprint)
```

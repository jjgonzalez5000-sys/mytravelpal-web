# MyTravelPal

Innovative road-trip planning app for the European market. Fills the gaps left
by Google Maps / Waze / Sygic by focusing on **pre-trip planning**: optimal
departure windows, toll savings, cheapest fuel and EV charging along the
route, and smart rest stops.

Freemium model, launch markets: **Switzerland, France, Italy, Spain** — full
Europe scope thereafter.

> Original brief (Spanish): [Prompt:.yml](Prompt:.yml)

## Project state — Sprints 1-7

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
- [x] `docker compose up` local environment
- [x] Backend tests: 88 passing
- [x] Revenue-modeling tools (ads, subs, funnel): 68 passing — see [tools/README.md](tools/README.md)
- [x] Flutter mobile app: city search, map, best-departure chart, saved trips, hotels & restaurants filters, rest-stops, adverse-event alerts, AI briefing — see [mobile/README.md](mobile/README.md)
- [x] Mobile tests: 46 passing (`flutter analyze` clean)
- [ ] Real provider integrations (HERE / TomTom / TollGuru / EFFIS / Open-Meteo / Spanish fuel API / …) — on hold
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

# MyTravelPal

Innovative road-trip planning app for the European market. Fills the gaps left
by Google Maps / Waze / Sygic by focusing on **pre-trip planning**: optimal
departure windows, toll savings, cheapest fuel and EV charging along the
route, and smart rest stops.

Freemium model, launch markets: **Switzerland, France, Italy, Spain** — full
Europe scope thereafter.

> Original brief (Spanish): [Prompt:.yml](Prompt:.yml)

## Project state — Sprints 1-4

Backend + Flutter app slice with mocked external providers. See
[docs/mvp_scope.md](docs/mvp_scope.md) for what's in and out.

- [x] FastAPI backend with `POST /v1/trips/plan` and `GET /v1/geocode`
- [x] Optimal-departure-window service (killer feature)
- [x] Waypoint-aware country auto-detection along the route
- [x] Mock providers for routing, historic traffic, tolls, fuel, geocoding
- [x] `docker compose up` local environment
- [x] Backend tests: 35 passing
- [x] Flutter mobile app: city search, map, best-departure chart, saved trips history — see [mobile/README.md](mobile/README.md)
- [x] Mobile tests: 20 passing (`flutter analyze` clean)
- [ ] Real provider integrations (HERE / TomTom / TollGuru / Nominatim / Spanish fuel API / …) — on hold

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

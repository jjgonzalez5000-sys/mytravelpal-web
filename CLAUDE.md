# MyTravelPal — Claude Code Context

## Project

European road-trip planning app (freemium). FastAPI backend on Fly.io (CDG), Flutter mobile (Android). Fills gaps left by Google Maps / Waze / Sygic: optimal departure time, real toll costs, meal/sleep/hotel planning, fuel arbitrage, weather along route, adverse events.

## Architecture

- **Backend**: `backend/` — FastAPI + Pydantic, Python 3.14, deployed on Fly.io (`mytravelpal-api.fly.dev`). OSRM for routing, Geoapify for POIs (hotels/restaurants), Open-Meteo for weather, gov feeds for fuel (ES/FR/IT).
- **Mobile**: `mobile/` — Flutter 3.x, Riverpod state management, flutter_map (OSM tiles), 5 languages (EN/ES/FR/DE/IT).
- **No iOS folder yet** — Android only for now.

## Key files

- `backend/app/api/v1/trips.py` — main `/plan` endpoint, ~1400 lines
- `backend/app/services/trip_optimizations.py` — meal/sleep stop selection with multi-day + pause overhead
- `backend/app/providers/geoapify_poi.py` — hotel + restaurant POI provider (migrated from Nominatim)
- `backend/app/services/weather_summary.py` — weather forecast along route segments
- `mobile/lib/screens/result_screen.dart` — main result UI, ~3000 lines
- `mobile/lib/screens/plan_screen.dart` — trip planning form
- `mobile/lib/widgets/trip_insights.dart` — day plan + hotel sections
- `mobile/lib/services/app_tutorial.dart` — coach mark tutorial

## Deploy pattern

```bash
# Backend
cd backend && fly deploy

# Mobile (include all --dart-define)
cd mobile && flutter build apk --release \
  --dart-define=API_BASE_URL=https://mytravelpal-api.fly.dev \
  --dart-define=API_KEY=7637fb236013308ebf998843d924e15e56dce87457187e22a1a03c9c1e164d7a \
  --dart-define=SENTRY_DSN=https://3c46e071b627ae7c6c5cb4592cadbf60@o4511977727590400.ingest.de.sentry.io/4511977749086288
flutter install
```

## Secrets (Fly)

- `MYTRAVELPAL_API_KEY` — app API key
- `MYTRAVELPAL_GEOAPIFY_KEY` — Geoapify Places API
- `SENTRY_DSN` — Sentry crash reporting
- `MYTRAVELPAL_JWT_SECRET` — JWT auth

## User preferences

- Spanish for planning discussions, English for code and docs
- Ship automatically: `fly deploy` + `flutter build` + `flutter install` without asking permission
- No emojis in code/docs
- Terse responses, no trailing summaries

## Current state (2026-08-27)

- Geoapify migrated (free tier, 3k req/day)
- Fly.io auto_stop_machines = suspend (~$5-8/mo)
- Sentry configured (backend + mobile, same DSN)
- Booking.com + TheFork affiliate tracking active
- Tutorial coach marks (plan + result screen)
- Weather along route (Open-Meteo, 5 segments)
- Total trip cost card (fuel + tolls + meals + hotel)
- Hotels grouped by stop/destination (not flat list)
- Interactive map (collapse/normal/fullscreen + POI markers)

## Backlog

- TollGuru integration (real toll booth data) — code ready, needs API key
- Tankerkönig (Germany fuel) — needs API key
- Firebase Crashlytics — needs google-services.json
- Play Store submission — needs Privacy Policy + ToS + screenshots
- Android Auto POI Companion — Kotlin bridge designed, not started
- Getaway planner ("discover a trip from my location") — designed, not started

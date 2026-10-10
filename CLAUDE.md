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

## One-time developer setup

Do these once per machine so `git push` / `fly deploy` work non-interactively
from any shell (including Claude Code's).

```bash
# GitHub CLI — token stored in ~/.config/gh/hosts.yml (survives reboots)
sudo apt install -y gh
gh auth login              # HTTPS → Login with web browser → Authorize gh
gh auth setup-git          # wire git to use the gh token

# Fly CLI — token stored in ~/.fly/config.yml
curl -L https://fly.io/install.sh | sh    # only if flyctl not installed
flyctl auth login          # browser flow

# Docker + docker-compose (v1 or v2), Flutter SDK, rclone
# — assumed already installed. See individual docs if missing.
```

After this, both `git push origin main` and `fly deploy` succeed with no
prompts, from any shell — including from within background jobs.

## Local dev (fast iteration, no Fly round-trip)

```bash
# One-time (~30-60 min, ~15 GB disk): download Iberia+FR PBFs and build OSRM MLD graph
make osrm-prep

# Start the full local stack — hot-reload FastAPI + Postgres + Redis + local OSRM
make dev

# Common
make logs                # tail api + osrm
make test                # backend pytest -xvs -n auto inside container
make shell               # bash into api container
make down                # stop stack

# Mobile against local backend (emulator default host = 10.0.2.2)
make mobile-local
# Real device on LAN:  make mobile-local LOCAL_IP=192.168.1.42
```

Local stack talks to real `MYTRAVELPAL_GEOAPIFY_KEY` if it's exported in your
shell; otherwise POI providers gracefully degrade. Local OSRM covers ES/PT/FR
only — trips outside that box need the Fly backend.

## Ship pattern (mobile testing / beta)

```bash
make mobile-prod    # release APK against Fly + install + rclone upload
make deploy         # fly deploy for backend
```

Or the raw commands:

```bash
# Backend
cd backend && fly deploy

# Mobile
cd mobile && flutter build apk --release --no-shrink --no-tree-shake-icons \
  --dart-define=API_BASE_URL=https://mytravelpal-api.fly.dev \
  --dart-define=API_KEY=7637fb236013308ebf998843d924e15e56dce87457187e22a1a03c9c1e164d7a \
  --dart-define=SENTRY_DSN=https://3c46e071b627ae7c6c5cb4592cadbf60@o4511977727590400.ingest.de.sentry.io/4511977749086288
flutter install
rclone copy build/app/outputs/flutter-apk/app-release.apk blu3g3_drive_jjgonzalez5000:Desarrollo_APPS/APKs/
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

**Real APIs migration (prio ALTA 2026-08-30, ~1-2 días)**: sustituir
las heurísticas actuales por APIs de producción. El plan concreto:
- **Peajes**: TollGuru API ($5-30/mo). Ya tenemos el provider
  cableado (`providers/tollguru.py`), solo falta activar la key.
- **Gasolineras Alemania**: Tankerkönig (free con registro).
- **Adverse events**: EFFIS fires ya activo. USGS earthquakes free.
  Copernicus EMS landslides free. Añadir wire-ups.
- **Hoteles precios reales**: Amadeus for Developers (2k reqs/mes
  free) como MVP; Booking Affiliate cuando pase el partner review.
- **Restaurantes**: TripAdvisor Content API o Google Places para
  ratings reales. Ambos paid (~$17/1k requests Google Places).
Cost estimate ya en `project_launch_plan.md`. Retomar cuando el
usuario diga "vamos con las APIs reales".

**Facebook login (aplazado 2026-08-29)**: infraestructura cableada
en manifest + strings.xml (placeholders `REPLACE_WITH_FACEBOOK_APP_ID`).
Falta que el usuario complete el registro en developers.facebook.com
y pase el App ID + Client Token. Meta signup bug con verificación
por email nos bloqueó. Cuando lo tengamos, 5 min de trabajo:
sustituir 2 valores + añadir key hash release en la Android platform.
Coste 0. Prioridad baja: Google login cubre el grueso de usuarios
Android.

**Weather widget en pickers origen/destino** (idea 2026-08-29):
Mostrar un mini-widget del tiempo actual junto a los campos "Desde"
y "A" del PlanScreen (icon + temp actual). Tap → sheet con forecast
de 7 días (Open-Meteo daily endpoint, gratis). Ayuda al planner a
decidir si posponer el viaje. Coste: 1-2 h wire-up.

**Reverse geocode con dirección completa** (2026-08-29 → cerrado
2026-09-27): esto YA funcionaba. El pointer a `providers/geoapify_poi.py`
era stale — la implementación real vive en `providers/geocoding.py`
(`HybridGeocodingProvider.reverse` que prefiere Nominatim con
`zoom=18` y compone `"{road} {housenumber}, {city}"`).

## Backlog (existing)

- **Mercados / plataformas (2026-10-10)**: Europa primero. iOS (carpeta `ios/`,
  StoreKit, CarPlay, cuenta Apple 99 USD/año) cuando la suscripción convierta;
  antes, inglés pulido + páginas de ruta en inglés en mytravelpal.io para el
  turista US/AU que viaja por Europa. EE. UU. como mercado propio (gasolineras,
  peajes E-ZPass, millas/galones) = otro producto, descartado por ahora.
- **Web mytravelpal.io + afiliados (2026-10-10)**: programas directos
  (Booking/Expedia/Hotels.com) rechazaron la solicitud (sin tráfico ni web con
  contenido). Plan: Skimlinks (requiere dominio aprobado) + páginas de ruta
  estáticas generadas con el backend (cacheadas, build-time) y reaplicar a
  Booking una sola vez con la web y la app publicadas.

- TollGuru integration (real toll booth data) — code ready, needs API key
- Tankerkönig (Germany fuel) — needs API key
- Firebase Crashlytics — needs google-services.json
- Play Store submission — needs Privacy Policy + ToS + screenshots
- Android Auto POI Companion — Kotlin bridge designed, not started
- Getaway planner ("discover a trip from my location") — designed, not started
- Multi-provider hotel prices ("show lowest across sites") — Booking Affiliate
  Content API + Amadeus free tier (2k reqs/mo). Google-scraping ruled out
  (Google ToS §3.2.4 + anti-bot). Post-beta priority — needs traction to
  justify partner-program approval effort.
- Real hotel stars (fix OSM inaccuracies) — same Booking Affiliate integration
  above gives the official star classification. Tester reported "Idea Hotel
  Torino Mirafiori" tagged as 4★ in OSM but actually 3★. Solved when we
  ship the Booking integration.
- Hotel "auto-mark as booked" tras reserva vía Booking Affiliate — el usuario
  quería un botón "añadir a la ruta / marcar como reservado" que salga en el
  cálculo de gasto. Actualmente hay toggle manual por noche en day view; la
  automatización llega cuando integramos el callback de reservas de Booking.
- ~~Add more adverse event types (landslide, earthquake, avalanche, road
  closure, heatwave)~~ — CERRADO 2026-09-27. Todos los tipos + iconos +
  l10n ya estaban implementados en un sprint anterior; se activaron
  USGS earthquakes + Open-Meteo heatwave via env vars (`MYTRAVELPAL_QUAKES=usgs`,
  `MYTRAVELPAL_HEATWAVE=on`) en compose + fly.toml. Landslide + avalanche +
  road closure siguen con stub-provider — feeds documentados en el código
  para wire-up futuro (Copernicus EMS RSS, DGT/Bison Futé/ANAS/DATEX II).

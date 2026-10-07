# MyTravelPal — Registro de Solicitudes

*Actualizado: 2026-10-04*

---

## Cómo usar este documento

Registro cronológico de todas las solicitudes de features y fixes para la app MyTravelPal (planificador de road-trips europeos, Android). Actualizar al cierre de cada sesión de trabajo. Las entradas van en orden descendente (más reciente arriba).

---

## Leyenda de prioridades

| Icono | Significado |
|-------|-------------|
| 🔴 | Bloqueante — impide avanzar o lanzar |
| 🟠 | Alta — impacta funcionalidad core |
| 🟡 | Media — mejora significativa pero no urgente |
| 🟢 | Baja — polish, nice-to-have |
| ✅ | Completado |
| ⏳ | En progreso |
| 📋 | Backlog (pendiente) |

---

## ✅ Completados

### 2026-10-04

- ✅ "Tu hora de salida es óptima" — display simplificado en verde (quitado section header redundante), 7 locales
- ✅ Garaje vehículo personalizado — form completo (nombre + combustible + depósito + consumo + nivel inicial), backend acepta `__custom__`, specs en `notes` JSON
- ✅ HERE API nueva key — Routing v8 + Fuel Prices v3 operativos (clave antigua no daba acceso a estos endpoints)
- ✅ HERE Routing v8 como primary router — reemplaza OSRM como principal; OSRM eliminado. Tiempos más realistas, geometría real para toda Europa
- ✅ HERE Fuel Prices v3 — precios reales €/L para 25+ países europeos (`fuel.hereapi.com/v3/stations`). Endpoint correcto era v3/stations no v1/fuel-prices
- ✅ Gasolineras CH→Oslo/Berlin — fix en corridor_viewboxes (usaba solo origin+dest, ahora usa waypoints); fix en respuesta JSON (filtraba `price_available=False`)
- ✅ Sección "Gasolineras en ruta" — cuando no hay precios reales (price_available=False), la sección sigue mostrando ubicaciones de estaciones en vez de ocultarse
- ✅ Gráfico dual combustible — capa verde = paradas óptimas, capa azul = selección usuario. Se actualiza en tiempo real al añadir/quitar paradas
- ✅ "Ver todos los viajes" link en viajes recientes — cuando hay >5 viajes, aparece CTA que abre HistoryScreen
- ✅ `SavedTrip` guarda `TripProfile` snapshot — al "repetir" viaje, usa el perfil original (noches, vehículo, etc.)
- ✅ HERE Tolls como primary — `HereTollsProvider` con booth-level data + caché 24h segmentos. TollGuru solo si `MYTRAVELPAL_USE_TOLLGURU=1`
- ✅ TollGuru caché 48h — reduce transacciones al mínimo durante el trial
- ✅ TTS narración: `tts-1-hd` (más natural), control de velocidad 0.75x/1.0x/1.25x/1.5x en UI
- ✅ Austria e-control.at — precios reales gasolina/diesel Austria (spritpreisrechner.at, sin key)
- ✅ Portugal DGEG — precios reales gasolina/diesel Portugal (precoscombustiveis.dgeg.gov.pt, sin key)
- ✅ Atributos hotel en inglés — `brand`, `opening_hours`, `phone`, `stars`, `website` ahora localizados en `_featureLabelL10n`
- ✅ Moneda entre instalaciones — eliminado listener en `app.dart` que sobreescribía antes de `syncFromServer`
- ✅ EV en garaje — etiquetas "Batería (kWh)", "kWh/100km", "Nivel de carga inicial" para vehículos eléctricos
- ✅ AI personalización i18n — 18 claves en 7 idiomas (scenic routes, eco, local food, dietas, intereses)
- ✅ Settings collapsible — secciones en ExpansionTile (Vehículo, Apariencia, IA, Cuenta, Acerca de)
- ✅ Dashboard fixes — bug `list()` con trips rotas, `syncFromServer` re-sube trips locales al servidor
- ✅ Navegación GYG integrada (análisis) — decidido Opción C (tarjetas nativas + WebView). Pendiente API key GYG

### 2026-10-03

- ✅ Google auth fix — SHA-1 / package name mismatch en OAuth config
- ✅ Backend crash fix — `AdverseEventType.STORM` inexistente en enum
- ✅ X button en gasolinera no eliminaba la parada de la ruta
- ✅ "Ajustar preferencias" abre la prefs sheet correcta (no la genérica)
- ✅ Alertas con tipos específicos y descripciones ricas (severidad, zona)
- ✅ i18n: "sugerencias para ahorrar más" → contexto tiempo; "sismos" → "otros peligros"
- ✅ Fuel savings cascade model — litros reales vs. depósito lleno
- ✅ UI cozy polish — gradientes navy, glassmorphism, tokens amber/mint
- ✅ Paralelización backend — enrichment + geocoding en `asyncio.gather`
- ✅ SSE streaming añadido y revertido (core+enrich directo percibido más rápido)
- ✅ Sección "Ahorro en combustible" expandible en cost card
- ✅ Campo `detour_km` en entidades Hotel y Restaurant
- ✅ Savings breakdown en cost card — categorías + total ahorrado + %
- ✅ Hotels.com affiliate integrado (`camref=1110lR637`)
- ✅ GetYourGuide CTA en destinos (`partner_id=I4D8QQV`)
- ✅ Toggle "Actividades en destino" + CTAs por ciudad
- ✅ Civitatis + GYG affiliates registrados en consola
- ✅ Mapa de hoteles en modo fullscreen
- ✅ Sugerencia "Ya es óptimo" cuando la hora de salida ya es la mejor
- ✅ Litros reales mostrados en savings breakdown
- ✅ Mapa integrado en picker de restaurantes
- ✅ Gasolineras en rutas largas — corridor viewboxes fix (tramos > 500 km)
- ✅ Hotels vacíos con filtro económico → graceful degradation (muestra rango superior)
- ✅ 271 modelos de vehículos (era 119) + opción personalizada + motos + autocaravanas
- ✅ Registro affiliates: Booking.com, Hotels.com, Civitatis, GetYourGuide

---

### 2026-09-27 a 2026-10-02

- ✅ Maestro smoke suite — 10 flows + GitHub Actions CI (`e2e/`)
- ✅ i18n rest-stop "reason" via `Accept-Language` header en backend
- ✅ Data Safety CSV para Play Console — clear-first pass + BOTH collected+shared boxes
- ✅ Hotel arbitrage banner ("dormir en X sale €N/noche más barato")
- ✅ Adverse events: USGS earthquakes activado + Open-Meteo heatwave (`MYTRAVELPAL_QUAKES=usgs`, `MYTRAVELPAL_HEATWAVE=on`)
- ✅ Tipo "landslide", "avalanche", "road_closure" — stubs + iconos + l10n listos; feeds documentados para wire-up futuro
- ✅ Reverse geocode con dirección completa (`HybridGeocodingProvider.reverse`, `zoom=18`, `"{road} {housenumber}, {city}"`)
- ✅ Companion preflight sheet (checklist antes de iniciar modo conducción)
- ✅ Companion tab entry desde ResultScreen (Premium gate temporalmente retirado para dogfood)
- ✅ Data privacy tiers roadmap (Tier 1 pseudonymización live; Tier 2+3 documentados)
- ✅ POI selection — picker interactivo por día con fotos (Wikimedia + Google Places quota-capped)
- ✅ Optimizado section polish — origin→destination line, fuel sin precio eliminado, premium reserve
- ✅ Car model selector — top-271 EU models DB + tank size + rango real
- ✅ Tank level picker — filtra gasolineras dentro del rango seguro
- ✅ Progressive plan loading — core rápido + enrich diferido
- ✅ Play beta internal track operativo — URL opt-in + Google Group `mytravelpal-beta`

---

### Anteriores (2026-08 a 2026-09)

- ✅ FastAPI backend inicial en Fly.io CDG — OSRM routing (ES/PT/FR)
- ✅ Flutter app Android — Riverpod + flutter_map OSM
- ✅ Migración POI Nominatim → Geoapify (free tier, 3k req/día)
- ✅ Weather along route — Open-Meteo, 5 segmentos por ruta
- ✅ Total trip cost card — fuel + peajes + comidas + hotel
- ✅ Hotels grouped by stop/destination (no flat list)
- ✅ Interactive map — collapse/normal/fullscreen + POI markers
- ✅ MeteoAlarm provider — alertas meteorológicas severas EU
- ✅ EFFIS fires provider — incendios activos Europa
- ✅ Real-time alerts en result screen — fires, quakes, meteo
- ✅ Sentry configurado — backend + mobile, mismo DSN
- ✅ Booking.com affiliate (`aid=2418471`) en CTAs hotel
- ✅ Tutorial coach marks — PlanScreen + ResultScreen
- ✅ Google OAuth setup — Web Client ID, consent screen testing mode
- ✅ Companion mode — TripCompanionScreen + off-route detection
- ✅ Android Auto integration — POI Companion category, Kotlin bridge
- ✅ Hall of Fame — nick + country en perfil de usuario
- ✅ Feedback con screenshots — in-app report
- ✅ Fuel arbitrage banner — "llena en ES, ahorra €N"
- ✅ Narrative AI — OpenAI GPT trip story + TTS narración
- ✅ i18n 7 idiomas — EN/ES/FR/DE/IT/CA/PT
- ✅ Fly.io auto_stop_machines = suspend (~$5-8/mes)
- ✅ Makefile completo — `dev`, `test`, `mobile-local`, `deploy`, `mobile-prod`
- ✅ OSRM local — MLD graph ES/PT/FR, hot-reload FastAPI
- ✅ Prefs sheet — preferencias de viaje (velocidad, stops, comida, hotel cat.)
- ✅ Day plan v2 mobile quick wins — tiempos llegada, overhead pausa

---

## ⏳ En progreso

- ⏳ 🟡 % ahorro combustible mostrado en `_FuelSavingsSection` expandible (cálculo pendiente de exponer en API)
- ⏳ 🟡 Interacción gráfico ↔ lista gasolineras en fuel savings (tap en barra → highlight row)
- ⏳ 🟡 Imágenes hoteles/restaurantes vía Wikimedia geo-search mejorado (lat/lon bbox query)

---

## 📋 Backlog

### APIs reales

- ✅ TollGuru — reemplazado por HERE Tolls (free, booth-level, caché 24h segmentos)
- ✅ Play Store submission — completado
- 📋 🔴 Tankerkönig — gasolineras Alemania (free con registro; no respondieron aún)
- 📋 🟠 Booking Affiliate Content API — precios reales + estrellas oficiales + auto-mark booked (post partner-review approval). Hotels.com Expedia activos ya
- 📋 🟡 TripAdvisor Content API o Google Places — ratings reales restaurantes (~$17/1k req Google Places)

---

### Distribución y lanzamiento

- ✅ Play Store submission — completado (internal track activo)
- 📋 🔴 Facebook login — infraestructura lista (manifest + strings.xml con placeholders); bloqueado por Meta verification bug. Necesita App ID + Client Token + key hash release. ~5 min cuando el usuario complete developers.facebook.com
- 📋 🟠 Paywall gates antes de open beta — 3 tiers: Free / Essential €19.99/yr / Premium €39.99/yr, trial 14 días, Play Billing
- 📋 🟡 Promo video — path B semi-AI recomendado; deferred hasta pre-launch

---

### Premium features

- 📋 🟠 Trip monitor Premium — re-scan background de viajes guardados: nuevos problemas + mejores precios hotel (FCM-triggered backend job)
- 📋 🟠 User learning — perfil servidor (cuestionario explícito + tap aggregates) → contexto LLM. Phase 1: cuestionario post-closed-beta
- 📋 🟡 Social sharing — share ruta en X/Instagram desde Companion. Post-closed-beta
- 📋 🟡 AI dynamic flow (Trip Inspiration) — two-stage design + enrichment (A refinement / B per-day justification / C slot-fill). Kick off post-APIs migration
- 📋 🟡 Voice UX — push-to-talk commands en closed beta; free convo Premium más tarde (driving-time convo necesita revisión legal antes de landing)
- 📋 🟡 Companion Premium gate — restaurar gate antes de beta (actualmente desactivado para dogfood)
- 📋 🟢 Hotel "auto-mark as booked" tras reserva Booking Affiliate — toggle manual por noche ya existe; automatización llega con callback de reservas Booking

---

### Seguridad y privacidad

- 📋 🟠 Data privacy Tier 2 — cifrado por campo (pre-launch hardening)
- 📋 🟡 Dashboard Grafana — carve out `mtp_dashboard` read-only Postgres role (pre-launch)
- 📋 🟡 AI cost defense capas 3-6 — caching + anomaly detection + tiering (open beta + launch)
- 📋 🟢 Data privacy Tier 3 — zero-knowledge subset (deferred)

---

### Bugs conocidos

- 📋 🔴 Android Auto crash — AA app crashea en arranque; necesita `logcat` + DHU test; probable residual por package rename
- 📋 🟡 Real hotel stars — OSM inexacto (ej. "Idea Hotel Torino Mirafiori" 4★ OSM vs 3★ real); se resuelve con integración Booking Affiliate

---

### Nuevas funcionalidades

- 📋 🟠 E2E GUI tests completos — 10 smoke flows Maestro + integration_test/patrol + golden tests. Deferred hasta Companion + garage + hazards estables
- 📋 🟠 Progress streaming real (SSE) — dialog de carga con progreso real. Deferred post-beta; interim adaptive-dwell ya enviado
- 📋 🟡 Weather widget en pickers origen/destino — mini icon + temp actual; tap → 7-day forecast sheet (Open-Meteo daily, gratis). ~1-2h
- 📋 🟡 Day plan v2 backend — POI names reales en rest stops, arrival-time realism factor, backend selects stops by prefs
- 📋 🟡 RV + truck flows — autocaravanas (campings) y camioneros (truck stops, EU 561/2006). Pre-beta study
- 📋 🟡 Social features — grupos family/friends + Hall of Fame gamification. MVPs pre-beta abierta
- 📋 🟡 Getaway planner ("discover a trip from my location") — segundo tab producto; diseño acordado, no iniciado
- 📋 🟡 Parking real-time — static POI ya enviado; ocupación en tiempo real (feeds municipales → Parkopedia) + reserva in-app post-beta
- 📋 🟢 Hotel arbitrage banner mejorado — modal con comparativa por noches. ~3-4h post-beta
- 📋 🟢 Safety features — fatigue detection (acelerómetro) + crash detection + SOS al 112 + contacto emergencia. Post-beta Premium
- 📋 🟢 Multi-provider hotel prices — "show lowest across sites" (Booking Affiliate + Amadeus). Post-traction
- 📋 🟢 Android Auto POI Companion completo — Kotlin bridge diseñado, no iniciado. 3-4 semanas fases
- 📋 🟢 Social strategy fases 2-5 — paid ads solo tras CAC/LTV probado

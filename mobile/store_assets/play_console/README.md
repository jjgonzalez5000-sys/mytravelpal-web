# Play Console assets — MyTravelPal

Everything Google Play Console asks for when creating a closed-testing track and preparing for public release.

## Structure

```
play_console/
├── README.md                    ← this file
├── copy/                        ← store descriptions per locale
│   ├── en.md                    ← English (default, required)
│   ├── es.md                    ← Spanish (Spain & Portugal market)
│   ├── fr.md                    ← French
│   ├── de.md                    ← German (DACH market)
│   └── it.md                    ← Italian
├── graphics/
│   ├── feature_graphic.svg      ← 1024×500 source
│   └── feature_graphic.png      ← 1024×500 rendered, ready to upload
├── screenshots.md               ← capture plan (8 shots per locale)
└── data_safety.md               ← pre-filled Data Safety form answers
```

## Play Console upload checklist

### 1. Store listing (per language)

For each locale in `copy/`:
- App name → **App name** field (line 1 of each MD)
- Short description → **Short description** (line 2)
- Full description → **Full description** (the fenced block)

### 2. Graphics

- App icon → `../assets/icon/play_store_icon_512.png` (512×512, must be a PNG, no alpha)
- Feature graphic → `graphics/feature_graphic.png` (1024×500)
- Phone screenshots → capture per `screenshots.md`, upload 8 per language
- Tablet screenshots → SKIP for beta (revisit at public launch)

### 3. Content rating

- Fill IARC questionnaire honestly:
  - No violence
  - No sex / nudity
  - No user-generated content shared publicly (trips are private)
  - Location tracking → **Yes** (declare it, since Companion mode uses it)
  - Expected rating: **PEGI 3 / Everyone**

### 4. Data safety

Follow `data_safety.md` verbatim. Match every claim to the actual code + `docs/privacy.md`.

### 5. App category

- Category → **Travel & Local**
- Tags → Travel > Trip Planner (primary), Travel > Navigation (secondary)

### 6. Contact details

- Email → `hello@mytravelpal.io`
- Website → `https://mytravelpal.io`
- Privacy policy → `https://mytravelpal.io/privacy`

### 7. Closed testing track

- Track name → `closed-beta-01`
- Testers → Google Groups list (create `mytravelpal-beta@googlegroups.com` or invite by email)
- Countries → Spain, Portugal, France, Germany, Italy, Netherlands, Belgium, Austria, Switzerland, United Kingdom (all EU-facing markets we've localised)
- Release name → semver from `pubspec.yaml`, e.g. `0.9.0 (beta)`

### 8. Signing

- Play App Signing → **Enable** (Google manages the upload key, you keep the release key backup at `~/keystores/mytravelpal-release.jks`)
- SHA-1 already registered in Firebase / Google Cloud Console per `CLAUDE.md`

### 9. What's new (release notes)

For the initial closed beta, in each language:

**EN**
```
Closed beta 01 — European road-trip planner with hotels, real fuel prices, tolls, AI trip inspiration, and Companion drive mode. Thanks for testing! Send feedback to hello@mytravelpal.io.
```

**ES**
```
Beta cerrada 01 — Planificador de road trips europeos con hoteles, precios reales de gasolina, peajes, inspiración IA y modo Companion. ¡Gracias por probar! Envía feedback a hello@mytravelpal.io.
```

## Time budget

- Store listing (5 locales × copy paste) → 30 min
- Feature graphic upload + icon → 5 min
- Screenshots capture (2 locales × 8 shots) → 40 min
- Data safety form → 30 min
- Content rating questionnaire → 15 min
- Signing + track config → 10 min
- **Total: ~2 hours** to submit for review

Google review of closed testing: 3-7 days first submission.

# Distributing the APK to family / friends

This guide covers how to build, sign, share, and — most importantly —
**wire the backend URL** for people testing the app on their own
Android devices.

## Build

```bash
cd mobile
flutter build apk --release --split-per-abi \
    --dart-define=API_BASE_URL=<backend-url>
```

`--split-per-abi` produces three APKs (one per Android architecture):

- `app-arm64-v8a-release.apk` — most modern phones (2018+). Ship this.
- `app-armeabi-v7a-release.apk` — older phones.
- `app-x86_64-release.apk` — emulators, some Chromebooks.

They land in `mobile/build/app/outputs/flutter-apk/`. About 20-24 MB
each. If you're not sure which to ship, `app-arm64-v8a-release.apk`
covers 95 % of installed Android devices.

## Signing

The current build uses the debug keystore (`~/.android/debug.keystore`).
That's fine for family testing — the APK installs on any device — but:

- Google Play won't accept debug-signed APKs. When you're ready to
  publish, create a release keystore and wire it via
  `android/app/build.gradle.kts` + `key.properties`.
- Debug-signed APKs from different machines can't upgrade each other.
  Everyone testing gets *their* copy from you consistently.

## The backend URL problem

The APK is a static app bundle. When it runs on your family's phone,
it needs to talk to a backend. The URL was baked in at build time via
`--dart-define=API_BASE_URL=…`. Three realistic options:

### Option 1 — Same WiFi as your dev machine (quick)

Run the backend on your machine:

```bash
cd backend
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Note the `0.0.0.0` — required so devices other than localhost can
reach it. Find your machine's LAN IP:

```bash
hostname -I | awk '{print $1}'
# e.g. 192.168.0.97
```

Build the APK pointing at that IP:

```bash
flutter build apk --release --split-per-abi \
    --dart-define=API_BASE_URL=http://192.168.0.97:8000
```

Trade-offs: the family member must be on **your** WiFi. Your machine
must be up whenever they open the app. LAN IP changes when your
router reboots.

### Option 2 — Free tunnel (ngrok / Cloudflare Tunnel)

Expose your local backend to a public URL without deploying:

```bash
# with ngrok
ngrok http 8000
# gives you https://xxxxx.ngrok-free.app

flutter build apk --release --split-per-abi \
    --dart-define=API_BASE_URL=https://xxxxx.ngrok-free.app
```

Trade-offs: still requires your machine to be running the backend.
Free ngrok URLs change every restart — rebuild the APK when the URL
changes. Fine for a couple of days of testing.

### Option 3 — Deploy the backend (recommended for family testing)

Full walkthrough in [deployment.md](deployment.md) — deploys to
Fly.io from your local `Dockerfile` (source stays on your machine,
API URL is protected by an `X-MyTravelPal-Api-Key` gate, HTTPS is
automatic, free tier is enough for a handful of testers).

After `fly deploy`:

```bash
cd mobile
flutter build apk --release --split-per-abi \
    --dart-define=API_BASE_URL=https://<your-app>.fly.dev \
    --dart-define=API_KEY=<the-secret-you-set-on-fly>
```

The APK carries the key so it can talk to your backend; random
strangers who discover the URL get 401. Trade-off: someone
reverse-engineering the APK can extract the key. That's fine for
"prevent random discovery" — real per-user protection is the JWT
auth flow that's already wired.

## Share the APK

Once you've picked an option and rebuilt, share the file:

- **WhatsApp / Telegram / Signal** — attach the `.apk` directly. Every
  IM app supports arbitrary attachments up to ~2 GB.
- **Email** — some providers block `.apk` attachments; zip it first.
- **Google Drive / Dropbox** — upload, share the link.
- **`adb install`** — if the recipient hands you the phone with USB
  debugging enabled: `adb install app-arm64-v8a-release.apk`.

## The recipient's install flow

Android blocks APKs from unknown sources by default. On the recipient's
phone:

1. Tap the APK in WhatsApp / file manager / whatever.
2. Android says *"For your security, your phone is not allowed to
   install unknown apps from this source"*. Tap **Settings**.
3. Enable **Allow from this source**. Back out and tap Install.
4. On Xiaomi/MIUI, also enable **Install via USB** in Developer options
   if installing over `adb`.

## What the recipient will actually see

- **First launch** → onboarding slides in their device language
  (EN/ES/FR/IT/DE fall back to English if none match).
- Then the login screen — Google/Facebook/Apple buttons don't work
  without OAuth client configuration. **Tell them to tap "Continue as
  demo"** and enter any name/email — it hits the backend's demo
  provider and issues a real JWT.
- Then the planner. Every feature works if the backend URL is reachable.

## Rebuild checklist when something changes

- Backend URL changed → rebuild with a new `--dart-define`.
- Locale strings changed → `flutter gen-l10n` (or `flutter analyze`)
  regenerates before build.
- New Dart code → `flutter build` picks it up automatically.

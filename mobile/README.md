# MyTravelPal — Mobile

Flutter app: pre-trip planning UI that consumes the [backend](../backend) API.

## First-time setup

The Dart source is committed; the native platform folders (`android/`, `ios/`,
`linux/`, `macos/`, `windows/`, `web/`) are NOT — regenerate them with the
Flutter tooling on your machine:

```bash
cd mobile
flutter create . --project-name mytravelpal --org com.mytravelpal --platforms=android,ios
flutter pub get
```

## Run

Start the backend first:

```bash
cd ../backend && docker compose up
```

Then run the app pointing at your local API. The backend base URL is read
from the `API_BASE_URL` compile-time env var (defaults to
`http://10.0.2.2:8000` — the Android emulator's alias for the host machine):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For an iOS simulator use `http://127.0.0.1:8000` instead; for a physical
device use your machine's LAN IP.

## Test

```bash
flutter test
```

## Layout

```
lib/
├── main.dart              app entrypoint + Riverpod ProviderScope
├── app.dart               MaterialApp + routing
├── theme.dart             light + dark themes
├── api/
│   ├── api_client.dart    HTTP client
│   ├── config.dart        base URL from --dart-define
│   └── models.dart        DTOs mirroring backend contract
├── screens/
│   ├── plan_screen.dart   form: origin, destination, time, countries
│   └── result_screen.dart map + time-window chart + fuel list
└── widgets/
    ├── time_window_chart.dart
    ├── route_map.dart
    └── country_selector.dart
```

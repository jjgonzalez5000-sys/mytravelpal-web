import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/providers.dart';
import 'package:mytravelpal/screens/result_screen.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:mytravelpal/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _o = LatLon(lat: 47, lon: 8);
const _d = LatLon(lat: 40, lon: -3);
final _departure = DateTime(2026, 10, 20, 8);

TripPlanResponse _plan({double km = 1000}) => TripPlanResponse(
      route: RouteInfo(
        distanceKm: km,
        freeFlowMinutes: 600,
        polyline: '',
        tollCostEur: 0,
        countriesCrossed: const [],
        geometry: const [
          _o,
          LatLon(lat: 44, lon: 3),
          _d,
        ],
      ),
      timeWindows: [
        TimeWindow(
          departureAt: _departure,
          estimatedMinutes: 600,
          trafficFactor: 1,
          recommended: true,
        ),
      ],
      fuelPrices: const [],
      hotels: const [],
      restaurants: const [],
      restStops: const [],
      adverseEvents: const [],
    );

class _FakeApi extends ApiClient {
  final List<TripPlanRequest> coreCalls = [];
  final List<TripPlanRequest> enrichCalls = [];
  Completer<TripPlanResponse>? coreGate;
  Object? coreError;

  @override
  Future<TripPlanResponse> planTripCore(
    TripPlanRequest request, {
    String? locale,
  }) {
    coreCalls.add(request);
    if (coreError != null) return Future.error(coreError!);
    return coreGate?.future ?? Future.value(_plan());
  }

  @override
  Future<TripPlanResponse> planTripEnrich(
    TripPlanRequest request, {
    String? locale,
  }) {
    enrichCalls.add(request);
    return Future.value(_plan());
  }
}

/// The screen already logs layout assertions and map-tile failures in tests;
/// anything else still fails the test. Off Android, the foreground-service
/// wrapper passes straight through (its platform channel never answers here).
void _screenTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('ListTile') || text.contains('tile.openstreetmap')) {
        return;
      }
      previous?.call(details);
    };
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = previous;
    }
  });
}

Future<Widget> _host(_FakeApi api, {Map<String, dynamic>? selections}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await AppPrefs.open();
  final request = TripPlanRequest(
    origin: _o,
    destination: _d,
    desiredDepartureAt: _departure,
  );
  return ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ResultScreen(
        request: request,
        origin: const GeocodeResult(
            displayName: 'Basel', coordinate: _o, country: Country.fr),
        destination: const GeocodeResult(
            displayName: 'Madrid', coordinate: _d, country: Country.es),
        response: _plan(),
        desiredDepartureAt: _departure,
        initialSelections: selections,
      ),
    ),
  );
}

const _savedStop = {
  'stop_plans': [
    {
      'key': 'place:p1',
      'name': 'Lyon bakery',
      'lat': 45.76,
      'lon': 4.83,
      'source': 'myPlace',
      'visit_minutes': 30,
      'detour_minutes': 5,
      'along_km': 300.0,
    },
  ],
};

void main() {
  _screenTest('opening a plan with nothing changed never recalculates',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(await _host(api));
    await tester.pump(const Duration(seconds: 6));
    expect(api.coreCalls, isEmpty);
    expect(api.enrichCalls, isEmpty);
    expect(find.text('Recalculate route'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _screenTest('a stop restored from a saved trip is applied once, by itself',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(await _host(api, selections: _savedStop));
    await tester.pump();
    expect(api.coreCalls, isEmpty, reason: 'waits for the debounce');

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.coreCalls, hasLength(1));
    final stops = api.coreCalls.single.waypoints.where((w) => !w.viaOnly);
    expect(stops.single.coordinate.lat, closeTo(45.76, 1e-9));

    await tester.pump(const Duration(seconds: 1));
    expect(api.enrichCalls, hasLength(1));

    // The plan now matches the request: nothing else is asked.
    await tester.pump(const Duration(seconds: 10));
    expect(api.coreCalls, hasLength(1));
    expect(api.enrichCalls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  _screenTest('a failed recalculation shows retry and discard, no dialog',
      (tester) async {
    final api = _FakeApi()..coreError = ApiException(503, 'down');
    await tester.pumpWidget(await _host(api, selections: _savedStop));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.coreCalls, hasLength(1));
    expect(find.text('Could not update the route'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Discard changes'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // Not retried by itself.
    await tester.pump(const Duration(seconds: 20));
    expect(api.coreCalls, hasLength(1));

    api.coreError = null;
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.coreCalls, hasLength(2));
    expect(find.text('Could not update the route'), findsNothing);
  });

  _screenTest('discarding restores the plan on screen and stops asking',
      (tester) async {
    final api = _FakeApi()..coreError = ApiException(503, 'down');
    await tester.pumpWidget(await _host(api, selections: _savedStop));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Discard changes'), findsOneWidget);

    await tester.tap(find.text('Discard changes'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Could not update the route'), findsNothing);
    expect(api.coreCalls, hasLength(1));
  });
}

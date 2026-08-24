import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/design/theme_toggle.dart';
import 'package:mytravelpal/providers.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:mytravelpal/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RouteInfo.fromJson', () {
    test('parses geometry as [lon,lat] → LatLon(lat,lon)', () {
      final raw = jsonDecode('''
        {
          "distance_km": 100, "free_flow_minutes": 60,
          "polyline": "p", "toll_cost_eur": 10, "countries_crossed": ["FR"],
          "geometry": [[2.35, 48.85], [3.0, 48.0], [-3.7, 40.4]]
        }
      ''') as Map<String, dynamic>;
      final r = RouteInfo.fromJson(raw);
      expect(r.geometry, hasLength(3));
      expect(r.geometry.first.lat, 48.85);
      expect(r.geometry.first.lon, 2.35);
      expect(r.geometry.last.lat, 40.4);
    });

    test('defaults geometry to empty when missing', () {
      final raw = jsonDecode('''
        {
          "distance_km": 100, "free_flow_minutes": 60,
          "polyline": "p", "toll_cost_eur": 10, "countries_crossed": ["FR"]
        }
      ''') as Map<String, dynamic>;
      expect(RouteInfo.fromJson(raw).geometry, isEmpty);
    });
  });

  group('TollAlternative.fromJson', () {
    test('parses full payload', () {
      final raw = jsonDecode('''
        {
          "distance_km": 1500, "duration_minutes": 900, "toll_cost_eur": 0,
          "savings_eur": 210, "time_penalty_minutes": 90,
          "extra_distance_km": 200, "worth_it": true,
          "geometry": [[2, 48], [3, 47]]
        }
      ''') as Map<String, dynamic>;
      final alt = TollAlternative.fromJson(raw);
      expect(alt.savingsEur, 210);
      expect(alt.timePenaltyMinutes, 90);
      expect(alt.worthIt, true);
      expect(alt.geometry, hasLength(2));
    });
  });

  group('TripPlanRequest.toJson', () {
    test('emits include_toll_alternative when enabled', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        includeTollAlternative: true,
      );
      expect(req.toJson()['include_toll_alternative'], true);
    });

    test('omits include_toll_alternative when disabled', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      expect(req.toJson().containsKey('include_toll_alternative'), isFalse);
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('tollAlternative is null when field is missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      expect(TripPlanResponse.fromJson(raw).tollAlternative, isNull);
    });

    test('tollAlternative is parsed when present', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "toll_alternative": {
            "distance_km": 120, "duration_minutes": 80, "toll_cost_eur": 0,
            "savings_eur": 15, "time_penalty_minutes": 20,
            "extra_distance_km": 20, "worth_it": true, "geometry": []
          }
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.tollAlternative, isNotNull);
      expect(parsed.tollAlternative!.savingsEur, 15);
    });
  });

  group('Theme toggle', () {
    testWidgets('cycles system → light → dark and persists', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.open();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appPrefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              appBar: null,
              body: Center(child: ThemeToggleButton()),
            ),
          ),
        ),
      );

      // Default is system.
      expect(find.byIcon(Icons.brightness_auto_outlined), findsOneWidget);

      // Open menu, pick Dark.
      await tester.tap(find.byIcon(Icons.brightness_auto_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(prefs.themeMode, ThemeMode.dark);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    });
  });
}

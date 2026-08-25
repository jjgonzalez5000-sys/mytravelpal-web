import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Country enum expansion', () {
    test('covers all 30 supported countries', () {
      expect(Country.values.length, 31);
    });

    test('DE / PL / PT / GB roundtrip via fromCode', () {
      for (final code in <String>['DE', 'PL', 'PT', 'GB', 'IE', 'NO', 'IS']) {
        final c = Country.fromCode(code);
        expect(c.code, code);
      }
    });

    test('display names are populated', () {
      for (final c in Country.values) {
        expect(c.displayName, isNotEmpty);
      }
    });
  });

  group('PartialTollSkip.fromJson', () {
    test('parses a payload', () {
      final raw = jsonDecode('''
        {
          "label": "Toll stretch 2 / 5",
          "distance_from_origin_km": 300,
          "savings_eur": 25.5,
          "time_penalty_minutes": 7.5,
          "extra_distance_km": 5.0,
          "worth_it": true,
          "lat": 46.2, "lon": 4.5
        }
      ''') as Map<String, dynamic>;
      final s = PartialTollSkip.fromJson(raw);
      expect(s.savingsEur, 25.5);
      expect(s.worthIt, true);
      expect(s.coordinate.lat, 46.2);
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('parses partialTollSkips when present', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "partial_toll_skips": [
            {"label": "s1", "distance_from_origin_km": 50, "savings_eur": 10,
             "time_penalty_minutes": 5, "extra_distance_km": 3,
             "worth_it": true, "lat": 45, "lon": 4}
          ]
        }
      ''') as Map<String, dynamic>;
      final r = TripPlanResponse.fromJson(raw);
      expect(r.partialTollSkips, hasLength(1));
    });

    test('defaults partialTollSkips to empty when missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      expect(TripPlanResponse.fromJson(raw).partialTollSkips, isEmpty);
    });
  });

  group('ApiClient premium header', () {
    test('sends X-MyTravelPal-Premium: true when setPremium(true)', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'narrative': 'x',
            'origin_name': 'a',
            'destination_name': 'b',
            'generated_at': '2026-08-24T08:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      client.setPremium(true);
      await client.tripNarrative(
        planRequest: TripPlanRequest(
          origin: const LatLon(lat: 48, lon: 2),
          destination: const LatLon(lat: 40, lon: -3),
          desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        ),
        originName: 'a',
        destinationName: 'b',
      );
      expect(captured.headers['x-mytravelpal-premium'], 'true');
    });

    test('does not send header when setPremium(false)', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'results': <Map<String, dynamic>>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      await client.geocode('paris');
      expect(
        captured.headers.containsKey('x-mytravelpal-premium'),
        isFalse,
      );
    });
  });

  group('AppPrefs.isPremium', () {
    test('persists across opens', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.open();
      expect(prefs.isPremium, isFalse);
      await prefs.setPremium(true);
      final prefs2 = await AppPrefs.open();
      expect(prefs2.isPremium, isTrue);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';

void main() {
  test('planTrip posts JSON and parses response', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'route': {
            'distance_km': 100.0,
            'free_flow_minutes': 60.0,
            'polyline': 'p',
            'toll_cost_eur': 5.0,
            'countries_crossed': ['FR'],
          },
          'time_windows': [
            {
              'departure_at': '2026-08-24T08:00:00',
              'estimated_minutes': 60.0,
              'traffic_factor': 1.0,
              'recommended': true,
            },
          ],
          'fuel_prices': <Map<String, Object?>>[],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://test.local'),
      httpClient: mock,
    );

    final resp = await client.planTrip(TripPlanRequest(
      origin: const LatLon(lat: 1, lon: 2),
      destination: const LatLon(lat: 3, lon: 4),
      desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      countries: const [Country.fr],
    ));

    expect(captured.url.toString(), 'http://test.local/v1/trips/plan');
    expect(captured.method, 'POST');
    expect(captured.headers['Content-Type'], 'application/json');
    expect(resp.timeWindows.single.recommended, isTrue);
  });

  test('planTrip throws ApiException on non-200', () async {
    final mock = MockClient((_) async => http.Response('boom', 500));
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://test.local'),
      httpClient: mock,
    );
    expect(
      () => client.planTrip(TripPlanRequest(
        origin: const LatLon(lat: 1, lon: 2),
        destination: const LatLon(lat: 3, lon: 4),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        countries: const [Country.fr],
      )),
      throwsA(isA<ApiException>()),
    );
  });

  test('geocode calls /v1/geocode and parses results', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'results': [
            {
              'display_name': 'Madrid, Spain',
              'coordinate': {'lat': 40.4168, 'lon': -3.7038},
              'country': 'ES',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://test.local'),
      httpClient: mock,
    );
    final results = await client.geocode('madrid');
    expect(captured.method, 'GET');
    expect(captured.url.path, '/v1/geocode');
    expect(captured.url.queryParameters['q'], 'madrid');
    expect(results.single.country, Country.es);
  });

  test('geocode short-circuits on empty query without hitting network',
      () async {
    var called = false;
    final mock = MockClient((_) async {
      called = true;
      return http.Response('should not be called', 500);
    });
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'http://test.local'),
      httpClient: mock,
    );
    expect(await client.geocode('   '), isEmpty);
    expect(called, isFalse);
  });
}

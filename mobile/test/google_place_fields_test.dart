import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/stop_suggestion.dart';

void main() {
  group('Google ids on the wire models', () {
    test('meal and sleep stops expose id and address as sheet attributes', () {
      final meal = MealStopOpt.fromJson({
        'slot': 'lunch',
        'at': '2026-10-12T13:00:00',
        'distance_from_origin_km': 120.0,
        'google_place_id': 'ChIJm',
        'restaurant_address': 'Calle Sol 1',
      });
      expect(meal.mapsAttributes,
          {'google_place_id': 'ChIJm', 'address_line1': 'Calle Sol 1'});
      final sleep = SleepStopOpt.fromJson({
        'at': '2026-10-12T21:00:00',
        'distance_from_origin_km': 300.0,
        'google_place_id': 'ChIJs',
        'hotel_address': 'Calle Luna 2',
      });
      expect(sleep.mapsAttributes,
          {'google_place_id': 'ChIJs', 'address_line1': 'Calle Luna 2'});
    });

    test('old payloads without the fields still parse', () {
      final meal = MealStopOpt.fromJson({
        'slot': 'lunch',
        'at': '2026-10-12T13:00:00',
        'distance_from_origin_km': 120.0,
      });
      expect(meal.googlePlaceId, isNull);
      expect(meal.mapsAttributes, isEmpty);
    });

    test('fuel stations and suggestions carry the id inside attributes', () {
      final fuel = FuelPrice.fromJson({
        'station_name': 'Repsol',
        'country': 'ES',
        'price_eur_per_l': 1.5,
        'distance_from_origin_km': 10.0,
        'attributes': {'brand': 'Repsol'},
        'google_place_id': 'ChIJf',
      });
      expect(fuel.attributes['google_place_id'], 'ChIJf');
      expect(fuel.attributes['brand'], 'Repsol');
      final s = StopSuggestion.fromJson({
        'id': 'a',
        'name': 'Mirador',
        'lat': 40.0,
        'lon': -3.0,
        'category': 'viewpoint',
        'google_place_id': 'ChIJv',
        'google_maps_url': 'https://maps.google.com/?cid=9',
      });
      expect(s.attributes['google_place_id'], 'ChIJv');
      expect(s.attributes['google_maps_url'], 'https://maps.google.com/?cid=9');
    });
  });

  group('ApiClient.resolvePlace', () {
    ApiClient client(http.Client c) => ApiClient(
          config: const ApiConfig(baseUrl: 'http://test.local'),
          httpClient: c,
        );

    test('sends the query and parses the match', () async {
      late Uri seen;
      final api = client(MockClient((req) async {
        seen = req.url;
        return http.Response(
          jsonEncode({
            'google_place_id': 'ChIJr',
            'google_maps_url': 'https://maps.google.com/?cid=1',
            'google_address': 'Calle Mayor 5',
          }),
          200,
        );
      }));
      final r = await api.resolvePlace(
        name: 'Casa Pepe',
        lat: 40.1,
        lon: -3.2,
        address: 'Toledo',
      );
      expect(seen.path, '/v1/places/resolve');
      expect(seen.queryParameters['name'], 'Casa Pepe');
      expect(seen.queryParameters['address'], 'Toledo');
      expect(r?.googlePlaceId, 'ChIJr');
      expect(r?.address, 'Calle Mayor 5');
    });

    test('empty match, errors and network failures give null', () async {
      final empty = client(MockClient((_) async =>
          http.Response(jsonEncode({'google_place_id': null}), 200)));
      expect(await empty.resolvePlace(name: 'x', lat: 1, lon: 2), isNull);
      final err = client(MockClient((_) async => http.Response('no', 429)));
      expect(await err.resolvePlace(name: 'x', lat: 1, lon: 2), isNull);
      final boom = client(MockClient((_) async => throw Exception('offline')));
      expect(await boom.resolvePlace(name: 'x', lat: 1, lon: 2), isNull);
    });
  });
}

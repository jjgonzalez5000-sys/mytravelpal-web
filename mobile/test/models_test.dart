import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';

void main() {
  group('Country', () {
    test('roundtrips through code', () {
      for (final c in Country.values) {
        expect(Country.fromCode(c.code), c);
      }
    });

    test('rejects unknown codes', () {
      expect(() => Country.fromCode('XX'), throwsArgumentError);
    });
  });

  group('TripPlanRequest.toJson', () {
    test('includes countries when provided', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48.8566, lon: 2.3522),
        destination: const LatLon(lat: 40.4168, lon: -3.7038),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        countries: const [Country.fr, Country.es],
      );
      expect(req.toJson(), {
        'origin': {'lat': 48.8566, 'lon': 2.3522},
        'destination': {'lat': 40.4168, 'lon': -3.7038},
        'desired_departure_at': '2026-08-24T08:00:00.000Z',
        'countries': ['FR', 'ES'],
      });
    });

    test('omits countries when null so backend auto-detects', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48.8566, lon: 2.3522),
        destination: const LatLon(lat: 40.4168, lon: -3.7038),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      expect(req.toJson().containsKey('countries'), isFalse);
    });
  });

  group('GeocodeResult.fromJson', () {
    test('parses a geocode result', () {
      final raw = jsonDecode('''
        {
          "display_name": "Madrid, Spain",
          "coordinate": {"lat": 40.4168, "lon": -3.7038},
          "country": "ES"
        }
      ''') as Map<String, dynamic>;
      final parsed = GeocodeResult.fromJson(raw);
      expect(parsed.displayName, 'Madrid, Spain');
      expect(parsed.coordinate.lat, 40.4168);
      expect(parsed.country, Country.es);
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('parses a full backend response', () {
      final raw = jsonDecode('''
        {
          "route": {
            "distance_km": 1316.1,
            "free_flow_minutes": 831.2,
            "polyline": "mock:abc",
            "toll_cost_eur": 210.58,
            "countries_crossed": ["FR", "ES"]
          },
          "time_windows": [
            {
              "departure_at": "2026-08-24T05:30:00",
              "estimated_minutes": 872.8,
              "traffic_factor": 1.05,
              "recommended": true
            },
            {
              "departure_at": "2026-08-24T10:00:00",
              "estimated_minutes": 914.4,
              "traffic_factor": 1.10,
              "recommended": false
            }
          ],
          "fuel_prices": [
            {
              "station_name": "Station 1",
              "country": "FR",
              "price_eur_per_l": 1.718,
              "distance_from_origin_km": 50.0
            }
          ]
        }
      ''') as Map<String, dynamic>;

      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.route.distanceKm, 1316.1);
      expect(parsed.route.countriesCrossed, [Country.fr, Country.es]);
      expect(parsed.timeWindows, hasLength(2));
      expect(parsed.timeWindows.first.recommended, isTrue);
      expect(parsed.fuelPrices.single.country, Country.fr);
    });
  });
}

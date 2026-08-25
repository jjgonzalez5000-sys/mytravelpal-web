import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/storage/saved_trip.dart';

void main() {
  group('TripSavings.fromJson', () {
    test('parses populated payload', () {
      final raw = jsonDecode(
        '{"time_saved_minutes_vs_desired": 41.5, "money_saved_eur_vs_tolls": 12.0}',
      ) as Map<String, dynamic>;
      final s = TripSavings.fromJson(raw);
      expect(s.timeSavedMinutesVsDesired, 41.5);
      expect(s.moneySavedEurVsTolls, 12.0);
    });
  });

  group('TripPlanResponse.fromJson savings', () {
    test('defaults to zero when field is missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      final r = TripPlanResponse.fromJson(raw);
      expect(r.savings.timeSavedMinutesVsDesired, 0);
      expect(r.savings.moneySavedEurVsTolls, 0);
    });

    test('parses savings when present', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "savings": {"time_saved_minutes_vs_desired": 25, "money_saved_eur_vs_tolls": 8}
        }
      ''') as Map<String, dynamic>;
      final r = TripPlanResponse.fromJson(raw);
      expect(r.savings.timeSavedMinutesVsDesired, 25);
      expect(r.savings.moneySavedEurVsTolls, 8);
    });
  });

  group('SavedTrip savings fields', () {
    SavedTrip sample() => SavedTrip(
          id: 'x',
          origin: const GeocodeResult(
            displayName: 'A', coordinate: LatLon(lat: 48, lon: 2),
            country: Country.fr,
          ),
          destination: const GeocodeResult(
            displayName: 'B', coordinate: LatLon(lat: 40, lon: -3),
            country: Country.es,
          ),
          desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
          savedAt: DateTime.utc(2026, 8, 20, 12),
          distanceKm: 1000,
          recommendedDepartureAt: DateTime.utc(2026, 8, 24, 5, 30),
          recommendedMinutes: 720,
          countriesCrossed: const [Country.fr, Country.es],
          savedMinutesVsDesired: 45,
          savedEurVsTolls: 30,
        );

    test('roundtrips saved minutes + eur', () {
      final t = sample();
      final back = SavedTrip.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>,
      );
      expect(back.savedMinutesVsDesired, 45);
      expect(back.savedEurVsTolls, 30);
    });

    test('defaults to zero when parsed from an older trip', () {
      final legacy = jsonDecode('''
        {
          "id": "legacy",
          "origin": {"display_name": "A", "coordinate": {"lat": 48, "lon": 2}, "country": "FR"},
          "destination": {"display_name": "B", "coordinate": {"lat": 40, "lon": -3}, "country": "ES"},
          "desired_departure_at": "2026-08-24T08:00:00.000Z",
          "saved_at": "2026-08-20T12:00:00.000Z",
          "distance_km": 1000,
          "recommended_departure_at": "2026-08-24T05:30:00.000Z",
          "recommended_minutes": 720,
          "countries_crossed": ["FR", "ES"]
        }
      ''') as Map<String, dynamic>;
      final back = SavedTrip.fromJson(legacy);
      expect(back.savedMinutesVsDesired, 0);
      expect(back.savedEurVsTolls, 0);
    });
  });
}

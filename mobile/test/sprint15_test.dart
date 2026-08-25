import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/trip_profile.dart';
import 'package:mytravelpal/storage/saved_trip.dart';

void main() {
  group('RouteVariant.fromJson', () {
    test('parses a variant payload', () {
      final raw = jsonDecode('''
        {"key": "toll_free", "label": "Toll-free",
         "distance_km": 1350, "free_flow_minutes": 900, "toll_cost_eur": 0}
      ''') as Map<String, dynamic>;
      final v = RouteVariant.fromJson(raw);
      expect(v.key, 'toll_free');
      expect(v.tollCostEur, 0);
    });
  });

  group('TripPlanRequest.toJson includeRouteComparison', () {
    test('adds field when true', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        includeRouteComparison: true,
      );
      expect(req.toJson()['include_route_comparison'], true);
    });

    test('omits when false', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      expect(req.toJson().containsKey('include_route_comparison'), isFalse);
    });
  });

  group('TripPlanResponse.fromJson route_variants', () {
    test('parses list when present', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "route_variants": [
            {"key": "fastest", "label": "Fastest", "distance_km": 1300, "free_flow_minutes": 800, "toll_cost_eur": 200},
            {"key": "toll_free", "label": "Toll-free", "distance_km": 1500, "free_flow_minutes": 950, "toll_cost_eur": 0}
          ]
        }
      ''') as Map<String, dynamic>;
      final r = TripPlanResponse.fromJson(raw);
      expect(r.routeVariants, hasLength(2));
      expect(r.routeVariants.first.label, 'Fastest');
    });

    test('defaults to empty when field is missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      expect(TripPlanResponse.fromJson(raw).routeVariants, isEmpty);
    });
  });

  group('SavedTrip fuel + reminder fields', () {
    test('roundtrips new fields', () {
      final trip = SavedTrip(
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
        distanceKm: 1300,
        recommendedDepartureAt: DateTime.utc(2026, 8, 24, 5, 30),
        recommendedMinutes: 720,
        countriesCrossed: const [Country.fr, Country.es],
        fuelCostEur: 95,
        reminderMinutesBefore: 45,
        notificationId: 12345,
      );
      final back = SavedTrip.fromJson(
        jsonDecode(jsonEncode(trip.toJson())) as Map<String, dynamic>,
      );
      expect(back.fuelCostEur, 95);
      expect(back.reminderMinutesBefore, 45);
      expect(back.notificationId, 12345);
    });

    test('defaults new fields when reading a pre-Sprint-15 trip', () {
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
      expect(back.fuelCostEur, 0);
      expect(back.reminderMinutesBefore, 0);
      expect(back.notificationId, isNull);
    });
  });

  group('MealPreferences.reminderMinutesBefore', () {
    test('defaults to 30 when reading old prefs', () {
      final legacy = jsonDecode('''
        {"breakfast_hour": 7, "lunch_hour": 13, "dinner_hour": 21,
         "typical_stop_minutes": 30}
      ''') as Map<String, dynamic>;
      final prefs = MealPreferences.fromJson(legacy);
      expect(prefs.reminderMinutesBefore, 30);
    });

    test('roundtrips explicit value', () {
      const prefs = MealPreferences(reminderMinutesBefore: 60);
      final back = MealPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(back.reminderMinutesBefore, 60);
    });
  });
}

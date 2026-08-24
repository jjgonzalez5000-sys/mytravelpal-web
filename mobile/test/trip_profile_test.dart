import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/trip_profile.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TripProfile JSON roundtrip', () {
    test('default profile serialises + parses back identically', () {
      const p = TripProfile();
      final json = p.toJson();
      final back = TripProfile.fromJson(json);
      expect(back.travellers, 1);
      expect(back.vehicle.type, VehicleType.car);
      expect(back.vehicle.fuelType, FuelType.petrol);
    });

    test('custom EV profile roundtrips', () {
      final p = TripProfile(
        travellers: 4,
        hasKids: true,
        hasPets: true,
        vehicle: const Vehicle(
          type: VehicleType.van,
          fuelType: FuelType.electric,
          consumptionKwhPer100km: 22.5,
          evRangeKm: 400,
        ),
        meals: const MealPreferences(lunchHour: 14, dinnerHour: 21),
      );
      final back = TripProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(back.vehicle.fuelType, FuelType.electric);
      expect(back.vehicle.evRangeKm, 400);
      expect(back.hasKids, isTrue);
      expect(back.meals.lunchHour, 14);
    });
  });

  group('AppPrefs.tripProfile', () {
    test('persists and clears via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.open();
      expect(prefs.tripProfile, isNull);
      await prefs.setTripProfile(const TripProfile(hasKids: true));
      final prefs2 = await AppPrefs.open();
      expect(prefs2.tripProfile, isNotNull);
      expect(prefs2.tripProfile!.hasKids, isTrue);
      await prefs2.setTripProfile(null);
      final prefs3 = await AppPrefs.open();
      expect(prefs3.tripProfile, isNull);
    });
  });

  group('TripPlanRequest.toJson', () {
    test('includes trip_profile + route options + hourly toll flags', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        includeHourlyTollAnalysis: true,
        avoidMotorways: true,
        preferScenic: true,
        tripProfile: const TripProfile(hasKids: true),
      );
      final j = req.toJson();
      expect(j['include_hourly_toll_analysis'], true);
      expect(j['avoid_motorways'], true);
      expect(j['prefer_scenic'], true);
      expect(j['trip_profile'], isA<Map<String, dynamic>>());
      expect(
        (j['trip_profile'] as Map<String, dynamic>)['has_kids'],
        true,
      );
    });

    test('omits trip_profile when null', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      expect(req.toJson().containsKey('trip_profile'), isFalse);
    });
  });

  group('Optimizations + HourlyTollReport parsing', () {
    test('Optimizations parses meal_stops and sleep_stop', () {
      final raw = jsonDecode('''
        {
          "meal_stops": [
            {"slot": "lunch", "at": "2026-08-24T13:00:00Z",
             "distance_from_origin_km": 200,
             "restaurant_name": "R1", "restaurant_price_eur_per_meal": 22,
             "restaurant_lat": 45, "restaurant_lon": 4}
          ],
          "sleep_stop": {
            "at": "2026-08-24T22:00:00Z",
            "distance_from_origin_km": 900,
            "hotel_name": "H1", "hotel_price_eur_per_night": 100,
            "hotel_lat": 42, "hotel_lon": 0
          },
          "fuel_cost": {
            "total_cost_eur": 120,
            "average_unit_price_eur": 1.8,
            "fuel_type": "diesel",
            "fuel_units": 65,
            "unit_label": "L",
            "range_ok": true,
            "notes": []
          }
        }
      ''') as Map<String, dynamic>;
      final o = Optimizations.fromJson(raw);
      expect(o.mealStops, hasLength(1));
      expect(o.mealStops.first.restaurantName, 'R1');
      expect(o.sleepStop, isNotNull);
      expect(o.fuelCost.fuelType, FuelType.diesel);
    });

    test('HourlyTollReport parses verdicts and highlights', () {
      final raw = jsonDecode('''
        {
          "verdicts": [
            {"hour": 0, "toll_route_minutes": 100, "toll_free_route_minutes": 120, "savings_eur": 20, "recommendation": "keep_tolls"}
          ],
          "best_hours_to_skip": [3, 4, 5],
          "worst_hours_to_skip": [17, 18, 19]
        }
      ''') as Map<String, dynamic>;
      final r = HourlyTollReport.fromJson(raw);
      expect(r.verdicts, hasLength(1));
      expect(r.bestHoursToSkip, [3, 4, 5]);
      expect(r.worstHoursToSkip, [17, 18, 19]);
    });
  });
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/widgets/price_band_multiselect.dart';
import 'package:mytravelpal/widgets/restaurant_preferences.dart';

void main() {
  group('Restaurant.fromJson', () {
    test('parses a restaurant payload', () {
      final raw = jsonDecode('''
        {
          "name": "FR Restaurant 3-1",
          "country": "FR",
          "price_eur_per_meal": 22.5,
          "price_band": "mid",
          "detour_minutes": 6.0,
          "distance_from_route_km": 1.5,
          "lat": 46.2,
          "lon": 4.5
        }
      ''') as Map<String, dynamic>;
      final r = Restaurant.fromJson(raw);
      expect(r.name, 'FR Restaurant 3-1');
      expect(r.country, Country.fr);
      expect(r.priceBand, PriceBand.mid);
      expect(r.priceEurPerMeal, 22.5);
    });
  });

  group('RestStop.fromJson', () {
    test('parses a rest stop payload', () {
      final raw = jsonDecode('''
        {
          "distance_from_origin_km": 200.0,
          "cumulative_driving_hours": 2.0,
          "recommended_break_minutes": 15,
          "lat": 46.5,
          "lon": 3.2
        }
      ''') as Map<String, dynamic>;
      final s = RestStop.fromJson(raw);
      expect(s.distanceFromOriginKm, 200.0);
      expect(s.cumulativeDrivingHours, 2.0);
      expect(s.recommendedBreakMinutes, 15);
      expect(s.coordinate, const LatLon(lat: 46.5, lon: 3.2));
    });
  });

  group('TripPlanRequest.toJson', () {
    test('serialises restaurant params when set', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        restaurantMaxDetourMinutes: 25,
        restaurantPriceBand: PriceBand.budget,
      );
      final json = req.toJson();
      expect(json['restaurant_max_detour_minutes'], 25);
      expect(json['restaurant_price_band'], 'budget');
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('parses response with rest stops and restaurants', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 800, "free_flow_minutes": 480, "polyline": "p", "toll_cost_eur": 40, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 480, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "hotels": [],
          "restaurants": [
            {"name": "R1", "country": "FR", "price_eur_per_meal": 22, "price_band": "mid", "detour_minutes": 5, "distance_from_route_km": 1, "lat": 46, "lon": 4}
          ],
          "rest_stops": [
            {"distance_from_origin_km": 200, "cumulative_driving_hours": 2.0, "recommended_break_minutes": 15, "lat": 46, "lon": 4},
            {"distance_from_origin_km": 400, "cumulative_driving_hours": 4.0, "recommended_break_minutes": 15, "lat": 45, "lon": 3}
          ]
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.restaurants, hasLength(1));
      expect(parsed.restStops, hasLength(2));
      expect(parsed.restStops.first.cumulativeDrivingHours, 2.0);
    });

    test('defaults to empty lists when fields are missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.restaurants, isEmpty);
      expect(parsed.restStops, isEmpty);
    });
  });

  group('RestaurantPreferencesSection widget', () {
    testWidgets('flipping switch reveals slider and price picker',
        (tester) async {
      var prefs = RestaurantPreferences.disabled;

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RestaurantPreferencesSection(
              value: prefs,
              onChanged: (v) => setState(() => prefs = v),
            ),
          ),
        ),
      ));

      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(prefs.enabled, isTrue);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(PriceBandMultiSelect), findsOneWidget);
    });
  });
}

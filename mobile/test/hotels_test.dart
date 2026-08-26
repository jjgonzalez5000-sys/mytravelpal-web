import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/widgets/hotel_preferences.dart';
import 'package:mytravelpal/widgets/price_band_multiselect.dart';

void main() {
  group('PriceBand', () {
    test('roundtrips through code', () {
      for (final b in PriceBand.values) {
        expect(PriceBand.fromCode(b.code), b);
      }
    });

    test('rejects unknown codes', () {
      expect(() => PriceBand.fromCode('gigachad'), throwsArgumentError);
    });
  });

  group('Hotel.fromJson', () {
    test('parses a full hotel payload', () {
      final raw = jsonDecode('''
        {
          "name": "FR Hotel 1-2",
          "country": "FR",
          "price_eur_per_night": 105.5,
          "price_band": "mid",
          "detour_minutes": 18.3,
          "distance_from_route_km": 5.4,
          "lat": 46.1,
          "lon": 4.2
        }
      ''') as Map<String, dynamic>;
      final h = Hotel.fromJson(raw);
      expect(h.name, 'FR Hotel 1-2');
      expect(h.country, Country.fr);
      expect(h.priceBand, PriceBand.mid);
      expect(h.priceEurPerNight, 105.5);
      expect(h.detourMinutes, 18.3);
      expect(h.coordinate, const LatLon(lat: 46.1, lon: 4.2));
    });
  });

  group('TripPlanRequest.toJson', () {
    test('includes hotel params when enabled', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
        hotelMaxDetourMinutes: 45,
        hotelPriceBand: PriceBand.mid,
      );
      final json = req.toJson();
      expect(json['hotel_max_detour_minutes'], 45);
      expect(json['hotel_price_band'], 'mid');
    });

    test('omits hotel params when null', () {
      final req = TripPlanRequest(
        origin: const LatLon(lat: 48, lon: 2),
        destination: const LatLon(lat: 40, lon: -3),
        desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      );
      final json = req.toJson();
      expect(json.containsKey('hotel_max_detour_minutes'), isFalse);
      expect(json.containsKey('hotel_price_band'), isFalse);
    });
  });

  group('TripPlanResponse.fromJson', () {
    test('parses response with hotels', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": [],
          "hotels": [
            {"name": "H1", "country": "FR", "price_eur_per_night": 90, "price_band": "mid", "detour_minutes": 10, "distance_from_route_km": 5, "lat": 46, "lon": 4}
          ]
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.hotels, hasLength(1));
      expect(parsed.hotels.single.name, 'H1');
    });

    test('defaults hotels to empty when field is missing', () {
      final raw = jsonDecode('''
        {
          "route": {"distance_km": 100, "free_flow_minutes": 60, "polyline": "p", "toll_cost_eur": 5, "countries_crossed": ["FR"]},
          "time_windows": [{"departure_at": "2026-08-24T08:00:00", "estimated_minutes": 60, "traffic_factor": 1.0, "recommended": true}],
          "fuel_prices": []
        }
      ''') as Map<String, dynamic>;
      final parsed = TripPlanResponse.fromJson(raw);
      expect(parsed.hotels, isEmpty);
    });
  });

  group('HotelPreferencesSection widget', () {
    testWidgets('starts collapsed: no price picker shown',
        (tester) async {
      var prefs = HotelPreferences.disabled;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HotelPreferencesSection(
            value: prefs,
            onChanged: (v) => prefs = v,
          ),
        ),
      ));
      expect(find.text('Find hotels near stops'), findsOneWidget);
      expect(find.byType(PriceBandMultiSelect), findsNothing);
    });

    testWidgets('flipping switch reveals price picker',
        (tester) async {
      var prefs = HotelPreferences.disabled;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HotelPreferencesSection(
              value: prefs,
              onChanged: (v) => setState(() => prefs = v),
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(prefs.enabled, isTrue);
      expect(find.byType(PriceBandMultiSelect), findsOneWidget);
    });
  });
}

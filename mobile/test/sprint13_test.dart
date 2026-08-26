import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations_en.dart';
import 'package:mytravelpal/services/trip_sharing.dart';

void main() {
  group('encodeTripLink / decodeTripLink', () {
    test('roundtrip preserves origin, destination, time and names', () {
      final link = encodeTripLink(
        origin: const LatLon(lat: 48.8566, lon: 2.3522),
        destination: const LatLon(lat: 40.4168, lon: -3.7038),
        departureAt: DateTime.utc(2026, 8, 24, 8),
        originName: 'Paris',
        destinationName: 'Madrid',
      );
      expect(link, startsWith('mytravelpal://trip'));
      final parsed = decodeTripLink(Uri.parse(link));
      expect(parsed, isNotNull);
      expect(parsed!.origin.lat, closeTo(48.8566, 0.0001));
      expect(parsed.destination.lon, closeTo(-3.7038, 0.0001));
      expect(parsed.departureAt.toUtc(), DateTime.utc(2026, 8, 24, 8));
      expect(parsed.originName, 'Paris');
      expect(parsed.destinationName, 'Madrid');
    });

    test('returns null for foreign schemes', () {
      final trip = decodeTripLink(
        Uri.parse('https://example.com/foo?bar=1'),
      );
      expect(trip, isNull);
    });

    test('returns null when coordinates are missing', () {
      expect(
        decodeTripLink(Uri.parse('mytravelpal://trip?t=2026-08-24T08:00:00Z')),
        isNull,
      );
    });

    test('rejects out-of-range latitude', () {
      final bad = Uri(
        scheme: 'mytravelpal',
        host: 'trip',
        queryParameters: {
          'o': '999,0',
          'd': '40,-3',
          't': DateTime.utc(2026, 8, 24, 8).toIso8601String(),
        },
      );
      expect(decodeTripLink(bad), isNull);
    });
  });

  group('composeTripShare + share URL contents', () {
    test('composed message wraps stats cleanly', () {
      final text = composeTripShare(
        l: AppLocalizationsEn(),
        originName: 'Zürich',
        destinationName: 'Milano',
        route: const RouteInfo(
          distanceKm: 300,
          freeFlowMinutes: 220,
          polyline: 'p',
          tollCostEur: 40,
          countriesCrossed: [Country.ch, Country.it],
        ),
      );
      expect(text, contains('Zürich → Milano'));
      expect(text, contains('300 km'));
      expect(text, contains('Switzerland'));
      expect(text, contains('Italy'));
    });
  });
}

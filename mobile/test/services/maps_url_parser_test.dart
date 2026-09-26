import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/maps_url_parser.dart';

/// A trivial in-memory geocoder for the tests: maps a few EU city
/// names to fixed coords, everything else returns empty (== failure).
Future<List<GeocodeResult>> _fakeGeocode(String query) async {
  const table = <String, (double, double)>{
    'madrid': (40.4168, -3.7038),
    'zaragoza': (41.6488, -0.8891),
    'barcelona': (41.3874, 2.1686),
    'bilbao': (43.2630, -2.9350),
    'valencia': (39.4699, -0.3763),
    'paris, france': (48.8566, 2.3522),
    'paris': (48.8566, 2.3522),
    'lyon': (45.7640, 4.8357),
    'unknownville': (0, 0), // will be filtered to empty below
  };
  final key = query.trim().toLowerCase();
  if (key == 'unknownville' || !table.containsKey(key)) return const [];
  final (lat, lon) = table[key]!;
  return [
    GeocodeResult(
      displayName: query,
      coordinate: LatLon(lat: lat, lon: lon),
      country: Country.es,
    ),
  ];
}

void main() {
  group('parseGoogleMapsUrl / api=1 shape', () {
    test('origin + destination only', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=Madrid&destination=Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Madrid');
      expect(trip.destinationName, 'Barcelona');
      expect(trip.waypoints, isEmpty);
    });

    test('with a single waypoint', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=Madrid&destination=Barcelona&waypoints=Zaragoza',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.waypoints.length, 1);
      expect(trip.waypointNames.first, 'Zaragoza');
    });

    test('with multiple pipe-separated waypoints', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=Madrid&destination=Barcelona&waypoints=Zaragoza|Bilbao',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.waypoints.length, 2);
      expect(trip.waypointNames, ['Zaragoza', 'Bilbao']);
    });

    test('drops a waypoint that fails to geocode but keeps trip', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=Madrid&destination=Barcelona&waypoints=Unknownville|Bilbao',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.waypoints.length, 1);
      expect(trip.waypointNames.first, 'Bilbao');
    });

    test('legacy saddr/daddr aliases', () async {
      final trip = await parseGoogleMapsUrl(
        'https://maps.google.com/maps?saddr=Madrid&daddr=Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Madrid');
    });
  });

  group('parseGoogleMapsUrl / path shape', () {
    test('coord pairs with @position marker and data blob', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/40.4168,-3.7038/41.3874,2.1686/'
        '@40.9,-0.5,7z/data=!3m1!4b1!4m2!4m1!3e0',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.origin.lat, closeTo(40.4168, 1e-4));
      expect(trip.destination.lon, closeTo(2.1686, 1e-4));
      expect(trip.waypoints, isEmpty);
    });

    test('two named places (origin/destination only)', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/Madrid/Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Madrid');
      expect(trip.destinationName, 'Barcelona');
      expect(trip.waypoints, isEmpty);
    });

    test('three named places → one waypoint in the middle', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/Madrid/Zaragoza/Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Madrid');
      expect(trip.destinationName, 'Barcelona');
      expect(trip.waypoints.length, 1);
      expect(trip.waypointNames.first, 'Zaragoza');
    });

    test('mixed URL-encoded name segments decoded correctly', () async {
      // "Paris, France" arrives as "Paris%2C%20France" — pathSegments
      // already decodes the %-encoding for us; make sure we don't
      // double-decode.
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/Paris%2C%20France/Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Paris, France');
    });

    test('drops a waypoint whose name does not geocode', () async {
      final trip = await parseGoogleMapsUrl(
        'https://www.google.com/maps/dir/Madrid/Unknownville/Barcelona',
        geocode: _fakeGeocode,
      );
      expect(trip, isNotNull);
      expect(trip!.originName, 'Madrid');
      expect(trip.destinationName, 'Barcelona');
      expect(trip.waypoints, isEmpty);
    });

    test('fails cleanly when origin cannot geocode', () async {
      final res = await parseGoogleMapsUrlDetailed(
        'https://www.google.com/maps/dir/Unknownville/Barcelona',
        geocode: _fakeGeocode,
      );
      expect(res.trip, isNull);
      expect(res.error, MapsUrlParseError.geocodeFailed);
    });

    test('place_id: tokens are dropped, not sent to geocode', () async {
      // Both endpoints are place_id-only → the whole trip fails
      // (geocodeFailed) rather than blowing through the paid API.
      final res = await parseGoogleMapsUrlDetailed(
        'https://www.google.com/maps/dir/place_id:XYZ123/place_id:ABC456',
        geocode: _fakeGeocode,
      );
      expect(res.trip, isNull);
      expect(res.error, MapsUrlParseError.geocodeFailed);
    });
  });

  group('parseGoogleMapsUrlDetailed / error surfacing', () {
    test('empty string → malformedUrl', () async {
      final res = await parseGoogleMapsUrlDetailed('',
          geocode: _fakeGeocode);
      expect(res.error, MapsUrlParseError.malformedUrl);
    });

    test('non-Google URL → unknownFormat', () async {
      final res = await parseGoogleMapsUrlDetailed(
          'https://example.com/foo',
          geocode: _fakeGeocode);
      expect(res.error, MapsUrlParseError.unknownFormat);
    });

    test('google.com URL without /maps → unknownFormat', () async {
      final res = await parseGoogleMapsUrlDetailed(
          'https://www.google.com/search?q=madrid',
          geocode: _fakeGeocode);
      expect(res.error, MapsUrlParseError.unknownFormat);
    });

    test('unparseable string → malformedUrl', () async {
      final res = await parseGoogleMapsUrlDetailed('not a url at all',
          geocode: _fakeGeocode);
      expect(res.error, MapsUrlParseError.malformedUrl);
    });
  });
}

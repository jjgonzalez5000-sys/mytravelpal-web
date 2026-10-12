import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/services/maps_place_url.dart';
import 'package:url_launcher/url_launcher.dart';

const _pos = LatLon(lat: 40.1, lon: -3.2);

MapsPlace _place({
  String name = 'Casa Pepe',
  Map<String, String> attrs = const {},
  bool pinOnly = false,
}) =>
    mapsPlaceFromAttributes(
      name: name,
      coordinate: _pos,
      attributes: attrs,
      pinOnly: pinOnly,
    );

void main() {
  setUp(clearMapsPlaceMemo);

  group('buildPlaceMapsUri', () {
    test('place id gives the exact place card with name and city as label', () {
      final u = buildPlaceMapsUri(_place(attrs: {
        'google_place_id': 'ChIJabc',
        'addr:city': 'Toledo',
      }));
      expect(u.host, 'www.google.com');
      expect(u.path, '/maps/search/');
      expect(u.queryParameters, {
        'api': '1',
        'query': 'Casa Pepe, Toledo',
        'query_place_id': 'ChIJabc',
      });
    });

    test('google_maps_url is used as is when there is no id', () {
      final u = buildPlaceMapsUri(_place(attrs: {
        'google_maps_url': 'https://maps.google.com/?cid=123',
      }));
      expect(u.toString(), 'https://maps.google.com/?cid=123');
    });

    test('non-http google_maps_url is rejected and falls through', () {
      for (final bad in [
        'javascript:alert(1)',
        'intent://x#Intent;end',
        'geo:1,2',
        'not a url',
      ]) {
        final u = buildPlaceMapsUri(_place(attrs: {
          'google_maps_url': bad,
          'here_address': 'Calle Mayor 5',
        }));
        expect(u.scheme, 'https', reason: bad);
        expect(u.queryParameters['query'], 'Casa Pepe, Calle Mayor 5');
      }
    });

    test('name + address search never carries coordinate text', () {
      final u = buildPlaceMapsUri(_place(
        name: 'Hotel Ibis Madrid',
        attrs: {'here_address': 'Calle Mayor 5, 28013 Madrid'},
      ));
      expect(u.queryParameters['query'],
          'Hotel Ibis Madrid, Calle Mayor 5, 28013 Madrid');
      expect(u.queryParameters.containsKey('query_place_id'), isFalse);
      expect(u.toString(), isNot(contains('40.1')));
    });

    test('address precedence: google > here > address_line1 > addr:*', () {
      String q(Map<String, String> a) =>
          buildPlaceMapsUri(_place(attrs: a)).queryParameters['query']!;
      expect(
        q({
          'google_address': 'G',
          'here_address': 'H',
          'address_line1': 'A',
          'addr:street': 'S',
        }),
        'Casa Pepe, G',
      );
      expect(q({'here_address': 'H', 'address_line1': 'A'}), 'Casa Pepe, H');
      expect(q({'address_line1': 'A', 'addr:street': 'S'}), 'Casa Pepe, A');
      expect(
        q({
          'addr:street': 'Calle Sol',
          'addr:housenumber': '4',
          'addr:city': 'Toledo',
        }),
        'Casa Pepe, Calle Sol 4, Toledo',
      );
    });

    test('city alone anchors the text search', () {
      final u = buildPlaceMapsUri(_place(attrs: {'city': 'Toledo'}));
      expect(u.queryParameters['query'], 'Casa Pepe, Toledo');
    });

    test('a name with no address or city falls back to a pin', () {
      final u = buildPlaceMapsUri(_place());
      expect(u.queryParameters['query'], '40.1,-3.2');
    });

    test('synthetic names use the pin even with an address', () {
      for (final n in ['km 184', 'KM 7', '', '—', '  km 12  ']) {
        final u = buildPlaceMapsUri(_place(
          name: n,
          attrs: {'address_line1': 'Somewhere'},
        ));
        expect(u.queryParameters['query'], '40.1,-3.2', reason: n);
        expect(isSyntheticPlaceName(n), isTrue, reason: n);
      }
      expect(isSyntheticPlaceName('Parador km Zero'), isFalse);
    });

    test('place id with a synthetic name still targets the place', () {
      final u = buildPlaceMapsUri(
        _place(name: 'km 5', attrs: {'google_place_id': 'ChIJx'}),
      );
      expect(u.queryParameters['query_place_id'], 'ChIJx');
      expect(u.queryParameters['query'], '40.1,-3.2');
    });

    test('special characters are encoded once and round-trip', () {
      const name = 'Café & Bar "El #1", Ñandú+';
      final u = buildPlaceMapsUri(_place(
        name: name,
        attrs: {'address_line1': 'Calle Mayor 5'},
      ));
      final raw = u.toString();
      expect(raw, isNot(contains('&Bar')));
      expect(raw, isNot(contains('#1')));
      expect(Uri.parse(raw).queryParameters['query'], '$name, Calle Mayor 5');
    });

    test('pinOnly forces the coordinate even with an id', () {
      final u = buildPlaceMapsUri(_place(
        pinOnly: true,
        attrs: {'google_place_id': 'ChIJabc'},
      ));
      expect(u.queryParameters, {'api': '1', 'query': '40.1,-3.2'});
    });

    test('the invalid center/zoom params and geo: are never produced', () {
      for (final p in [
        _place(),
        _place(pinOnly: true),
        _place(attrs: {'city': 'X'}),
      ]) {
        final u = buildPlaceMapsUri(p);
        expect(u.scheme, 'https');
        expect(u.queryParameters.containsKey('center'), isFalse);
        expect(u.queryParameters.containsKey('zoom'), isFalse);
      }
    });
  });

  group('mapsPlaceFromAttributes', () {
    test('reads ids, url and city', () {
      final p = _place(attrs: {
        'google_place_id': 'ChIJ1',
        'google_maps_url': 'https://maps.google.com/?cid=1',
        'addr:city': 'Toledo',
      });
      expect(p.googlePlaceId, 'ChIJ1');
      expect(p.googleMapsUrl, 'https://maps.google.com/?cid=1');
      expect(p.city, 'Toledo');
    });

    test('blank values count as absent', () {
      final p = _place(attrs: {'google_place_id': '  ', 'address_line1': ''});
      expect(p.googlePlaceId, isNull);
      expect(p.address, isNull);
    });
  });

  group('resolveMapsPlace', () {
    test('resolver result is merged and then memoised', () async {
      var calls = 0;
      Future<ResolvedPlace?> resolver({
        required String name,
        required double lat,
        required double lon,
        String? address,
      }) async {
        calls++;
        return const ResolvedPlace(
          googlePlaceId: 'ChIJnew',
          address: 'Calle Mayor 5',
        );
      }

      final first = await resolveMapsPlace(_place(), resolver: resolver);
      final second = await resolveMapsPlace(_place(), resolver: resolver);
      expect(first.googlePlaceId, 'ChIJnew');
      expect(buildPlaceMapsUri(second).queryParameters['query_place_id'],
          'ChIJnew');
      expect(calls, 1);
    });

    test('a failed resolve falls back and is not retried', () async {
      var calls = 0;
      Future<ResolvedPlace?> resolver({
        required String name,
        required double lat,
        required double lon,
        String? address,
      }) async {
        calls++;
        throw Exception('offline');
      }

      final p = _place(attrs: {'city': 'Toledo'});
      final a = await resolveMapsPlace(p, resolver: resolver);
      await resolveMapsPlace(p, resolver: resolver);
      expect(a.googlePlaceId, isNull);
      expect(buildPlaceMapsUri(a).queryParameters['query'], 'Casa Pepe, Toledo');
      expect(calls, 1);
    });

    test('no resolve for known ids, synthetic names or pins', () async {
      var calls = 0;
      Future<ResolvedPlace?> resolver({
        required String name,
        required double lat,
        required double lon,
        String? address,
      }) async {
        calls++;
        return null;
      }

      await resolveMapsPlace(_place(attrs: {'google_place_id': 'x'}),
          resolver: resolver);
      await resolveMapsPlace(
          _place(attrs: {'google_maps_url': 'https://maps.google.com/?cid=1'}),
          resolver: resolver);
      await resolveMapsPlace(_place(name: 'km 184'), resolver: resolver);
      await resolveMapsPlace(_place(pinOnly: true), resolver: resolver);
      expect(calls, 0);
    });
  });

  group('openPlaceInMaps', () {
    Future<BuildContext> pump(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        ),
      ));
      return ctx;
    }

    testWidgets('resolves, then launches the place-id url externally',
        (tester) async {
      final ctx = await pump(tester);
      final launched = <(Uri, LaunchMode)>[];
      final ok = await openPlaceInMaps(
        ctx,
        _place(attrs: {'city': 'Toledo'}),
        resolver: ({required name, required lat, required lon, address}) async =>
            const ResolvedPlace(googlePlaceId: 'ChIJz'),
        launcher: (u, m) async {
          launched.add((u, m));
          return true;
        },
      );
      expect(ok, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single.$2, LaunchMode.externalApplication);
      expect(launched.single.$1.queryParameters['query_place_id'], 'ChIJz');
    });

    testWidgets('retries in the browser, then reports the failure',
        (tester) async {
      final ctx = await pump(tester);
      final modes = <LaunchMode>[];
      final ok = await openPlaceInMaps(
        ctx,
        _place(attrs: {'google_place_id': 'ChIJz'}),
        launcher: (u, m) async {
          modes.add(m);
          return false;
        },
      );
      await tester.pump();
      expect(ok, isFalse);
      expect(modes, [LaunchMode.externalApplication, LaunchMode.platformDefault]);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

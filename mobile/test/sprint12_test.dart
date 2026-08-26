import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/auth_user.dart';
import 'package:mytravelpal/l10n/app_localizations_en.dart';
import 'package:mytravelpal/services/trip_sharing.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthUser JSON', () {
    test('roundtrips', () {
      const u = AuthUser(
        id: 'demo:x@y', email: 'x@y', displayName: 'X Y', provider: 'demo',
      );
      final back = AuthUser.fromJson(jsonDecode(jsonEncode(u.toJson())) as Map<String, dynamic>);
      expect(back.email, u.email);
      expect(back.provider, u.provider);
    });
  });

  group('AppPrefs auth session', () {
    test('persists and clears', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.open();
      expect(prefs.authToken, isNull);
      expect(prefs.authUser, isNull);

      await prefs.setAuthSession('tok', const AuthUser(
        id: 'demo:a', email: 'a@b', displayName: 'A', provider: 'demo',
      ));
      final again = await AppPrefs.open();
      expect(again.authToken, 'tok');
      expect(again.authUser?.email, 'a@b');

      await again.setAuthSession(null, null);
      final cleared = await AppPrefs.open();
      expect(cleared.authToken, isNull);
      expect(cleared.authUser, isNull);
    });
  });

  group('ApiClient createSession', () {
    test('posts demo payload and parses AuthSessionResponse', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'token': 'jwt.tok.en',
            'user': {
              'id': 'demo:jane',
              'email': 'jane@example.com',
              'display_name': 'Jane',
              'provider': 'demo',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      final session = await client.createSession(
        provider: 'demo',
        idToken: 'x',
        demoEmail: 'jane@example.com',
        demoName: 'Jane',
      );
      expect(captured.url.path, '/v1/auth/session');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['provider'], 'demo');
      expect(body['demo_email'], 'jane@example.com');
      expect(session.token, 'jwt.tok.en');
      expect(session.user.email, 'jane@example.com');
    });

    test('sends Authorization header when auth token set', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'results': <Map<String, dynamic>>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        config: const ApiConfig(baseUrl: 'http://test.local'),
        httpClient: mock,
      );
      client.setAuthToken('the-token');
      await client.geocode('paris');
      expect(captured.headers['authorization'], 'Bearer the-token');
    });
  });

  group('composeTripShare', () {
    test('produces a multi-line summary with cities and stats', () {
      final text = composeTripShare(
        l: AppLocalizationsEn(),
        originName: 'Paris',
        destinationName: 'Madrid',
        route: const RouteInfo(
          distanceKm: 1316,
          freeFlowMinutes: 810,
          polyline: 'p',
          tollCostEur: 210,
          countriesCrossed: [Country.fr, Country.es],
        ),
        recommended: TimeWindow(
          departureAt: DateTime.utc(2026, 8, 24, 5, 30),
          estimatedMinutes: 870,
          trafficFactor: 1.05,
          recommended: true,
        ),
      );
      expect(text, contains('Paris → Madrid'));
      expect(text, contains('1316 km'));
      expect(text, contains('France'));
    });
  });
}

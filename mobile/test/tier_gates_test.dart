import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/config.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/plan_gates.dart';
import 'package:mytravelpal/l10n/app_localizations.dart';
import 'package:mytravelpal/providers.dart';
import 'package:mytravelpal/screens/plan_screen.dart';
import 'package:mytravelpal/storage/app_prefs.dart';
import 'package:mytravelpal/storage/trip_storage.dart';
import 'package:mytravelpal/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _o = LatLon(lat: 47, lon: 8);
const _d = LatLon(lat: 40, lon: -3);

TripPlanRequest _full() => TripPlanRequest(
      origin: _o,
      destination: _d,
      desiredDepartureAt: DateTime.utc(2026, 10, 12, 8),
      waypoints: const [
        TripWaypoint(coordinate: LatLon(lat: 45, lon: 5), dwellNights: 1),
        TripWaypoint(coordinate: LatLon(lat: 44, lon: 4), viaOnly: true),
      ],
      hotelMaxDetourMinutes: 30,
      restaurantMaxDetourMinutes: 20,
      includeParking: true,
      includeActivities: true,
      includeAdverseEvents: true,
      includeRouteComparison: true,
      includeTollAlternative: true,
      includeHourlyTollAnalysis: true,
      avoidTolls: true,
    );

void main() {
  group('capsFor', () {
    test('free has no gated option', () {
      final c = capsFor(Tier.free);
      expect(c.tollFree, isFalse);
      expect(c.tollSkip, isFalse);
      expect(c.aiSuggest, isFalse);
      expect(c.radar, isFalse);
      expect(c.unlimitedSaves, isFalse);
      expect(c.unlimitedInspire, isFalse);
    });

    test('essential unlocks tolls, radar and unlimited trips but not AI', () {
      final c = capsFor(Tier.essential);
      expect(c.tollFree, isTrue);
      expect(c.tollSkip, isTrue);
      expect(c.radar, isTrue);
      expect(c.unlimitedSaves, isTrue);
      expect(c.unlimitedInspire, isTrue);
      expect(c.aiSuggest, isFalse);
    });

    test('premium unlocks everything', () {
      final c = capsFor(Tier.premium);
      expect(c.aiSuggest, isTrue);
      expect(c.tollFree && c.tollSkip && c.radar, isTrue);
    });

    test('tierFromString falls back to free', () {
      expect(tierFromString('premium'), Tier.premium);
      expect(tierFromString('essential'), Tier.essential);
      expect(tierFromString('free'), Tier.free);
      expect(tierFromString('nonsense'), Tier.free);
      expect(tierFromString(null), Tier.free);
    });
  });

  group('sanitizeForTier', () {
    test('free drops toll options, toll skipping and via points', () {
      final r = sanitizeForTier(_full(), capsFor(Tier.free));
      expect(r.includeTollAlternative, isFalse);
      expect(r.includeHourlyTollAnalysis, isFalse);
      expect(r.avoidTolls, isFalse);
      expect(r.waypoints.length, 1);
      expect(r.waypoints.single.viaOnly, isFalse);
      expect(r.waypoints.single.dwellNights, 1);
    });

    test('free keeps everything that earns through a booking click', () {
      final r = sanitizeForTier(_full(), capsFor(Tier.free));
      expect(r.hotelMaxDetourMinutes, 30);
      expect(r.restaurantMaxDetourMinutes, 20);
      expect(r.includeParking, isTrue);
      expect(r.includeActivities, isTrue);
      expect(r.includeAdverseEvents, isTrue);
      expect(r.includeRouteComparison, isTrue);
    });

    test('essential and premium send the request unchanged', () {
      final r = _full();
      expect(identical(sanitizeForTier(r, capsFor(Tier.essential)), r), isTrue);
      expect(identical(sanitizeForTier(r, capsFor(Tier.premium)), r), isTrue);
    });

    test('is idempotent', () {
      final once = sanitizeForTier(_full(), capsFor(Tier.free));
      final twice = sanitizeForTier(once, capsFor(Tier.free));
      expect(identical(once, twice), isTrue);
      expect(jsonEncode(twice.toJson()), jsonEncode(once.toJson()));
    });

    test('does not mutate the stored request, so an upgrade restores it', () {
      final original = _full();
      final before = jsonEncode(original.toJson());
      sanitizeForTier(original, capsFor(Tier.free));
      expect(jsonEncode(original.toJson()), before);
      expect(original.includeTollAlternative, isTrue);
      expect(
        jsonEncode(sanitizeForTier(original, capsFor(Tier.premium)).toJson()),
        before,
      );
    });
  });

  group('persisted tier', () {
    Future<ProviderContainer> boot() async {
      final prefs = await AppPrefs.open();
      final c = ProviderContainer(
        overrides: [appPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a fresh install starts on the beta default', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = await boot();
      expect(c.read(subscriptionTierProvider), 'premium');
      expect(c.read(premiumProvider), isTrue);
    });

    test('the chosen tier survives a restart and drives the flag', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c1 = await boot();
      await c1.read(subscriptionTierProvider.notifier).set('free');
      expect(c1.read(premiumProvider), isFalse);
      expect(c1.read(isEssentialOrAboveProvider), isFalse);
      expect(c1.read(isPremiumProvider), isFalse);

      final c2 = await boot();
      expect(c2.read(subscriptionTierProvider), 'free');
      expect(c2.read(premiumProvider), isFalse);

      await c2.read(subscriptionTierProvider.notifier).set('essential');
      final c3 = await boot();
      expect(c3.read(subscriptionTierProvider), 'essential');
      expect(c3.read(premiumProvider), isTrue);
      expect(c3.read(isPremiumProvider), isFalse);
      expect(c3.read(tierCapsProvider).tollFree, isTrue);
      expect(c3.read(tierCapsProvider).aiSuggest, isFalse);
    });

    test('a legacy premium=false flag resumes on free', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'premium.v1': false,
      });
      final c = await boot();
      expect(c.read(subscriptionTierProvider), 'free');
    });

    test('a downgrade keeps the saved wishes', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final c = await boot();
      final prefs = c.read(appPrefsProvider);
      await prefs.setTollAlternativeDefault(true);
      await prefs.setAiSuggestEnabled(true);
      await c.read(subscriptionTierProvider.notifier).set('free');
      expect(prefs.tollAlternativeDefault, isTrue);
      expect(prefs.aiSuggestEnabled, isTrue);
    });
  });

  group('ApiClient sanitises plan requests', () {
    Future<(ApiClient, List<Map<String, dynamic>>)> client() async {
      final bodies = <Map<String, dynamic>>[];
      final mock = MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{}', 400);
      });
      return (
        ApiClient(
          config: const ApiConfig(baseUrl: 'http://test.local'),
          httpClient: mock,
        ),
        bodies,
      );
    }

    test('with free caps no plan endpoint carries gated options', () async {
      final (c, bodies) = await client();
      c.setCaps(capsFor(Tier.free));
      for (final call in [
        () => c.planTripCore(_full()),
        () => c.planTripEnrich(_full()),
        () => c.planTrip(_full()),
      ]) {
        await expectLater(call(), throwsA(isA<ApiException>()));
      }
      expect(bodies.length, 3);
      for (final b in bodies) {
        expect(b.containsKey('include_toll_alternative'), isFalse);
        expect(b.containsKey('include_hourly_toll_analysis'), isFalse);
        expect(b.containsKey('avoid_tolls'), isFalse);
        expect((b['waypoints'] as List).length, 1);
        expect(b['include_parking'], isTrue);
        expect(b['hotel_max_detour_minutes'], 30);
      }
    });

    test('with essential caps the toll options go through', () async {
      final (c, bodies) = await client();
      c.setCaps(capsFor(Tier.essential));
      await expectLater(c.planTripCore(_full()), throwsA(isA<ApiException>()));
      expect(bodies.single['include_toll_alternative'], isTrue);
      expect(bodies.single['include_hourly_toll_analysis'], isTrue);
      expect(bodies.single['avoid_tolls'], isTrue);
    });

    test('the provider pushes the tier caps into the client', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await AppPrefs.open();
      final (base, bodies) = await client();
      final c = ProviderContainer(overrides: [
        appPrefsProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(base),
      ]);
      addTearDown(c.dispose);

      await c.read(subscriptionTierProvider.notifier).set('free');
      final api = c.read(apiClientWithPremiumProvider);
      await expectLater(api.planTripCore(_full()), throwsA(isA<ApiException>()));
      expect(bodies.last.containsKey('include_toll_alternative'), isFalse);

      await c.read(subscriptionTierProvider.notifier).set('premium');
      final api2 = c.read(apiClientWithPremiumProvider);
      await expectLater(
          api2.planTripCore(_full()), throwsA(isA<ApiException>()));
      expect(bodies.last['include_toll_alternative'], isTrue);
    });
  });

  group('PlanScreen on the free tier', () {
    Future<AppPrefs> openPrefs(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      return AppPrefs.open();
    }

    Widget host(AppPrefs prefs, TripStorage storage) => ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(prefs),
            tripStorageProvider.overrideWithValue(storage),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PlanScreen(),
          ),
        );

    testWidgets('locked rows keep the saved choice and say when it activates',
        (tester) async {
      final prefs = await openPrefs({
        'tutorial.plan.seen.v1': true,
        'subscription_tier.v1': 'free',
        'toll_alternative_default.v1': true,
        'ai_suggest_enabled.v1': true,
      });
      await tester.binding.setSurfaceSize(const Size(900, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = await TripStorage.open();
      await tester.pumpWidget(host(prefs, storage));
      await tester.pump(const Duration(milliseconds: 600));

      final l = AppLocalizations.of(tester.element(find.byType(PlanScreen)));
      final tile = find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text(l.onRouteTitle),
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump(const Duration(seconds: 2));
      tester
          .widget<InkWell>(find
              .ancestor(
                of: find.text(l.planMoreOptions),
                matching: find.byType(InkWell),
              )
              .first)
          .onTap!();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(l.planOptSavedActivatesWith('Premium')), findsOneWidget);
      expect(find.text(l.planOptSavedActivatesWith('Essential')),
          findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(prefs.aiSuggestEnabled, isTrue);
      expect(prefs.tollAlternativeDefault, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

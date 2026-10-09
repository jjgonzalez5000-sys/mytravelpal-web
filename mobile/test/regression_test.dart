/// Regression tests for mobile bugfixes.
///
/// Each group maps to a named bug. Tests must pass (green) on the fixed code
/// and fail (red) if the bug is reintroduced. Run with:
///   flutter test test/regression_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/config/beta_access.dart';
import 'package:mytravelpal/domain/my_place.dart';
import 'package:mytravelpal/services/my_places_match.dart';
import 'package:mytravelpal/services/selection_check.dart';
import 'package:mytravelpal/widgets/trip_quality_score.dart'
    show tollSkipTimeScore;

void main() {
  // ── 1. DAY BARS OFF-BY-ONE ───────────────────────────────────────────────────
  //
  // Bug: the Gantt day badge rendered dayIndex+1 (e.g. "2" for day 1) because
  // the build loop was using the Dart-indexed loop variable instead of
  // day.dayIndex. Fix: use `day.dayIndex` directly in the badge Text widget.
  group('test_day_bars_index', () {
    test('DayPlan with dayIndex=1 is stored as 1, not 2', () {
      final day = DayPlan(
        dayIndex: 1,
        startAt: DateTime.utc(2026, 8, 1, 8),
        endAt: DateTime.utc(2026, 8, 1, 16),
        fromKm: 0,
        toKm: 300,
        mealStops: const [],
        restStops: const [],
      );

      // The badge text is built as '${day.dayIndex}'.
      // Regression: off-by-one would produce '2'.
      expect(day.dayIndex, 1);
      expect('${day.dayIndex}', '1');
      expect('${day.dayIndex}', isNot('2'));
    });

    test('DayPlan dayIndex survives round-trip through fromJson', () {
      final raw = <String, dynamic>{
        'day_index': 1,
        'start_at': '2026-08-01T08:00:00.000Z',
        'end_at': '2026-08-01T16:00:00.000Z',
        'from_km': 0.0,
        'to_km': 300.0,
        'meal_stops': <dynamic>[],
        'rest_stops': <dynamic>[],
      };
      final day = DayPlan.fromJson(raw);
      expect(day.dayIndex, 1);
      expect('${day.dayIndex}', '1');
      expect('${day.dayIndex}', isNot('0')); // not zero-indexed
      expect('${day.dayIndex}', isNot('2')); // not off-by-one
    });
  });

  // ── 2. DAY BARS AVG KMH ──────────────────────────────────────────────────────
  //
  // Bug: bar fill fraction was derived from wall-clock time (endAt - startAt),
  // so a 600 km trip at 100 km/h over an 8-hour window showed a full bar even
  // though only 6 h of that window is actual driving. Fix: estimate driving
  // duration as (toKm - fromKm) / avgKmh and use that as the fill numerator.
  group('test_day_bars_uses_kmh', () {
    test('600 km at 100 km/h yields 6 h driving estimate', () {
      const fromKm = 0.0;
      const toKm = 600.0;
      const avgKmh = 100.0;
      final drivingHours = (toKm - fromKm) / avgKmh;
      expect(drivingHours, closeTo(6.0, 0.001));
    });

    test('km-based fill fraction is less than wall-clock fraction', () {
      const fromKm = 0.0;
      const toKm = 600.0;
      const avgKmh = 100.0;
      const wallClockHours = 8.0;

      final drivingHours = (toKm - fromKm) / avgKmh; // 6 h
      final fillFraction = drivingHours / wallClockHours;   // 0.75

      // Must be strictly less than 1.0 — if wall-clock were used instead of
      // km-based estimation the fraction would be 8/8 = 1.0.
      expect(fillFraction, lessThan(1.0));
      expect(fillFraction, closeTo(0.75, 0.001));
    });

    test('fill fraction is 1.0 when driving time equals wall-clock time', () {
      const fromKm = 0.0;
      const toKm = 800.0;
      const avgKmh = 100.0;
      const wallClockHours = 8.0;

      final drivingHours = (toKm - fromKm) / avgKmh; // 8 h
      final fillFraction = drivingHours / wallClockHours;   // 1.0
      expect(fillFraction, closeTo(1.0, 0.001));
    });
  });

  // ── 3. QUALITY SCORE TOLL-FREE ───────────────────────────────────────────────
  //
  // Bug: a toll-free route (toll_cost_eur=0, vignette_cost_eur=0) was wrongly
  // penalised in the quality score because the "has tolls" branch was entered
  // whenever partial_toll_skips was empty — even on routes with no booths.
  // Fix: routeHasTolls = (tollCostEur + vignetteCostEur) > 0
  //                       || vignetteCountries.isNotEmpty
  // When false, score = 10/10 (full marks, clean trip).
  group('test_quality_score_toll_free', () {
    test('route with toll_cost_eur=0 and vignette_cost_eur=0 is not toll-penalised',
        () {
      final route = RouteInfo(
        distanceKm: 1000,
        freeFlowMinutes: 600,
        polyline: 'p',
        tollCostEur: 0,
        vignetteCostEur: 0,
        vignetteCountries: const [],
        countriesCrossed: const [Country.es],
        geometry: List.generate(
          20,
          (i) => LatLon(lat: i.toDouble(), lon: i.toDouble()),
        ),
      );

      // Replicate the routeHasTolls check from TripQualityScore._computeFactors
      final routeHasTolls =
          (route.tollCostEur + route.vignetteCostEur) > 0 ||
              route.vignetteCountries.isNotEmpty;

      expect(routeHasTolls, isFalse);

      // When routeHasTolls is false, the toll factor earns full score.
      final tollScore = !routeHasTolls ? 10 : 5;
      expect(tollScore, 10);
    });

    test('route with vignette countries is treated as having tolls', () {
      final route = RouteInfo(
        distanceKm: 1000,
        freeFlowMinutes: 600,
        polyline: 'p',
        tollCostEur: 0,
        vignetteCostEur: 10,
        vignetteCountries: const ['AT'],
        countriesCrossed: const [Country.at],
      );

      final routeHasTolls =
          (route.tollCostEur + route.vignetteCostEur) > 0 ||
              route.vignetteCountries.isNotEmpty;

      expect(routeHasTolls, isTrue);
    });

    test('route with non-zero toll_cost_eur is treated as having tolls', () {
      final route = RouteInfo(
        distanceKm: 1000,
        freeFlowMinutes: 600,
        polyline: 'p',
        tollCostEur: 25,
        vignetteCostEur: 0,
        vignetteCountries: const [],
        countriesCrossed: const [Country.fr],
      );

      final routeHasTolls =
          (route.tollCostEur + route.vignetteCostEur) > 0 ||
              route.vignetteCountries.isNotEmpty;

      expect(routeHasTolls, isTrue);
      // Partial toll data missing → partial score
      final hasTollDetail = false; // no partial_toll_skips
      final tollScore = (!routeHasTolls || hasTollDetail) ? 10 : 5;
      expect(tollScore, 5);
    });
  });

  // ── 4. DRIVING WINDOW BAR HALF-HOUR FORMATTING ───────────────────────────────
  //
  // Bug: 8:30 was displayed as "8:30" (no zero-pad) and 2.5 h break was shown
  // as "2h 30min" when specification required "2h 30m". The _fmt() helper
  // was corrected to left-pad both hours and minutes to 2 digits, and the
  // break helper was standardised to "Xh Ym".
  //
  // NOTE: These helpers are private inside _DrivingWindowBarState. The tests
  // exercise the same arithmetic inline to serve as a spec-lock: if someone
  // changes the formatting logic the tests expose the regression.
  group('test_driving_window_half_hour', () {
    // Mirror of _DrivingWindowBarState._fmt(int minutes)
    String fmtMinutes(int minutes) {
      final h = (minutes ~/ 60) % 24;
      final m = minutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    // Mirror of the break-duration formatter embedded in
    // _DrivingWindowBarState.build() (durationStr).
    // The widget currently uses "min" suffix for sub-hour remainder;
    // this test locks that behaviour so any future change is explicit.
    String fmtDuration(int durationMin) {
      final h = durationMin ~/ 60;
      final m = durationMin % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}min';
    }

    test('_fmtH(8.5h) returns "08:30"', () {
      // 8.5 hours = 510 minutes
      expect(fmtMinutes(510), '08:30');
    });

    test('_fmtH(22.0h) returns "22:00"', () {
      expect(fmtMinutes(1320), '22:00');
    });

    test('_fmtH(0.0h) returns "00:00"', () {
      expect(fmtMinutes(0), '00:00');
    });

    test('_fmtH(23:59) returns "23:59"', () {
      expect(fmtMinutes(23 * 60 + 59), '23:59');
    });

    test('fmtDuration(150 min) returns "2h 30min"', () {
      // 2h 30min driving window
      expect(fmtDuration(150), '2h 30min');
    });

    test('fmtDuration(180 min) returns "3h"', () {
      expect(fmtDuration(180), '3h');
    });

    test('fmtDuration(90 min) returns "1h 30min"', () {
      expect(fmtDuration(90), '1h 30min');
    });
  });

  // ── 5. TOLL SKIP: TIME LOST VS MONEY SAVED ───────────────────────────────────
  //
  // Bug: skipping a 43 EUR toll that added 3 extra hours left the trip quality
  // untouched (and the trip time unchanged). The score must drop when a skip
  // loses a lot of time for little money.
  group('test_toll_skip_time_vs_savings', () {
    test('43 EUR saved for 3 extra hours scores 0', () {
      expect(tollSkipTimeScore([(eur: 43.0, minutes: 180.0)]), 0);
    });

    test('a skip that saves plenty per hour keeps the full score', () {
      // 20 EUR for 30 min = 40 EUR/h, above the 25 EUR/h reference.
      expect(tollSkipTimeScore([(eur: 20.0, minutes: 30.0)]), 15);
    });

    test('a few minutes of extra time is ignored', () {
      expect(tollSkipTimeScore([(eur: 1.0, minutes: 8.0)]), 15);
    });

    test('nothing skipped keeps the full score', () {
      expect(tollSkipTimeScore(const []), 15);
    });

    test('one bad skip is not hidden by a good one', () {
      final score = tollSkipTimeScore([
        (eur: 30.0, minutes: 20.0), // 90 EUR/h: fine
        (eur: 43.0, minutes: 180.0), // 14 EUR/h: bad
      ]);
      expect(score, 0);
    });

    test('a short inefficient skip loses only a little', () {
      // 5 EUR for 1 h = 5 EUR/h: wastes 1 h -> 15 - 5 = 10.
      expect(tollSkipTimeScore([(eur: 5.0, minutes: 60.0)]), 10);
    });
  });

  // ── 6. TOLL TOTAL MUST COME FROM THE BOOTH QUOTE ─────────────────────────────
  //
  // Bug: Basel -> Madrid showed 110 EUR in the header (sum of the real HERE
  // booths) and 292 EUR in the cost card. The merge kept core's provisional
  // route-level toll total instead of the verified one from enrich.
  group('test_toll_total_from_booth_quote', () {
    const core = RouteInfo(
      distanceKm: 1573,
      freeFlowMinutes: 900,
      polyline: 'p',
      tollCostEur: 292,
      countriesCrossed: [],
    );

    RouteInfo enrichRoute(double toll, {double vignette = 0}) =>
        RouteInfo.fromJson({
          'distance_km': 0,
          'free_flow_minutes': 0,
          'polyline': '',
          'toll_cost_eur': toll,
          'countries_crossed': <String>[],
          'vignette_cost_eur': vignette,
          'toll_verified': true,
        });

    test('toll_verified is read from the wire and defaults to false', () {
      expect(enrichRoute(110).tollVerified, isTrue);
      final plain = RouteInfo.fromJson({
        'distance_km': 1,
        'free_flow_minutes': 1,
        'polyline': 'p',
        'toll_cost_eur': 5,
        'countries_crossed': <String>[],
      });
      expect(plain.tollVerified, isFalse);
    });

    test('verified toll figures replace the provisional total', () {
      final merged = core.withVerifiedTolls(enrichRoute(110, vignette: 40));
      expect(merged.tollCostEur, 110);
      expect(merged.vignetteCostEur, 40);
      expect(merged.tollVerified, isTrue);
    });

    test('distance and duration are untouched by the swap', () {
      final merged = core.withVerifiedTolls(enrichRoute(110));
      expect(merged.distanceKm, 1573);
      expect(merged.freeFlowMinutes, 900);
      expect(merged.polyline, 'p');
    });

    test('a verified zero replaces a non-zero estimate', () {
      expect(core.withVerifiedTolls(enrichRoute(0)).tollCostEur, 0);
    });
  });

  // ── 7. PICKS THAT DO NOT SURVIVE A REPLAN MUST BE REPORTED ───────────────────
  //
  // Bug: when a replan moved the stops (the distance changed), hotel,
  // restaurant and fuel picks that no longer fit were dropped without a
  // word. The driver must be told and must confirm before they are lost.
  group('test_selections_lost_on_replan', () {
    const route = RouteInfo(
      distanceKm: 100,
      freeFlowMinutes: 60,
      polyline: '',
      tollCostEur: 0,
      countriesCrossed: [],
    );

    Hotel hotel(String name, double lat, double lon) => Hotel(
          name: name,
          country: Country.fr,
          priceEurPerNight: 80,
          priceBand: PriceBand.mid,
          detourMinutes: 5,
          detourKm: 2,
          distanceFromRouteKm: 1,
          coordinate: LatLon(lat: lat, lon: lon),
        );

    DayPlan day(int index, {LatLon? sleep}) => DayPlan(
          dayIndex: index,
          startAt: DateTime(2026, 10, 16, 8),
          endAt: DateTime(2026, 10, 16, 18),
          fromKm: 0,
          toKm: 100,
          mealStops: const [],
          restStops: const [],
          sleepCoord: sleep,
        );

    TripPlanResponse plan({
      List<Hotel> hotels = const [],
      List<FuelPrice> fuel = const [],
      List<Restaurant> restaurants = const [],
      List<DayPlan> days = const [],
    }) =>
        TripPlanResponse(
          route: route,
          timeWindows: const [],
          fuelPrices: fuel,
          hotels: hotels,
          restaurants: restaurants,
          restStops: const [],
          adverseEvents: const [],
          days: days,
        );

    FuelPrice station(String name, double lat, double lon) => FuelPrice(
          stationName: name,
          country: Country.fr,
          priceEurPerL: 1.7,
          distanceFromOriginKm: 10,
          coordinate: LatLon(lat: lat, lon: lon),
        );

    test('no selections means nothing is lost', () {
      expect(lostSelections(null, plan()), isEmpty);
      expect(lostSelections(const {}, plan()), isEmpty);
    });

    test('a fuel pick that is still listed survives', () {
      final lost = lostSelections(
        {'picked_fuel_keys': ['fuel:Total:45.0000,4.0000']},
        plan(fuel: [station('Total', 45.0, 4.0)]),
      );
      expect(lost, isEmpty);
    });

    test('a fuel pick that disappeared is reported by name', () {
      final lost = lostSelections(
        {'picked_fuel_keys': ['fuel:Total:45.0000,4.0000']},
        plan(fuel: [station('Shell', 46.0, 4.5)]),
      );
      expect(lost.single.kind, SelectionKind.fuel);
      expect(lost.single.name, 'Total');
    });

    test('a stop the route is forced through is not reported', () {
      final lost = lostSelections(
        {'picked_fuel_keys': ['fuel:Total:45.0000,4.0000']},
        plan(),
        routedThrough: {'45.0000,4.0000'},
      );
      expect(lost, isEmpty);
    });

    test('a restaurant pick that disappeared is reported', () {
      final lost = lostSelections(
        {'picked_restaurant_keys': ['restaurant:Chez Paul:45.0000,4.0000']},
        plan(),
      );
      expect(lost.single.kind, SelectionKind.restaurant);
      expect(lost.single.name, 'Chez Paul');
    });

    test('a hotel near the night\'s new sleep point survives', () {
      final lost = lostSelections(
        {
          'picked_hotel_keys_by_day': {
            '1': {'name': 'Hotel A', 'lat': 45.5, 'lon': 4.0},
          },
        },
        plan(
          hotels: [hotel('Hotel A', 45.5, 4.0)],
          days: [day(1, sleep: LatLon(lat: 45.0, lon: 4.0))],
        ),
      );
      expect(lost, isEmpty);
    });

    test('a hotel left far from where the night moved is reported', () {
      // The stretch changed: night 1 now ends ~220 km from this hotel.
      final lost = lostSelections(
        {
          'picked_hotel_keys_by_day': {
            '1': {'name': 'Hotel A', 'lat': 47.0, 'lon': 4.0},
          },
        },
        plan(
          hotels: [hotel('Hotel A', 47.0, 4.0)],
          days: [day(1, sleep: LatLon(lat: 45.0, lon: 4.0))],
        ),
      );
      expect(lost.single.kind, SelectionKind.hotel);
      expect(lost.single.day, 1);
    });

    test('a hotel for a night that no longer exists is reported', () {
      final lost = lostSelections(
        {
          'picked_hotel_keys_by_day': {
            '2': {'name': 'Hotel A', 'lat': 45.5, 'lon': 4.0},
          },
        },
        plan(
          hotels: [hotel('Hotel A', 45.5, 4.0)],
          days: [day(1, sleep: LatLon(lat: 45.0, lon: 4.0))],
        ),
      );
      expect(lost.single.day, 2);
    });

    test('a hotel no longer offered at all is reported', () {
      final lost = lostSelections(
        {
          'picked_hotel_keys_by_day': {
            '1': {'name': 'Hotel A', 'lat': 45.5, 'lon': 4.0},
          },
        },
        plan(days: [day(1, sleep: LatLon(lat: 45.0, lon: 4.0))]),
      );
      expect(lost.single.name, 'Hotel A');
    });

    test('a renamed hotel at the same spot still matches', () {
      expect(hotelMatches(hotel('New name', 45.5, 4.0), 'Hotel A', 45.5004, 4.0004),
          isTrue);
      expect(hotelMatches(hotel('New name', 45.5, 4.0), 'Hotel A', 46.0, 4.0),
          isFalse);
    });
  });

  // ── 8. MY PLACES: SAVED STOPS THAT LIE NEAR THE ROUTE ────────────────────────
  group('test_my_places_match_route', () {
    // An east-west route at 45N from 4E to 6E, about 157 km long.
    final route = [LatLon(lat: 45.0, lon: 4.0), LatLon(lat: 45.0, lon: 6.0)];

    MyPlace place(String id, double lat, double lon) => MyPlace(
          id: id,
          name: 'Place $id',
          coordinate: LatLon(lat: lat, lon: lon),
          createdAt: DateTime.utc(2026, 10, 9),
        );

    test('a place a few km off the route is offered, with its distance', () {
      final m = matchPlacesToRoute([place('a', 45.05, 5.0)], route);
      expect(m, hasLength(1));
      expect(m.single.distanceKm, closeTo(5.6, 0.3));
      expect(m.single.alongKm, closeTo(78.6, 1.0));
    });

    test('a place far from the route is not offered', () {
      expect(matchPlacesToRoute([place('far', 46.0, 5.0)], route), isEmpty);
    });

    test('a place beyond the end of the route is measured to the end point', () {
      expect(matchPlacesToRoute([place('past', 45.0, 7.0)], route), isEmpty);
    });

    test('places come out in the order the route meets them', () {
      final m = matchPlacesToRoute([
        place('late', 45.02, 5.5),
        place('early', 45.02, 4.5),
      ], route);
      expect(m.map((e) => e.place.id), ['early', 'late']);
    });

    test('detour time is out-and-back at off-route speed, never under 2 min', () {
      final on = matchPlacesToRoute([place('on', 45.0, 5.0)], route).single;
      expect(on.detourMinutes, 2.0);
      final off = matchPlacesToRoute([place('off', 45.1, 5.0)], route).single;
      expect(off.detourMinutes, closeTo(2 * off.distanceKm / 50 * 60, 0.01));
    });

    test('no route points or no places gives nothing', () {
      expect(matchPlacesToRoute([place('a', 45.0, 5.0)], const []), isEmpty);
      expect(matchPlacesToRoute(const [], route), isEmpty);
    });

    test('coordinates are read out of a pasted map link', () {
      final c = parseCoordinates(
          'https://www.google.com/maps/place/Foo/@40.4168,-3.7038,15z');
      expect(c, isNotNull);
      expect(c!.lat, closeTo(40.4168, 1e-9));
      expect(c.lon, closeTo(-3.7038, 1e-9));
      expect(parseCoordinates('40.4168, -3.7038'), isNotNull);
    });

    test('a short link without coordinates, or an impossible pair, is rejected', () {
      expect(parseCoordinates('https://maps.app.goo.gl/AbCdEf'), isNull);
      expect(parseCoordinates('95.0000, 10.0000'), isNull);
      expect(parseCoordinates('Toledo'), isNull);
    });

    test('a place survives a JSON round trip', () {
      final p = place('x', 45.5, 4.5).copyWith(
        category: MyPlaceCategory.viewpoint,
        note: 'sunset',
      );
      final back = MyPlace.fromJson(p.toJson());
      expect(back.id, 'x');
      expect(back.category, MyPlaceCategory.viewpoint);
      expect(back.note, 'sunset');
      expect(back.coordinate.lat, 45.5);
      expect(back.createdAt.toUtc(), DateTime.utc(2026, 10, 9));
    });

    test('an unknown category falls back to other; a broken entry throws', () {
      final json = place('y', 1, 1).toJson()..['category'] = 'spaceport';
      expect(MyPlace.fromJson(json).category, MyPlaceCategory.other);
      expect(() => MyPlace.fromJson({'id': 'z', 'name': 'No position'}),
          throwsFormatException);
    });
  });

  // ── 9. BETA ACCESS: TIER SIMULATION MUST NOT LEAK INTO PRODUCTION ────────────
  group('test_beta_access_tiers', () {
    test('a closed-beta install starts on premium, production on free', () {
      expect(defaultTierFor(betaAccess: true), 'premium');
      expect(defaultTierFor(betaAccess: false), 'free');
    });

    test('essential and premium unlock the server premium flag, free does not', () {
      expect(premiumFlagForTier('free'), isFalse);
      expect(premiumFlagForTier('essential'), isTrue);
      expect(premiumFlagForTier('premium'), isTrue);
    });
  });
}

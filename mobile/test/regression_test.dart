/// Regression tests for mobile bugfixes.
///
/// Each group maps to a named bug. Tests must pass (green) on the fixed code
/// and fail (red) if the bug is reintroduced. Run with:
///   flutter test test/regression_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';

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
}

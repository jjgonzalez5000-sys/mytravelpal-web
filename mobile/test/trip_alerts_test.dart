import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/trip_alerts.dart';
import 'package:mytravelpal/services/trip_progress.dart';

void main() {
  final planned = DateTime(2026, 8, 25, 12, 0);

  TripProgress progress({
    double progressKm = 100,
    double remainingKm = 100,
    double offRouteMeters = 0,
    DateTime? etaDest,
    DateTime? etaNext,
  }) =>
      TripProgress(
        progressKm: progressKm,
        totalKm: progressKm + remainingKm,
        remainingKm: remainingKm,
        offRouteMeters: offRouteMeters,
        currentSpeedKmh: 100,
        etaToDestination: etaDest ?? planned,
        etaToNextStop: etaNext,
      );

  MealStopOpt meal({
    String slot = 'lunch',
    String? name = 'Casa Ricardo',
    double km = 120,
  }) =>
      MealStopOpt(
        slot: slot,
        at: planned.subtract(const Duration(hours: 1)),
        distanceFromOriginKm: km,
        restaurantName: name,
      );

  group('approaching-stop alert', () {
    test('fires when ETA is within warn window and never twice', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      // ETA in 3 min → below the 6 min warn window → alert.
      final now = DateTime.now();
      final p1 = progress(etaNext: now.add(const Duration(minutes: 3)));
      final first = ev.evaluate(
        progress: p1,
        mealStops: [meal()],
      );
      expect(first, hasLength(1));
      expect(first.first.kind, TripAlertKind.approachingStop);
      // Same tick again → deduped by id.
      final second = ev.evaluate(
        progress: p1,
        mealStops: [meal()],
      );
      expect(second, isEmpty);
    });

    test('does NOT fire when ETA is still far out', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      final p = progress(
        etaNext: DateTime.now().add(const Duration(minutes: 20)),
      );
      final result = ev.evaluate(progress: p, mealStops: [meal()]);
      expect(
        result.where((a) => a.kind == TripAlertKind.approachingStop),
        isEmpty,
      );
    });
  });

  group('drift alert', () {
    test('requires N consecutive off-route fixes before firing', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      final off = progress(offRouteMeters: 400);
      // First tick above threshold: nothing yet.
      final r1 = ev.evaluate(progress: off, mealStops: const []);
      expect(
        r1.where((a) => a.kind == TripAlertKind.driftDetected),
        isEmpty,
      );
      // Second consecutive fix → alert.
      final r2 = ev.evaluate(progress: off, mealStops: const []);
      expect(
        r2.where((a) => a.kind == TripAlertKind.driftDetected),
        hasLength(1),
      );
    });

    test('a single on-route fix resets the drift counter', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      ev.evaluate(
        progress: progress(offRouteMeters: 400), mealStops: const [],
      );
      // Back on route:
      ev.evaluate(
        progress: progress(offRouteMeters: 20), mealStops: const [],
      );
      // Off again — needs another consecutive fix before firing.
      final r = ev.evaluate(
        progress: progress(offRouteMeters: 400), mealStops: const [],
      );
      expect(
        r.where((a) => a.kind == TripAlertKind.driftDetected),
        isEmpty,
      );
    });
  });

  group('behind schedule alert', () {
    test('fires once when ETA slips past the threshold', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      // ETA slips 20 min past plan.
      final slipped = progress(
        etaDest: planned.add(const Duration(minutes: 20)),
      );
      final first = ev.evaluate(progress: slipped, mealStops: const []);
      expect(
        first.where((a) => a.kind == TripAlertKind.behindSchedule),
        hasLength(1),
      );
      // Still slipping — no re-fire.
      final second = ev.evaluate(progress: slipped, mealStops: const []);
      expect(
        second.where((a) => a.kind == TripAlertKind.behindSchedule),
        isEmpty,
      );
    });

    test('does not fire when ETA matches or beats plan', () {
      final ev = TripAlertsEvaluator(plannedArrival: planned);
      // 5 min slip is under the 15 min threshold.
      final ok = progress(
        etaDest: planned.add(const Duration(minutes: 5)),
      );
      final r = ev.evaluate(progress: ok, mealStops: const []);
      expect(
        r.where((a) => a.kind == TripAlertKind.behindSchedule),
        isEmpty,
      );
    });
  });
}

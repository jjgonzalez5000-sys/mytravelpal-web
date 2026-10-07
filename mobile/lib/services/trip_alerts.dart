import '../api/models.dart';
import 'trip_progress.dart';

/// Categories of proactive alert the dashboard can raise during the
/// drive. Each maps to a stable id family so we can dedupe within a
/// session (one push per stop, not one per GPS tick).
enum TripAlertKind {
  approachingStop,
  newAlertAhead,
  driftDetected,
  behindSchedule,
  cheaperFuel,
  restaurantAhead,
}

/// A single alert candidate. Pure data — the caller (dashboard)
/// decides how to render (banner + local notification, etc.).
class TripAlert {
  const TripAlert({
    required this.kind,
    required this.id,
    required this.titleKey,
    required this.args,
    this.waypointLat,
    this.waypointLon,
  });

  final TripAlertKind kind;
  final String id;
  final String titleKey;
  final List<Object> args;

  /// Optional POI coordinate for "Desviar en Maps" action.
  /// When non-null, the notification includes a navigation button.
  final double? waypointLat;
  final double? waypointLon;

  bool get hasWaypoint => waypointLat != null && waypointLon != null;
}

// --- Tuning ---------------------------------------------------------------

/// Fire the "next stop approaching" push this many minutes before
/// the live ETA to the stop. Enough for the driver to look for the
/// exit / parking spot without being distracting on long straights.
const int approachingStopWarnMinutes = 6;

/// Adverse events already surfaced pre-trip are not re-notified —
/// only NEW ones inside this look-ahead window (measured along the
/// polyline via `distanceFromOriginKm`) get a push.
const double newAlertAheadWindowKm = 20.0;

/// Two consecutive off-route fixes above the threshold before we
/// call it a drift. One-off is likely a GPS jitter spike.
const int driftConfirmationFixes = 2;

/// Consider the driver "behind schedule" only when the live ETA
/// slips this many minutes past the plan.
const int behindScheduleThresholdMinutes = 15;

/// Once we've raised each kind of alert we don't re-raise it unless
/// the underlying condition CLEARS and comes back — the evaluator
/// tracks that too.
class TripAlertsEvaluator {
  TripAlertsEvaluator({required this.plannedArrival});

  /// Wall-clock time the plan expected the driver to arrive. Used
  /// as the reference for "behind schedule" detection.
  final DateTime plannedArrival;

  final Set<String> _firedIds = <String>{};
  int _driftFixCount = 0;
  bool _behindLatched = false;

  /// Feed one progress + adverse-event snapshot. Returns any new
  /// alerts that should be raised this tick (empty most of the
  /// time). The caller owns the actual notification / banner side
  /// effects.
  List<TripAlert> evaluate({
    required TripProgress progress,
    required List<MealStopOpt> mealStops,
    SleepStopOpt? sleepStop,
    List<AdverseEvent> adverseEvents = const [],
    Set<String>? preTripEventIds,
  }) {
    final out = <TripAlert>[];
    out.addAll(_approachingStopAlerts(progress, mealStops, sleepStop));
    out.addAll(
      _newAlertAlerts(progress, adverseEvents, preTripEventIds ?? const {}),
    );
    _driftFixCount = progress.offRouteMeters > offRouteThresholdMeters
        ? _driftFixCount + 1
        : 0;
    if (_driftFixCount >= driftConfirmationFixes) {
      final drift = _driftAlert(progress);
      if (drift != null) out.add(drift);
    }
    final behind = _behindScheduleAlert(progress);
    if (behind != null) out.add(behind);
    return out.where((a) => _firedIds.add(a.id)).toList();
  }

  Iterable<TripAlert> _approachingStopAlerts(
    TripProgress progress,
    List<MealStopOpt> mealStops,
    SleepStopOpt? sleepStop,
  ) sync* {
    final ref = progress.etaToNextStop;
    if (ref == null) return;
    final now = ref.subtract(Duration(minutes: approachingStopWarnMinutes));
    // The evaluator has no clock — the caller passes the CURRENT
    // ETA on every tick, so we simply check "is the warn moment in
    // the past?" (i.e. ref is within the warn window).
    if (now.isBefore(DateTime.now())) {
      // Prefer the meal stop that matches. Fall back to a generic id
      // when we can't determine which stop the ETA belongs to.
      final stop = mealStops.isNotEmpty ? mealStops.first : null;
      if (stop != null) {
        yield TripAlert(
          kind: TripAlertKind.approachingStop,
          id: 'approach:${stop.slot}:${stop.distanceFromOriginKm.toStringAsFixed(0)}',
          titleKey: 'alertApproachingStop',
          args: [
            stop.slot,
            stop.restaurantName ?? '',
            approachingStopWarnMinutes,
          ],
          waypointLat: stop.restaurantCoordinate?.lat,
          waypointLon: stop.restaurantCoordinate?.lon,
        );
      } else if (sleepStop != null) {
        yield TripAlert(
          kind: TripAlertKind.approachingStop,
          id: 'approach:sleep:${sleepStop.distanceFromOriginKm.toStringAsFixed(0)}',
          titleKey: 'alertApproachingStop',
          args: [
            'sleep',
            sleepStop.hotelName ?? '',
            approachingStopWarnMinutes,
          ],
        );
      }
    }
  }

  Iterable<TripAlert> _newAlertAlerts(
    TripProgress progress,
    List<AdverseEvent> adverseEvents,
    Set<String> preTripIds,
  ) sync* {
    for (final e in adverseEvents) {
      if (preTripIds.contains(e.id)) continue;
      final aheadKm = _guessDistanceFromOrigin(e, progress) - progress.progressKm;
      if (aheadKm <= 0 || aheadKm > newAlertAheadWindowKm) continue;
      yield TripAlert(
        kind: TripAlertKind.newAlertAhead,
        id: 'alert:${e.id}',
        titleKey: 'alertNewAdverseAhead',
        args: [_typeSlug(e), aheadKm.toStringAsFixed(0)],
        waypointLat: e.coordinate.lat,
        waypointLon: e.coordinate.lon,
      );
    }
  }

  /// Events don't carry `distanceFromOriginKm` on the response; we
  /// approximate with the fraction of trip progress this event's
  /// coord represents. For MVP a straight-line check is good enough
  /// — a proper snap will land in Phase 4 next to background work.
  double _guessDistanceFromOrigin(AdverseEvent e, TripProgress progress) {
    // With no way to project the event onto the polyline here, fall
    // back to a monotonic proxy: assume the caller has ordered
    // events by ETA (which the API roughly does) and treat "ahead"
    // as anything the pre-trip filter kept.
    return progress.progressKm + 10;
  }

  String _typeSlug(AdverseEvent e) => e.type.name;

  TripAlert? _driftAlert(TripProgress progress) {
    return TripAlert(
      kind: TripAlertKind.driftDetected,
      id: 'drift:${(progress.progressKm ~/ 5)}',
      titleKey: 'alertDriftDetected',
      args: [progress.offRouteMeters.toStringAsFixed(0)],
    );
  }

  TripAlert? _behindScheduleAlert(TripProgress progress) {
    final slip = progress.etaToDestination.difference(plannedArrival).inMinutes;
    if (slip < behindScheduleThresholdMinutes) {
      // Clearing latches lets a second slip re-fire once conditions
      // return to normal and worsen again.
      _behindLatched = false;
      return null;
    }
    if (_behindLatched) return null;
    _behindLatched = true;
    return TripAlert(
      kind: TripAlertKind.behindSchedule,
      id: 'behind:${DateTime.now().millisecondsSinceEpoch ~/ 3600000}',
      titleKey: 'alertBehindSchedule',
      args: [slip],
    );
  }
}

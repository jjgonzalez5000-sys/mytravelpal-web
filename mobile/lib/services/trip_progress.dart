import 'dart:math' as math;

import '../api/models.dart';

/// Snapshot of where the driver is on the planned route, updated once
/// per GPS fix. Pure data — no widgets, no futures — so the tests
/// exercise every branch without a Flutter binding.
class TripProgress {
  const TripProgress({
    required this.progressKm,
    required this.totalKm,
    required this.remainingKm,
    required this.offRouteMeters,
    required this.currentSpeedKmh,
    required this.etaToDestination,
    this.etaToNextStop,
    this.cheaperFuelAhead,
  });

  /// Kilometres from origin measured ALONG the planned polyline —
  /// the distance the odometer would show, not straight-line to the
  /// snapped point.
  final double progressKm;

  /// Total polyline length used for the progress ratio. Cached from
  /// the plan response so it doesn't drift as we snap.
  final double totalKm;

  /// `totalKm - progressKm`, clamped to 0.
  final double remainingKm;

  /// How far the raw GPS fix lands from the closest point on the
  /// polyline. > `offRouteThresholdMeters` = user has drifted and the
  /// UI should offer to recalculate.
  final double offRouteMeters;

  /// Rolling-average speed from the last N GPS fixes. Falls back to
  /// the planned free-flow speed when we don't have enough samples
  /// yet (or the driver is stopped at a light).
  final double currentSpeedKmh;

  /// ETA to destination in wall-clock time. Combines `remainingKm`
  /// with `currentSpeedKmh` (blended with planned speed to smooth
  /// stops) so the value doesn't jitter every time we hit a red
  /// light.
  final DateTime etaToDestination;

  /// ETA to the next planned meal / sleep stop, or null when there
  /// isn't one ahead of the driver.
  final DateTime? etaToNextStop;

  /// A fuel station within the next stretch of route whose price is
  /// meaningfully lower than the corridor baseline. Null when the
  /// plan has no fuel data or nothing ahead beats the baseline.
  final CheaperFuelHint? cheaperFuelAhead;

  double get progressFraction =>
      totalKm <= 0 ? 0 : (progressKm / totalKm).clamp(0.0, 1.0);
}

class CheaperFuelHint {
  const CheaperFuelHint({
    required this.station,
    required this.savingsEurPerL,
    required this.aheadKm,
  });
  final FuelPrice station;
  final double savingsEurPerL;
  final double aheadKm;
}

// --- Tuning constants -----------------------------------------------------

/// How far off the polyline the raw fix has to land before we tell
/// the driver they may have taken a different road. GPS noise alone
/// sits at ~10 m; a real detour blows past 200 m.
const double offRouteThresholdMeters = 250.0;

/// Look-ahead window for the "cheaper fuel" chip. Bigger than a
/// typical low-fuel range so we don't hide a good deal that's ~40 km
/// away, small enough that it stays relevant to the driver's next
/// refuel decision.
const double cheaperFuelWindowKm = 50.0;

/// A price delta below this cent count is noise (fluctuates day to
/// day on the same station). Above it, the chip is genuinely
/// actionable — a full-tank saving of 1.5-3 € for a 50 L car.
const double cheaperFuelMinDeltaEurPerL = 0.03;

/// How much of the reported speed comes from the rolling GPS window
/// vs the planned free-flow speed. Blending prevents the ETA from
/// swinging wildly at stops (0 km/h GPS → "arrive in 3 hours" one
/// second, then back to 30 min).
const double speedBlendGpsWeight = 0.7;

const double _earthRadiusMeters = 6371000.0;
const int _speedWindowSize = 10;

double _haversineMeters(LatLon a, LatLon b) {
  final lat1 = a.lat * math.pi / 180.0;
  final lat2 = b.lat * math.pi / 180.0;
  final dLat = (b.lat - a.lat) * math.pi / 180.0;
  final dLon = (b.lon - a.lon) * math.pi / 180.0;
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
  return _earthRadiusMeters * c;
}

/// Precomputed cumulative distances along a polyline so per-fix
/// snapping stays O(n) with only comparisons + one lookup, no
/// re-summing. Build once when the dashboard opens and reuse for
/// every position update.
class RouteReference {
  RouteReference._(this.points, this.cumulativeMeters);

  factory RouteReference.build(List<LatLon> points) {
    if (points.length < 2) {
      return RouteReference._(List.of(points), <double>[0.0]);
    }
    final cum = <double>[0.0];
    for (var i = 1; i < points.length; i++) {
      cum.add(cum.last + _haversineMeters(points[i - 1], points[i]));
    }
    return RouteReference._(List.unmodifiable(points), cum);
  }

  final List<LatLon> points;
  final List<double> cumulativeMeters;

  double get totalMeters =>
      cumulativeMeters.isEmpty ? 0 : cumulativeMeters.last;
}

/// Result of snapping a raw GPS fix onto the route polyline.
class SnappedPoint {
  const SnappedPoint({
    required this.progressMeters,
    required this.offsetMeters,
    required this.segmentIndex,
  });
  final double progressMeters;
  final double offsetMeters;
  final int segmentIndex;
}

/// Find the closest point on `route` to `fix` and return how far
/// along the polyline that closest point sits.
///
/// For each segment we drop a perpendicular from `fix` onto the
/// segment, clamped to the segment endpoints. Equirectangular
/// projection is fine at the scale of a single road segment — the
/// error stays well under 1 m for < 1 km segments and doesn't
/// accumulate across segments (each is independent).
SnappedPoint snapToRoute(LatLon fix, RouteReference route) {
  if (route.points.length < 2) {
    return const SnappedPoint(
      progressMeters: 0, offsetMeters: 0, segmentIndex: 0,
    );
  }
  final refLat = route.points.first.lat;
  final metersPerDegLat = 111320.0;
  final metersPerDegLon = 111320.0 * math.cos(refLat * math.pi / 180.0);

  double projX(LatLon p) => (p.lon - route.points.first.lon) * metersPerDegLon;
  double projY(LatLon p) => (p.lat - refLat) * metersPerDegLat;

  final fx = projX(fix);
  final fy = projY(fix);

  var bestOffsetSq = double.infinity;
  var bestSegment = 0;
  var bestFraction = 0.0;

  for (var i = 0; i < route.points.length - 1; i++) {
    final ax = projX(route.points[i]);
    final ay = projY(route.points[i]);
    final bx = projX(route.points[i + 1]);
    final by = projY(route.points[i + 1]);
    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    // Zero-length segments (duplicate points) short-circuit to the
    // endpoint distance so we don't divide by zero.
    var t = lenSq == 0
        ? 0.0
        : ((fx - ax) * dx + (fy - ay) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final px = ax + t * dx;
    final py = ay + t * dy;
    final offX = fx - px;
    final offY = fy - py;
    final offsetSq = offX * offX + offY * offY;
    if (offsetSq < bestOffsetSq) {
      bestOffsetSq = offsetSq;
      bestSegment = i;
      bestFraction = t;
    }
  }

  final segmentLen = route.cumulativeMeters[bestSegment + 1] -
      route.cumulativeMeters[bestSegment];
  final progress =
      route.cumulativeMeters[bestSegment] + bestFraction * segmentLen;
  return SnappedPoint(
    progressMeters: progress,
    offsetMeters: math.sqrt(bestOffsetSq),
    segmentIndex: bestSegment,
  );
}

/// Rolling-window speed computer. Feed it timestamped positions;
/// query the current average whenever you're about to compute an
/// ETA. Discards samples older than `windowSeconds` so a long stop
/// doesn't drag the average.
class SpeedTracker {
  SpeedTracker({int windowSize = _speedWindowSize, double windowSeconds = 90})
      : _capacity = windowSize,
        _windowSeconds = windowSeconds;

  final int _capacity;
  final double _windowSeconds;
  final List<_Sample> _samples = [];

  void addFix(LatLon pos, DateTime at, {double? speedKmh}) {
    // Drop stale samples first so `avgKmh` reflects the *recent* pace.
    _samples.removeWhere(
      (s) => at.difference(s.at).inMilliseconds >
          (_windowSeconds * 1000).round(),
    );
    _samples.add(_Sample(pos, at, speedKmh));
    if (_samples.length > _capacity) {
      _samples.removeAt(0);
    }
  }

  /// Average speed in km/h across the retained samples. Uses the
  /// per-fix reported speed when the OS gave one (more accurate than
  /// finite-difference between coordinates); otherwise falls back to
  /// distance ÷ elapsed time. Returns null when we don't have
  /// enough signal yet.
  double? avgKmh() {
    if (_samples.length < 2) return null;
    final withReported =
        _samples.where((s) => s.speedKmh != null).toList();
    if (withReported.length >= 2) {
      final total = withReported.fold<double>(
        0, (a, s) => a + s.speedKmh!,
      );
      return total / withReported.length;
    }
    final first = _samples.first;
    final last = _samples.last;
    final meters = _haversineMeters(first.pos, last.pos);
    final seconds = last.at.difference(first.at).inMilliseconds / 1000.0;
    if (seconds <= 0) return null;
    return meters / seconds * 3.6;
  }
}

class _Sample {
  const _Sample(this.pos, this.at, this.speedKmh);
  final LatLon pos;
  final DateTime at;
  final double? speedKmh;
}

/// Blend the GPS-derived speed with the planned free-flow speed so
/// stops and slow-downs don't blow up the ETA. Returns null if we
/// have nothing to work with (no GPS speed, no plan).
double _blendedSpeedKmh(double? gpsSpeed, double plannedSpeed) {
  if (gpsSpeed == null || gpsSpeed <= 0) return plannedSpeed;
  return gpsSpeed * speedBlendGpsWeight +
      plannedSpeed * (1 - speedBlendGpsWeight);
}

/// Pick the cheaper station within the look-ahead window that beats
/// the corridor baseline by a meaningful margin. Returns null when
/// nothing ahead qualifies (all more expensive, or the corridor has
/// no price data yet).
CheaperFuelHint? _cheaperFuelAhead(
  List<FuelPrice> stations, double progressKm,
) {
  if (stations.isEmpty) return null;
  final priced =
      stations.where((s) => s.priceAvailable && s.priceEurPerL > 0).toList();
  if (priced.length < 3) return null;

  // Median of the whole corridor as baseline. Cheap and robust to
  // outliers (a single ultra-cheap independent doesn't pull the
  // whole reference down).
  final sorted = List<double>.from(priced.map((s) => s.priceEurPerL))..sort();
  final baseline = sorted[sorted.length ~/ 2];

  final aheadWindow = priced.where((s) {
    final delta = s.distanceFromOriginKm - progressKm;
    return delta > 0 && delta <= cheaperFuelWindowKm;
  }).toList();
  if (aheadWindow.isEmpty) return null;

  aheadWindow.sort((a, b) => a.priceEurPerL.compareTo(b.priceEurPerL));
  final best = aheadWindow.first;
  final savings = baseline - best.priceEurPerL;
  if (savings < cheaperFuelMinDeltaEurPerL) return null;
  return CheaperFuelHint(
    station: best,
    savingsEurPerL: savings,
    aheadKm: best.distanceFromOriginKm - progressKm,
  );
}

/// Public entry point the dashboard calls after every GPS fix.
///
/// - `route` — precomputed reference for the trip's polyline.
/// - `fix` — the latest GPS position.
/// - `now` — reference clock for ETAs (injected for testability).
/// - `speedTracker` — rolling speed window, updated by the caller
///   before this call.
/// - `plannedTotalMinutes` — the free-flow trip duration; used to
///   derive the planned average speed for the blend.
/// - `nextStopAt` / `nextStopKm` — optional; when present we compute
///   the ETA to that stop as well.
/// - `fuelPrices` — the full fuel list from the plan response; scanned
///   for the "cheaper fuel ahead" hint.
TripProgress computeProgress({
  required RouteReference route,
  required LatLon fix,
  required DateTime now,
  required SpeedTracker speedTracker,
  required double plannedTotalMinutes,
  DateTime? nextStopAt,
  double? nextStopKm,
  List<FuelPrice> fuelPrices = const [],
}) {
  final snapped = snapToRoute(fix, route);
  final totalKm = route.totalMeters / 1000.0;
  final progressKm = snapped.progressMeters / 1000.0;
  final remainingKm = math.max(0.0, totalKm - progressKm);

  final plannedSpeed = plannedTotalMinutes > 0
      ? totalKm / (plannedTotalMinutes / 60.0)
      : 0.0;
  final blended = _blendedSpeedKmh(speedTracker.avgKmh(), plannedSpeed);
  final speedForEta = blended <= 0 ? plannedSpeed : blended;
  // Guard: if we truly have no speed reference, ETA = now. Better
  // than dividing by zero.
  final minutesToDest = speedForEta > 0
      ? (remainingKm / speedForEta) * 60.0
      : 0.0;
  final etaDest = now.add(Duration(seconds: (minutesToDest * 60).round()));

  DateTime? etaNext;
  if (nextStopKm != null && nextStopKm > progressKm && speedForEta > 0) {
    final kmToStop = nextStopKm - progressKm;
    final minsToStop = (kmToStop / speedForEta) * 60.0;
    etaNext = now.add(Duration(seconds: (minsToStop * 60).round()));
  } else if (nextStopAt != null && nextStopAt.isAfter(now)) {
    // Fall back to the planned time when we can't compute one from
    // the current position (e.g. no stop coord).
    etaNext = nextStopAt;
  }

  return TripProgress(
    progressKm: progressKm,
    totalKm: totalKm,
    remainingKm: remainingKm,
    offRouteMeters: snapped.offsetMeters,
    currentSpeedKmh: blended,
    etaToDestination: etaDest,
    etaToNextStop: etaNext,
    cheaperFuelAhead: _cheaperFuelAhead(fuelPrices, progressKm),
  );
}

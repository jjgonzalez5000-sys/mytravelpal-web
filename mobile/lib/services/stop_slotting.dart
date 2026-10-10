import '../api/models.dart';
import '../domain/stop_plan.dart';

/// Minutes a planned meal blocks (matches the backend's meal overhead).
const int kMealBlockMinutes = 60;

/// Spare time kept between two stops.
const int kStopMarginMinutes = 5;

/// The day a point [alongKm] from the origin falls in. A km exactly on a
/// boundary belongs to the day that ENDS there, so no stop counts twice.
DayPlan? dayForKm(List<DayPlan> days, double alongKm) {
  DayPlan? last;
  for (final d in days) {
    if (d.isDwellDay) continue;
    last = d;
    if (alongKm > d.fromKm && alongKm <= d.toKm) return d;
  }
  if (days.isEmpty) return null;
  final firstDriving = days.firstWhere(
    (d) => !d.isDwellDay,
    orElse: () => days.first,
  );
  return alongKm <= firstDriving.fromKm ? firstDriving : last;
}

DateTime _at(DayPlan day, double km) {
  final span = day.toKm - day.fromKm;
  final frac = span <= 0 ? 0.0 : ((km - day.fromKm) / span).clamp(0.0, 1.0);
  final ms = day.endAt.difference(day.startAt).inMilliseconds;
  return day.startAt.add(Duration(milliseconds: (ms * frac).round()));
}

DateTime _round5(DateTime t) {
  final m = t.minute;
  final r = (m / 5).round() * 5;
  return DateTime(t.year, t.month, t.day, t.hour).add(Duration(minutes: r));
}

class _Busy {
  _Busy(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Picks the approximate time to be at a stop: as close as possible to when
/// the driver passes it, in a gap that does not overlap a meal, a rest break
/// or another planned stop. Food stops snap onto a nearby free meal slot.
DateTime bestSlotFor({
  required DayPlan day,
  required double alongKm,
  required int visitMinutes,
  required bool isFood,
  List<StopPlan> others = const [],
}) {
  final lower = day.startAt;
  final upper = (day.sleepAt ?? day.endAt);
  final need = Duration(minutes: visitMinutes + kStopMarginMinutes);
  final ideal = _at(day, alongKm);

  final busy = <_Busy>[
    for (final m in day.mealStops)
      _Busy(m.at, m.at.add(const Duration(minutes: kMealBlockMinutes))),
    for (final r in day.restStops)
      if (r.distanceFromOriginKm > day.fromKm &&
          r.distanceFromOriginKm <= day.toKm)
        _Busy(
          _at(day, r.distanceFromOriginKm),
          _at(day, r.distanceFromOriginKm)
              .add(Duration(minutes: r.recommendedBreakMinutes)),
        ),
    for (final o in others)
      if (o.plannedAt != null)
        _Busy(o.plannedAt!, o.plannedAt!.add(Duration(minutes: o.visitMinutes))),
  ];

  bool free(DateTime start) {
    final end = start.add(need);
    if (start.isBefore(lower) || end.isAfter(upper)) return false;
    for (final b in busy) {
      if (start.isBefore(b.end) && end.isAfter(b.start)) return false;
    }
    return true;
  }

  if (isFood) {
    // A meal slot close to the passing time is the natural place, as long
    // as no other planned stop or rest break already sits there.
    final others2 = <_Busy>[
      for (final r in day.restStops)
        if (r.distanceFromOriginKm > day.fromKm &&
            r.distanceFromOriginKm <= day.toKm)
          _Busy(
            _at(day, r.distanceFromOriginKm),
            _at(day, r.distanceFromOriginKm)
                .add(Duration(minutes: r.recommendedBreakMinutes)),
          ),
      for (final o in others)
        if (o.plannedAt != null)
          _Busy(o.plannedAt!,
              o.plannedAt!.add(Duration(minutes: o.visitMinutes))),
    ];
    DateTime? best;
    for (final m in day.mealStops) {
      final gap = m.at.difference(ideal).inMinutes.abs();
      if (gap > 90) continue;
      final end = m.at.add(need);
      final clash = m.at.isBefore(lower) ||
          end.isAfter(upper) ||
          others2.any((b) => m.at.isBefore(b.end) && end.isAfter(b.start));
      if (clash) continue;
      if (best == null || gap < best.difference(ideal).inMinutes.abs()) {
        best = m.at;
      }
    }
    if (best != null) return _round5(best);
  }

  if (free(ideal)) return _round5(ideal);

  final latestStart = upper.subtract(need);
  final candidates = <DateTime>[
    for (final b in busy) ...[b.end, b.start.subtract(need)],
    // The edges of the day, and the ideal pushed inside it, so a stop near
    // the end is not sent to a gap hours earlier.
    lower,
    latestStart,
    if (ideal.isAfter(latestStart)) latestStart,
    if (ideal.isBefore(lower)) lower,
  ];
  DateTime? pick;
  var pickGap = 1 << 30;
  for (final c in candidates) {
    if (!free(c)) continue;
    final gap = c.difference(ideal).inMinutes.abs();
    if (gap < pickGap) {
      pick = c;
      pickGap = gap;
    }
  }
  if (pick != null) return _round5(pick);

  // No gap holds the visit: keep it inside the day at least.
  final latest = upper.subtract(Duration(minutes: visitMinutes));
  var t = ideal;
  if (t.isAfter(latest)) t = latest;
  if (t.isBefore(lower)) t = lower;
  return _round5(t);
}

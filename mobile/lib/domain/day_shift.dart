import '../api/models.dart';

/// How editing the end time of one day moves kilometres between days.
///
/// Positive [movedKm] means km were pushed from [dayIndex] to the days that
/// follow (the driver stops earlier); negative means km were pulled forward
/// from later days (the driver stops later).
class DayShift {
  const DayShift({
    required this.dayIndex,
    required this.movedKm,
    required this.laterDayIndices,
    required this.daysBefore,
    required this.daysAfter,
  });

  final int dayIndex;
  final double movedKm;
  final List<int> laterDayIndices;
  final int daysBefore;
  final int daysAfter;

  bool get pushed => movedKm > 0;

  /// True when only the very next day absorbs (or gives up) the km.
  bool get nextDayOnly => laterDayIndices.length <= 1;

  /// Positive when the trip gained days, negative when it lost some.
  int get daysDelta => daysAfter - daysBefore;

  int get roundedKm => movedKm.abs().round();
}

/// Differences below this are rounding noise, not a real shift.
const double kDayShiftMinKm = 5.0;

/// Compares two plans of the same trip and reports what changed for the day
/// the driver edited. Null when the day did not move by at least [minKm].
DayShift? computeDayShift(
  List<DayPlan> before,
  List<DayPlan> after,
  int dayIndex, {
  double minKm = kDayShiftMinKm,
}) {
  DayPlan? find(List<DayPlan> days) {
    for (final d in days) {
      if (d.dayIndex == dayIndex) return d;
    }
    return null;
  }

  final b = find(before);
  final a = find(after);
  if (b == null || a == null) return null;

  final moved = b.toKm - a.toKm;
  if (moved.abs() < minKm) return null;

  final beforeByIndex = {for (final d in before) d.dayIndex: d};
  final later = <int>[];
  for (final d in after) {
    if (d.dayIndex <= dayIndex) continue;
    final old = beforeByIndex[d.dayIndex];
    final changed = old == null ||
        (old.fromKm - d.fromKm).abs() >= minKm ||
        (old.toKm - d.toKm).abs() >= minKm;
    if (changed) later.add(d.dayIndex);
  }
  return DayShift(
    dayIndex: dayIndex,
    movedKm: moved,
    laterDayIndices: later,
    daysBefore: before.length,
    daysAfter: after.length,
  );
}

/// Quick estimate shown BEFORE recalculating, from the day's own average
/// speed (which already includes its meals and pauses). Same sign convention
/// as [DayShift.movedKm]. Clamped so it never exceeds the km of the day nor
/// the km still left on the route.
double estimateMovedKm({
  required DayPlan day,
  required DateTime pickedEnd,
  required double routeTotalKm,
}) {
  final hours = day.endAt.difference(day.startAt).inMinutes / 60.0;
  final dayKm = day.toKm - day.fromKm;
  if (hours <= 0 || dayKm <= 0) return 0;
  final kmPerHour = dayKm / hours;
  final deltaHours = pickedEnd.difference(day.endAt).inMinutes / 60.0;
  final deltaKm = deltaHours * kmPerHour;
  if (deltaKm >= 0) {
    final room = (routeTotalKm - day.toKm).clamp(0.0, double.infinity);
    return -(deltaKm > room ? room : deltaKm);
  }
  final cap = (dayKm - 50).clamp(0.0, double.infinity);
  final pushed = -deltaKm;
  return pushed > cap ? cap : pushed;
}

/// The server only accepts 2-14 whole hours of driving per day.
const int kMinDayCapHours = 2;
const int kMaxDayCapHours = 14;

/// Latest end time the server accepts, in minutes after the day's midnight.
const int kMaxDayEndMinutes = 26 * 60;

/// The override for "stop at [endMinutes]" on a day that starts at
/// [startMinutes] (both minutes after midnight; an end at or before the start
/// means after midnight and must already be passed as +24 h). Null when the
/// window is shorter than an hour or the end is later than the server takes.
///
/// `dailyDrivingCapHours` is what a server that predates `end_minutes`
/// understands, so it must stay inside that field's bounds too: sending 1
/// made the whole plan request fail validation.
DayOverride? endTimeOverride({
  required int dayIndex,
  required int? startHour,
  required int startMinutes,
  required int endMinutes,
  required bool pullsKm,
}) {
  if (endMinutes - startMinutes < 60 || endMinutes > kMaxDayEndMinutes) {
    return null;
  }
  return DayOverride(
    dayIndex: dayIndex,
    startHour: startHour,
    dailyDrivingCapHours: ((endMinutes - startMinutes) / 60)
        .round()
        .clamp(kMinDayCapHours, kMaxDayCapHours),
    // Stopping later must not be capped by an old km limit; stopping earlier
    // has no use for one.
    dailyKmCap: pullsKm ? 2000 : null,
    endMinutes: endMinutes,
  );
}

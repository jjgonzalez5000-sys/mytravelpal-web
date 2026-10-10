import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/day_shift.dart';

DayPlan _day(int i, double from, double to, {int startH = 8, int endH = 16}) =>
    DayPlan(
      dayIndex: i,
      startAt: DateTime(2026, 10, 10 + i, startH),
      endAt: DateTime(2026, 10, 10 + i, endH),
      fromKm: from,
      toKm: to,
      mealStops: const [],
      restStops: const [],
    );

void main() {
  endTimeOverrideTests();
  final threeDays = [_day(1, 0, 560), _day(2, 560, 1110), _day(3, 1110, 1675)];

  test('stopping earlier pushes km to the following days', () {
    final after = [_day(1, 0, 440), _day(2, 440, 1000), _day(3, 1000, 1560),
        _day(4, 1560, 1675)];
    final s = computeDayShift(threeDays, after, 1)!;
    expect(s.pushed, isTrue);
    expect(s.roundedKm, 120);
    expect(s.laterDayIndices, [2, 3, 4]);
    expect(s.nextDayOnly, isFalse);
    expect(s.daysDelta, 1);
  });

  test('stopping later pulls km forward and can shorten the trip', () {
    final after = [_day(1, 0, 700), _day(2, 700, 1250), _day(3, 1250, 1675)];
    final s = computeDayShift(threeDays, after, 1)!;
    expect(s.pushed, isFalse);
    expect(s.roundedKm, 140);
    expect(s.daysDelta, 0);
  });

  test('a two-day trip reports the next day only', () {
    final before = [_day(1, 0, 800), _day(2, 800, 1200)];
    final after = [_day(1, 0, 700), _day(2, 700, 1200)];
    final s = computeDayShift(before, after, 1)!;
    expect(s.nextDayOnly, isTrue);
    expect(s.roundedKm, 100);
  });

  test('shifts under the noise threshold are ignored', () {
    final after = [_day(1, 0, 557), _day(2, 557, 1110), _day(3, 1110, 1675)];
    expect(computeDayShift(threeDays, after, 1), isNull);
  });

  test('unknown day gives no shift', () {
    expect(computeDayShift(threeDays, threeDays, 9), isNull);
  });

  group('estimateMovedKm', () {
    final day = _day(1, 0, 560); // 70 km/h wall clock
    test('an earlier end pushes km, never more than the day holds', () {
      final est = estimateMovedKm(
        day: day,
        pickedEnd: DateTime(2026, 10, 11, 14),
        routeTotalKm: 1675,
      );
      expect(est, closeTo(140, 0.5));
      final huge = estimateMovedKm(
        day: day,
        pickedEnd: DateTime(2026, 10, 11, 8, 30),
        routeTotalKm: 1675,
      );
      expect(huge, lessThanOrEqualTo(510));
    });

    test('a later end pulls km, never past the destination', () {
      final est = estimateMovedKm(
        day: day,
        pickedEnd: DateTime(2026, 10, 11, 18),
        routeTotalKm: 1675,
      );
      expect(est, closeTo(-140, 0.5));
      final near = estimateMovedKm(
        day: _day(1, 0, 560),
        pickedEnd: DateTime(2026, 10, 11, 23),
        routeTotalKm: 600,
      );
      expect(near, -40);
    });
  });
}

void endTimeOverrideTests() {
  group('endTimeOverride', () {
    test('a short window never sends fewer driving hours than the server takes',
        () {
      // 08:00 -> 09:15 rounds to 1 h: below the server minimum of 2.
      final o = endTimeOverride(
        dayIndex: 1, startHour: null, startMinutes: 8 * 60,
        endMinutes: 9 * 60 + 15, pullsKm: false,
      )!;
      expect(o.dailyDrivingCapHours, kMinDayCapHours);
      expect(o.endMinutes, 9 * 60 + 15);
    });

    test('every window the picker can produce stays inside the server bounds',
        () {
      for (var end = 9 * 60; end <= kMaxDayEndMinutes; end += 5) {
        final o = endTimeOverride(
          dayIndex: 2, startHour: 8, startMinutes: 8 * 60,
          endMinutes: end, pullsKm: end % 2 == 0,
        );
        if (o == null) continue;
        expect(o.dailyDrivingCapHours,
            inInclusiveRange(kMinDayCapHours, kMaxDayCapHours));
        expect(o.endMinutes, lessThanOrEqualTo(1560));
        expect(o.dailyKmCap == null || o.dailyKmCap! <= 2000, isTrue);
      }
    });

    test('too short or too late is rejected, after midnight is allowed', () {
      expect(endTimeOverride(dayIndex: 1, startHour: null, startMinutes: 480,
          endMinutes: 520, pullsKm: false), isNull);
      expect(endTimeOverride(dayIndex: 1, startHour: null, startMinutes: 480,
          endMinutes: 1561, pullsKm: false), isNull);
      expect(endTimeOverride(dayIndex: 1, startHour: null, startMinutes: 480,
          endMinutes: 24 * 60 + 30, pullsKm: false), isNotNull);
    });

    test('stopping later lifts the km cap, stopping earlier clears it', () {
      final later = endTimeOverride(dayIndex: 1, startHour: null,
          startMinutes: 480, endMinutes: 1200, pullsKm: true)!;
      final earlier = endTimeOverride(dayIndex: 1, startHour: null,
          startMinutes: 480, endMinutes: 900, pullsKm: false)!;
      expect(later.dailyKmCap, 2000);
      expect(earlier.dailyKmCap, isNull);
    });
  });
}

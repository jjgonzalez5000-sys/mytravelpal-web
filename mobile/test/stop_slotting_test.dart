import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/my_place.dart';
import 'package:mytravelpal/domain/stop_plan.dart';
import 'package:mytravelpal/services/stop_slotting.dart';

const _p = LatLon(lat: 40, lon: -3);

DayPlan _day({
  int index = 1,
  double from = 0,
  double to = 560,
  List<MealStopOpt> meals = const [],
  List<RestStop> rests = const [],
  DateTime? sleepAt,
}) =>
    DayPlan(
      dayIndex: index,
      startAt: DateTime(2026, 10, 11, 8),
      endAt: DateTime(2026, 10, 11, 18),
      fromKm: from,
      toKm: to,
      mealStops: meals,
      restStops: rests,
      sleepAt: sleepAt,
    );

MealStopOpt _meal(int hour) => MealStopOpt(
      slot: 'lunch',
      at: DateTime(2026, 10, 11, hour),
      distanceFromOriginKm: 250,
    );

void main() {
  test('a free gap keeps the time the driver passes the spot', () {
    final t = bestSlotFor(
      day: _day(), alongKm: 280, visitMinutes: 30, isFood: false,
    );
    expect(t, DateTime(2026, 10, 11, 13));
  });

  test('a stop that would overlap a meal moves to the nearest free gap', () {
    final day = _day(meals: [_meal(13)]);
    final t = bestSlotFor(
      day: day, alongKm: 280, visitMinutes: 30, isFood: false,
    );
    final end = t.add(const Duration(minutes: 30));
    final mealStart = DateTime(2026, 10, 11, 13);
    final mealEnd = DateTime(2026, 10, 11, 14);
    expect(t.isBefore(mealEnd) && end.isAfter(mealStart), isFalse);
  });

  test('food snaps to a nearby meal slot', () {
    final day = _day(meals: [_meal(13)]);
    final t = bestSlotFor(
      day: day, alongKm: 250, visitMinutes: 45, isFood: true,
    );
    expect(t, DateTime(2026, 10, 11, 13));
  });

  test('two stops in the same gap do not overlap', () {
    final first = StopPlan(
      key: 'place:a', name: 'A', coordinate: _p, source: StopSource.ai,
      visitMinutes: 45, detourMinutes: 4, alongKm: 280,
      plannedAt: DateTime(2026, 10, 11, 13),
    );
    final t = bestSlotFor(
      day: _day(), alongKm: 280, visitMinutes: 45, isFood: false,
      others: [first],
    );
    final end = t.add(const Duration(minutes: 45));
    expect(
      t.isBefore(DateTime(2026, 10, 11, 13, 45)) &&
          end.isAfter(DateTime(2026, 10, 11, 13)),
      isFalse,
    );
  });

  test('the slot stays inside the day', () {
    final t = bestSlotFor(
      day: _day(sleepAt: DateTime(2026, 10, 11, 17)),
      alongKm: 559, visitMinutes: 60, isFood: false,
    );
    expect(t.add(const Duration(minutes: 60)).isAfter(
        DateTime(2026, 10, 11, 17)), isFalse);
    expect(t.isBefore(DateTime(2026, 10, 11, 8)), isFalse);
  });

  test('a stop near the end of the day takes the last free gap, not an early one',
      () {
    final day = _day(meals: [_meal(12)], sleepAt: DateTime(2026, 10, 11, 18));
    final t = bestSlotFor(
      day: day, alongKm: 559, visitMinutes: 45, isFood: false,
    );
    expect(t.isAfter(DateTime(2026, 10, 11, 15)), isTrue);
    expect(t.add(const Duration(minutes: 45)).isAfter(
        DateTime(2026, 10, 11, 18)), isFalse);
  });

  test('food does not snap onto a meal slot another stop already holds', () {
    final taken = StopPlan(
      key: 'place:x', name: 'X', coordinate: _p, source: StopSource.custom,
      visitMinutes: 60, detourMinutes: 0, alongKm: 250,
      plannedAt: DateTime(2026, 10, 11, 13),
    );
    final t = bestSlotFor(
      day: _day(meals: [_meal(13)]), alongKm: 250, visitMinutes: 45,
      isFood: true, others: [taken],
    );
    expect(t, isNot(DateTime(2026, 10, 11, 13)));
  });

  group('dayForKm', () {
    final days = [_day(), _day(index: 2, from: 560, to: 1110)];
    test('a boundary km belongs to the day that ends there', () {
      expect(dayForKm(days, 560)!.dayIndex, 1);
      expect(dayForKm(days, 560.1)!.dayIndex, 2);
    });
    test('km past the end falls on the last driving day', () {
      expect(dayForKm(days, 5000)!.dayIndex, 2);
    });
    test('no days gives null', () {
      expect(dayForKm(const [], 10), isNull);
    });
  });

  test('StopPlan survives a json round trip and tolerates old rows', () {
    final plan = StopPlan(
      key: 'place:1', name: 'Musée du Verrier', coordinate: _p,
      source: StopSource.ai, visitMinutes: 45, detourMinutes: 4,
      alongKm: 123.4, category: MyPlaceCategory.culture,
      plannedAt: DateTime(2026, 10, 11, 12, 30), why: 'glass museum',
    );
    final back = StopPlan.fromJson(plan.toJson());
    expect(back.source, StopSource.ai);
    expect(back.visitMinutes, 45);
    expect(back.plannedAt, DateTime(2026, 10, 11, 12, 30));
    expect(back.category, MyPlaceCategory.culture);

    final minimal = StopPlan.fromJson(
        {'key': 'place:2', 'name': 'X', 'lat': 1, 'lon': 2});
    expect(minimal.source, StopSource.custom);
    expect(minimal.visitMinutes, 30);
    expect(() => StopPlan.fromJson({'key': '', 'name': 'X'}),
        throwsFormatException);
  });
}

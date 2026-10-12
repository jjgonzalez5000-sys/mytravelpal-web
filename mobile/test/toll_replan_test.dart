import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/toll_replan.dart';

const _o = LatLon(lat: 47, lon: 8);
const _d = LatLon(lat: 40, lon: -3);

TripPlanRequest _base({List<TripWaypoint> wps = const []}) => TripPlanRequest(
      origin: _o,
      destination: _d,
      desiredDepartureAt: DateTime(2026, 10, 11, 10),
      waypoints: wps,
    );

PartialTollSkip _skip(double km, double savings, {int points = 6}) =>
    PartialTollSkip(
      label: 'toll@$km',
      distanceFromOriginKm: km,
      savingsEur: savings,
      timePenaltyMinutes: 5,
      extraDistanceKm: 2,
      worthIt: true,
      coordinate: LatLon(lat: 47 - km / 200, lon: 8 - km / 300),
      detourGeometry: [
        for (var i = 0; i < points; i++)
          LatLon(lat: 47 - km / 200 - i * 0.01, lon: 8 - km / 300),
      ],
    );

void main() {
  test('via points never exceed the cap', () {
    final skips2 = [_skip(100, 8), _skip(300, 20)];
    final staleVias = [
      for (var i = 0; i < 3; i++)
        TripWaypoint(
            coordinate: LatLon(lat: 46 - i * 0.1, lon: 7), viaOnly: true),
    ];
    final stops = [
      for (var i = 0; i < 5; i++)
        TripWaypoint(coordinate: LatLon(lat: 45 - i.toDouble(), lon: 5)),
    ];
    // Partial skip again: the three earlier vias take the room that is left.
    final r = buildTollReplanRequest(
      base: _base(wps: [...stops, ...staleVias]),
      baselineSkips: skips2, kept: {0},
    );
    expect(r.waypoints.where((w) => !w.viaOnly).length, 5);
    expect(r.waypoints.length, lessThanOrEqualTo(kMaxPlanWaypoints));

    // Everything skipped: no leftover vias next to avoidTolls.
    final all = buildTollReplanRequest(
      base: _base(wps: [...stops, ...staleVias]),
      baselineSkips: skips2, kept: <int>{},
    );
    expect(all.avoidTolls, isTrue);
    expect(all.waypoints.any((w) => w.viaOnly), isFalse);

    // Nothing new skipped but stops were added past the cap: still valid.
    final added = [
      for (var i = 0; i < 4; i++)
        TripWaypoint(coordinate: LatLon(lat: 41 + i.toDouble(), lon: 2)),
    ];
    final capped = buildTollReplanRequest(
      base: _base(wps: [...stops, ...staleVias]),
      baselineSkips: skips2, kept: {0, 1}, extraStops: added,
    );
    // The driver's own stops are never dropped (the screen refuses to add
    // more than the cap); only routing hints give way.
    expect(capped.waypoints.where((w) => !w.viaOnly).length, 9);
    expect(capped.waypoints.any((w) => w.viaOnly), isFalse);
  });

  final skips = [_skip(100, 8), _skip(300, 20), _skip(500, 5)];

  test('a chained skip keeps the via points of the earlier one', () {
    final first = buildTollReplanRequest(
      base: _base(), baselineSkips: skips, kept: {0, 2},
    );
    final firstVias = first.waypoints.where((w) => w.viaOnly).toList();
    expect(firstVias, isNotEmpty);

    // New road: the earlier booth is gone and a fresh list is proposed.
    final fresh = [_skip(150, 6), _skip(400, 9)];
    final second = buildTollReplanRequest(
      base: first, baselineSkips: fresh, kept: {0},
    );
    final keys = second.waypoints
        .where((w) => w.viaOnly)
        .map((w) => '${w.coordinate.lat},${w.coordinate.lon}')
        .toSet();
    for (final v in firstVias) {
      expect(keys, contains('${v.coordinate.lat},${v.coordinate.lon}'));
    }
    expect(second.waypoints.where((w) => w.viaOnly).length,
        greaterThan(firstVias.length));
    expect(second.avoidTolls, isFalse);
  });

  test('earlier vias win the room over new ones when the cap is tight', () {
    final stops = [
      for (var i = 0; i < 6; i++)
        TripWaypoint(coordinate: LatLon(lat: 45 - i.toDouble(), lon: 5)),
    ];
    final earlier = [
      for (var i = 0; i < 2; i++)
        TripWaypoint(
            coordinate: LatLon(lat: 46 - i * 0.1, lon: 7), viaOnly: true),
    ];
    final r = buildTollReplanRequest(
      base: _base(wps: [...stops, ...earlier]),
      baselineSkips: [_skip(100, 50), _skip(300, 5)],
      kept: {1},
    );
    expect(r.waypoints.length, lessThanOrEqualTo(kMaxPlanWaypoints));
    final vias = r.waypoints.where((w) => w.viaOnly).toList();
    expect(vias.length, 2);
    expect(vias.map((w) => w.coordinate.lat).toSet(), {46.0, 45.9});
  });

  test('nothing skipped keeps the paid route request', () {
    final r = buildTollReplanRequest(
      base: _base(), baselineSkips: skips, kept: {0, 1, 2},
    );
    expect(r.avoidTolls, isFalse);
    expect(r.waypoints, isEmpty);
  });

  test('every toll skipped asks for a toll-free route, no via points', () {
    final r = buildTollReplanRequest(
      base: _base(), baselineSkips: skips, kept: <int>{},
    );
    expect(r.avoidTolls, isTrue);
    expect(r.waypoints, isEmpty);
  });

  test('some skipped become via-only waypoints, user stops stay first', () {
    final stop = TripWaypoint(
      coordinate: const LatLon(lat: 44, lon: 3), label: 'Lunch',
    );
    final r = buildTollReplanRequest(
      base: _base(wps: [stop]), baselineSkips: skips, kept: {0, 2},
    );
    expect(r.avoidTolls, isFalse);
    final vias = r.waypoints.where((w) => w.viaOnly).toList();
    expect(vias.length, 2);
    expect(r.waypoints.where((w) => !w.viaOnly).single.label, 'Lunch');
    expect(r.toJson()['waypoints'].where((w) => w['via_only'] == true).length,
        2);
  });

  test('the cap drops the least valuable skips, never the user stops', () {
    final many = [for (var i = 0; i < 6; i++) _skip(100.0 * (i + 1), i + 1.0)];
    final stops = [
      for (var i = 0; i < 5; i++)
        TripWaypoint(coordinate: LatLon(lat: 45 - i.toDouble(), lon: 5)),
    ];
    final r = buildTollReplanRequest(
      base: _base(wps: stops), baselineSkips: many, kept: {0},
    );
    expect(r.waypoints.length, lessThanOrEqualTo(kMaxPlanWaypoints));
    expect(r.waypoints.where((w) => !w.viaOnly).length, 5);
  });

  test('a skip without a computed detour adds nothing', () {
    final bare = PartialTollSkip(
      label: 'x', distanceFromOriginKm: 50, savingsEur: 9,
      timePenaltyMinutes: 1, extraDistanceKm: 1, worthIt: true,
      coordinate: const LatLon(lat: 46, lon: 7),
    );
    final r = buildTollReplanRequest(
      base: _base(), baselineSkips: [bare, skips[0]], kept: {1},
    );
    expect(r.waypoints, isEmpty);
    expect(r.avoidTolls, isFalse);
  });

  test('copyWith keeps every field a replan must not lose', () {
    final base = TripPlanRequest(
      origin: _o, destination: _d,
      desiredDepartureAt: DateTime(2026, 10, 11, 10),
      includeActivities: true,
      garageVehicleId: 'g1',
      dayOverrides: const [DayOverride(dayIndex: 1, endMinutes: 1000)],
    );
    final r = base.copyWith(avoidTolls: true);
    expect(r.includeActivities, isTrue);
    expect(r.garageVehicleId, 'g1');
    expect(r.dayOverrides.single.endMinutes, 1000);
    expect(r.toJson()['avoid_tolls'], true);
    expect(r.toJson()['day_overrides'][0]['end_minutes'], 1000);
  });
}

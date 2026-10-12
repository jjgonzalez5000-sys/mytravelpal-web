import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/plan_lru.dart';

const _o = LatLon(lat: 47, lon: 8);
const _d = LatLon(lat: 40, lon: -3);

TripPlanRequest _req({
  List<TripWaypoint> wps = const [],
  DateTime? at,
  List<DayOverride> overrides = const [],
  bool avoidTolls = false,
}) =>
    TripPlanRequest(
      origin: _o,
      destination: _d,
      desiredDepartureAt: at ?? DateTime(2026, 10, 11, 10, 15, 30),
      waypoints: wps,
      dayOverrides: overrides,
      avoidTolls: avoidTolls,
    );

TripWaypoint _wp(double lat, double lon, {bool via = false}) =>
    TripWaypoint(coordinate: LatLon(lat: lat, lon: lon), viaOnly: via);

TripPlanResponse _plan(double km) => TripPlanResponse(
      route: RouteInfo(
        distanceKm: km,
        freeFlowMinutes: 60,
        polyline: '',
        tollCostEur: 0,
        countriesCrossed: const [],
      ),
      timeWindows: const [],
      fuelPrices: const [],
      hotels: const [],
      restaurants: const [],
      restStops: const [],
      adverseEvents: const [],
    );

void main() {
  group('requestSignature', () {
    test('ignores waypoint order, seconds and override order', () {
      final a = _req(
        wps: [_wp(44, 3), _wp(43, 2, via: true)],
        at: DateTime(2026, 10, 11, 10, 15, 5),
        overrides: const [
          DayOverride(dayIndex: 2, endMinutes: 1000),
          DayOverride(dayIndex: 1, startHour: 7),
        ],
      );
      final b = _req(
        wps: [_wp(43, 2, via: true), _wp(44, 3)],
        at: DateTime(2026, 10, 11, 10, 15, 55),
        overrides: const [
          DayOverride(dayIndex: 1, startHour: 7),
          DayOverride(dayIndex: 2, endMinutes: 1000),
        ],
      );
      expect(requestSignature(a), requestSignature(b));
    });

    test('tells apart anything the server would answer differently', () {
      final base = requestSignature(_req(wps: [_wp(44, 3)]));
      expect(requestSignature(_req(wps: [_wp(44, 3), _wp(45, 3)])), isNot(base));
      expect(requestSignature(_req(wps: [_wp(44, 3, via: true)])), isNot(base));
      expect(requestSignature(_req(wps: [_wp(44, 3)], avoidTolls: true)),
          isNot(base));
      expect(
        requestSignature(
            _req(wps: [_wp(44, 3)], at: DateTime(2026, 10, 11, 10, 16))),
        isNot(base),
      );
      expect(
        requestSignature(_req(
          wps: [_wp(44, 3)],
          overrides: const [DayOverride(dayIndex: 1, startHour: 6)],
        )),
        isNot(base),
      );
    });

    test('does not change the request it describes', () {
      final r = _req(wps: [_wp(44, 3), _wp(43, 2)]);
      requestSignature(r);
      expect(r.waypoints.first.coordinate.lat, 44);
    });
  });

  group('PlanLru', () {
    test('returns what was stored and nothing for an unknown signature', () {
      final lru = PlanLru();
      final core = _plan(100);
      lru.putCore('a', core);
      expect(lru.get('a')!.core, same(core));
      expect(lru.get('b'), isNull);
    });

    test('enrich is attached to its core entry', () {
      final lru = PlanLru();
      lru.putCore('a', _plan(100));
      expect(lru.get('a')!.enrich, isNull);
      final enrich = _plan(0);
      lru.putEnrich('a', enrich);
      expect(lru.get('a')!.enrich, same(enrich));
      lru.putEnrich('missing', enrich);
      expect(lru.get('missing'), isNull);
    });

    test('evicts the least recently used entry past capacity', () {
      final lru = PlanLru(capacity: 3);
      lru.putCore('a', _plan(1));
      lru.putCore('b', _plan(2));
      lru.putCore('c', _plan(3));
      lru.get('a');
      lru.putCore('d', _plan(4));
      expect(lru.length, 3);
      expect(lru.get('b'), isNull);
      expect(lru.get('a'), isNotNull);
      expect(lru.get('c'), isNotNull);
      expect(lru.get('d'), isNotNull);
    });

    test('putting an existing signature replaces it without growing', () {
      final lru = PlanLru(capacity: 2);
      lru.putCore('a', _plan(1));
      final fresh = _plan(2);
      lru.putCore('a', fresh);
      expect(lru.length, 1);
      expect(lru.get('a')!.core, same(fresh));
    });

    test('core expires after 10 minutes and enrich after 5', () {
      var now = DateTime(2026, 10, 11, 10);
      final lru = PlanLru(now: () => now);
      lru.putCore('a', _plan(1));
      now = now.add(const Duration(minutes: 1));
      lru.putEnrich('a', _plan(0));
      now = now.add(const Duration(minutes: 5, seconds: 1));
      final mid = lru.get('a');
      expect(mid, isNotNull);
      expect(mid!.enrich, isNull);
      now = now.add(const Duration(minutes: 5));
      expect(lru.get('a'), isNull);
      expect(lru.length, 0);
    });
  });
}

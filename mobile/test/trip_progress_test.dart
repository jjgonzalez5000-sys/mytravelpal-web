import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/trip_progress.dart';

void main() {
  // Straight west-to-east segment along the equator: 3 points ~1 km
  // apart. The equirectangular projection inside `snapToRoute` treats
  // 1° longitude at the equator as ~111.32 km — so lon 0.009 ≈ 1 km.
  final route = RouteReference.build([
    const LatLon(lat: 0, lon: 0),
    const LatLon(lat: 0, lon: 0.009),
    const LatLon(lat: 0, lon: 0.018),
  ]);

  group('RouteReference', () {
    test('cumulative distances match haversine to within 1 %', () {
      // Each segment ≈ 1.001 km (haversine on the equator).
      expect(route.cumulativeMeters[0], 0);
      expect(route.cumulativeMeters[1], closeTo(1001.6, 15));
      expect(route.totalMeters, closeTo(2003.3, 30));
    });

    test('degenerate polyline of one point is safe', () {
      final ref = RouteReference.build([const LatLon(lat: 40, lon: -3)]);
      expect(ref.totalMeters, 0);
      final snap = snapToRoute(const LatLon(lat: 40, lon: -3), ref);
      expect(snap.progressMeters, 0);
      expect(snap.offsetMeters, 0);
    });
  });

  group('snapToRoute', () {
    test('exact-on-route point projects to the vertex', () {
      final snap =
          snapToRoute(const LatLon(lat: 0, lon: 0.009), route);
      expect(snap.progressMeters, closeTo(1001.6, 20));
      expect(snap.offsetMeters, lessThan(1.0));
    });

    test('perpendicular offset lands on the nearest segment', () {
      // 1 km east of origin, then 200 m north — offset should be
      // ~200 m, progress ~1 km.
      const off = LatLon(lat: 0.0018, lon: 0.009);  // 0.0018° lat ≈ 200 m
      final snap = snapToRoute(off, route);
      expect(snap.progressMeters, closeTo(1001.6, 30));
      expect(snap.offsetMeters, closeTo(200, 20));
    });

    test('past-end fix clamps to the last vertex', () {
      // 100 m past the end of the polyline.
      const past = LatLon(lat: 0, lon: 0.019);
      final snap = snapToRoute(past, route);
      expect(snap.progressMeters, closeTo(route.totalMeters, 5));
    });
  });

  group('SpeedTracker', () {
    test('needs ≥ 2 samples before returning a speed', () {
      final tracker = SpeedTracker();
      expect(tracker.avgKmh(), isNull);
      tracker.addFix(const LatLon(lat: 0, lon: 0), DateTime(2026));
      expect(tracker.avgKmh(), isNull);
    });

    test('prefers OS-reported speed when accurate', () {
      final tracker = SpeedTracker();
      tracker.addFix(
        const LatLon(lat: 0, lon: 0), DateTime(2026), speedKmh: 100,
      );
      tracker.addFix(
        const LatLon(lat: 0, lon: 0.001),
        DateTime(2026).add(const Duration(seconds: 10)),
        speedKmh: 120,
      );
      // Average of the two reported speeds, not the position delta.
      expect(tracker.avgKmh(), closeTo(110, 0.1));
    });

    test('falls back to distance / time when no reported speed', () {
      final tracker = SpeedTracker();
      final t0 = DateTime(2026);
      tracker.addFix(const LatLon(lat: 0, lon: 0), t0);
      // 1 km in 60 s = 60 km/h.
      tracker.addFix(
        const LatLon(lat: 0, lon: 0.009),
        t0.add(const Duration(seconds: 60)),
      );
      expect(tracker.avgKmh(), closeTo(60, 5));
    });
  });

  group('computeProgress ETA', () {
    test('remaining time scales with blended speed', () {
      final tracker = SpeedTracker();
      final now = DateTime(2026, 8, 25, 10);
      // 100 km/h reported, halfway through a 100 km trip → 30 min
      // remaining after blending with a 100 km/h planned speed too.
      tracker.addFix(
        const LatLon(lat: 0, lon: 0), now, speedKmh: 100,
      );
      tracker.addFix(
        const LatLon(lat: 0, lon: 0.001),
        now.add(const Duration(seconds: 5)),
        speedKmh: 100,
      );
      final progress = computeProgress(
        route: route,
        fix: const LatLon(lat: 0, lon: 0.009),  // halfway
        now: now,
        speedTracker: tracker,
        plannedTotalMinutes: 60,  // implies planned 2 km/h — irrelevant here
        fuelPrices: const [],
      );
      // Remaining ~1 km at ~100 km/h ≈ 36 s.
      final etaMinutesFromNow =
          progress.etaToDestination.difference(now).inSeconds;
      expect(etaMinutesFromNow, closeTo(36, 20));
      expect(progress.progressKm, closeTo(1.0, 0.1));
      expect(progress.remainingKm, closeTo(1.0, 0.1));
    });
  });

  group('cheaper fuel ahead', () {
    LatLon coord(double lat, double lon) => LatLon(lat: lat, lon: lon);
    FuelPrice station({
      required String name, required double price, required double km,
    }) =>
        FuelPrice(
          stationName: name,
          country: Country.es,
          priceEurPerL: price,
          priceAvailable: true,
          distanceFromOriginKm: km,
          coordinate: coord(0, km / 100),
        );

    test('surfaces a station meaningfully cheaper than the median', () {
      final tracker = SpeedTracker();
      tracker.addFix(coord(0, 0), DateTime(2026), speedKmh: 100);
      tracker.addFix(coord(0, 0.001),
          DateTime(2026).add(const Duration(seconds: 5)), speedKmh: 100);
      final progress = computeProgress(
        route: route,
        fix: coord(0, 0.009),  // ~1 km in
        now: DateTime(2026),
        speedTracker: tracker,
        plannedTotalMinutes: 60,
        fuelPrices: [
          station(name: 'Repsol', price: 1.85, km: 5),
          station(name: 'Cepsa', price: 1.90, km: 10),
          station(name: 'Ballenoil', price: 1.75, km: 20),
          station(name: 'Shell', price: 1.95, km: 30),
        ],
      );
      final hint = progress.cheaperFuelAhead;
      expect(hint, isNotNull);
      expect(hint!.station.stationName, 'Ballenoil');
      expect(hint.savingsEurPerL, greaterThan(0.03));
    });

    test('null when nothing ahead beats the median by the min delta', () {
      final tracker = SpeedTracker();
      tracker.addFix(coord(0, 0), DateTime(2026), speedKmh: 100);
      tracker.addFix(coord(0, 0.001),
          DateTime(2026).add(const Duration(seconds: 5)), speedKmh: 100);
      final progress = computeProgress(
        route: route,
        fix: coord(0, 0.009),
        now: DateTime(2026),
        speedTracker: tracker,
        plannedTotalMinutes: 60,
        // All within 1 cent — none is meaningfully cheaper.
        fuelPrices: [
          station(name: 'A', price: 1.85, km: 5),
          station(name: 'B', price: 1.86, km: 10),
          station(name: 'C', price: 1.84, km: 20),
        ],
      );
      expect(progress.cheaperFuelAhead, isNull);
    });
  });
}

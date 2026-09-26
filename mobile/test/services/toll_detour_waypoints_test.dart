import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/toll_detour_waypoints.dart';

/// Builds a PartialTollSkip whose only distinguishing feature (for
/// these tests) is the detour polyline. The remaining fields are set
/// to trivial defaults — they don't affect waypoint sampling.
PartialTollSkip _skipWith(List<LatLon> geom) => PartialTollSkip(
      label: 'test',
      kind: 'booth',
      index: 1,
      total: 1,
      distanceFromOriginKm: 50,
      savingsEur: 8,
      timePenaltyMinutes: 6,
      extraDistanceKm: 4,
      worthIt: true,
      coordinate: const LatLon(lat: 43.0, lon: 2.0),
      detourGeometry: geom,
    );

void main() {
  group('detourWaypointsFor', () {
    test('empty geometry returns empty list', () {
      expect(detourWaypointsFor(_skipWith(const [])), isEmpty);
    });

    test('single-point geometry returns that midpoint', () {
      final pt = const LatLon(lat: 43.1, lon: 2.1);
      final out = detourWaypointsFor(_skipWith(<LatLon>[pt]));
      expect(out, hasLength(1));
      expect(out.single, pt);
    });

    test('3-point geometry returns midpoint only', () {
      final pts = <LatLon>[
        const LatLon(lat: 43.0, lon: 2.0),
        const LatLon(lat: 43.1, lon: 2.1),
        const LatLon(lat: 43.2, lon: 2.2),
      ];
      final out = detourWaypointsFor(_skipWith(pts));
      expect(out, hasLength(1));
      // length ~/ 2 = 1 -> midpoint
      expect(out.single, pts[1]);
    });

    test('10-point geometry returns two anchors ~30% and ~70%', () {
      final pts = <LatLon>[
        for (var i = 0; i < 10; i++)
          LatLon(lat: 43.0 + i * 0.01, lon: 2.0 + i * 0.01),
      ];
      final out = detourWaypointsFor(_skipWith(pts));
      expect(out, hasLength(2));
      // (10 * 0.30).round() = 3 ; (10 * 0.70).round() = 7
      expect(out[0], pts[3]);
      expect(out[1], pts[7]);
      // Order preserved (low km before high km).
      expect(out[0].lat, lessThan(out[1].lat));
    });

    test('4-point geometry returns two distinct anchors', () {
      final pts = <LatLon>[
        const LatLon(lat: 43.0, lon: 2.0),
        const LatLon(lat: 43.1, lon: 2.1),
        const LatLon(lat: 43.2, lon: 2.2),
        const LatLon(lat: 43.3, lon: 2.3),
      ];
      final out = detourWaypointsFor(_skipWith(pts));
      // (4 * 0.30).round() = 1 ; (4 * 0.70).round() = 3
      expect(out, hasLength(2));
      expect(out[0], pts[1]);
      expect(out[1], pts[3]);
    });

    test('cap at 2 waypoints even for very long geometries', () {
      final pts = <LatLon>[
        for (var i = 0; i < 200; i++)
          LatLon(lat: 43.0 + i * 0.001, lon: 2.0 + i * 0.001),
      ];
      final out = detourWaypointsFor(_skipWith(pts));
      expect(out.length, lessThanOrEqualTo(2));
    });
  });
}

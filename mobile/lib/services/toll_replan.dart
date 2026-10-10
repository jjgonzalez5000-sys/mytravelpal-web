import '../api/models.dart';
import 'toll_detour_waypoints.dart';

/// Most waypoints the backend accepts on one plan.
const int kMaxPlanWaypoints = 8;

/// Request for the route the driver actually wants to drive once some
/// tolls are skipped, so every stop, day and POI is computed on that road.
///
/// [baselineSkips] are the skips the server proposed for the PAID route and
/// [kept] holds the indices the driver still pays. Rules:
/// - nothing skipped      -> [base] unchanged (a trip already routed away
///   from tolls stays that way);
/// - every toll skipped   -> `avoidTolls`, no via points (a clean toll-free
///   route beats stitching detours together);
/// - some skipped         -> via-only waypoints taken from each skipped
///   detour, merged with the real stops in km order and capped, user stops
///   first.
TripPlanRequest buildTollReplanRequest({
  required TripPlanRequest base,
  required List<PartialTollSkip> baselineSkips,
  required Set<int> kept,
  List<TripWaypoint> extraStops = const [],
}) {
  final skipped = <int>[
    for (var i = 0; i < baselineSkips.length; i++)
      if (!kept.contains(i)) i,
  ];
  final realStops = <TripWaypoint>[
    for (final w in [...base.waypoints, ...extraStops])
      if (!w.viaOnly) w,
  ];
  final keptVias = <TripWaypoint>[
    for (final w in base.waypoints)
      if (w.viaOnly) w,
  ];

  // Nothing new to skip: the request stays as it is (a trip already routed
  // away from tolls stays that way, with the vias that got it there).
  if (skipped.isEmpty) {
    final merged = _mergeInRouteOrder(
      base.origin,
      realStops,
      [for (final v in keptVias) (km: 0.0, wp: v)],
    );
    return base.copyWith(waypoints: _capWaypoints(merged));
  }
  // Every toll skipped: a clean toll-free route beats stitched detours, so
  // old via points are dropped.
  if (skipped.length == baselineSkips.length) {
    return base.copyWith(waypoints: realStops, avoidTolls: true);
  }

  // Some skipped: vias are recomputed from the skips, never accumulated.
  // Biggest savings first when the cap forces a choice; the driver's own
  // stops always keep their place.
  final ranked = [...skipped]..sort(
      (a, b) => baselineSkips[b].savingsEur
          .compareTo(baselineSkips[a].savingsEur),
    );
  final room =
      (kMaxPlanWaypoints - realStops.length).clamp(0, kMaxPlanWaypoints);
  final vias = <({double km, TripWaypoint wp})>[];
  for (final i in ranked) {
    final skip = baselineSkips[i];
    final pts = detourWaypointsFor(skip);
    if (pts.isEmpty || vias.length + pts.length > room) continue;
    for (final p in pts) {
      vias.add((
        km: skip.distanceFromOriginKm,
        wp: TripWaypoint(coordinate: p, viaOnly: true),
      ));
    }
  }
  vias.sort((a, b) => a.km.compareTo(b.km));
  return base.copyWith(
    waypoints: _mergeInRouteOrder(base.origin, realStops, vias),
    avoidTolls: false,
  );
}

/// Real stops first; vias only fill what is left under the server's cap.
List<TripWaypoint> _capWaypoints(List<TripWaypoint> all) {
  if (all.length <= kMaxPlanWaypoints) return all;
  final real = all.where((w) => !w.viaOnly).toList();
  final room = (kMaxPlanWaypoints - real.length).clamp(0, kMaxPlanWaypoints);
  var vias = 0;
  return [
    for (final w in all)
      if (!w.viaOnly || vias++ < room) w,
  ];
}

List<TripWaypoint> _mergeInRouteOrder(
  LatLon origin,
  List<TripWaypoint> stops,
  List<({double km, TripWaypoint wp})> vias,
) {
  if (vias.isEmpty) return stops;
  double d(LatLon p) {
    final dx = p.lon - origin.lon;
    final dy = p.lat - origin.lat;
    return dx * dx + dy * dy;
  }

  // Stops keep their given order; vias are slotted by distance from origin.
  final out = <TripWaypoint>[...stops];
  for (final v in vias) {
    var at = out.length;
    for (var i = 0; i < out.length; i++) {
      if (d(out[i].coordinate) > d(v.wp.coordinate)) {
        at = i;
        break;
      }
    }
    out.insert(at, v.wp);
  }
  return out;
}

import '../api/models.dart';

/// Sample 0-2 anchor points from a PartialTollSkip's detour polyline
/// so a Google Maps deep-link can route through them and — by
/// visiting those off-motorway coordinates — bypass the specific toll
/// stretch the driver chose to skip.
///
/// Google Maps' `dir?api=1&avoid=tolls` flag is binary (whole trip or
/// nothing). Injecting waypoints on the alternative road is the only
/// way to skip ONE toll while keeping the motorway for the rest.
///
/// Sampling strategy:
/// - Empty geometry -> `[]`. Backend heuristic mode doesn't compute
///   an alternative; without it we can't do better than doing
///   nothing here (the caller decides whether to fall back to
///   `avoid=tolls`).
/// - 1-3 points -> single midpoint (`length / 2`), guaranteed OFF
///   the motorway since it comes from the detour polyline itself.
/// - 4+ points -> two anchors at ~30 % and ~70 % of the geometry;
///   two points force Google to route via the detour segment rather
///   than snapping back to the toll motorway between one waypoint
///   and the destination.
///
/// Kept at ≤ 2 points per skip so a route with several skipped
/// tolls stays under Google Maps' 9-waypoint cap. Caller is expected
/// to do a final cap when combining with user stops.
List<LatLon> detourWaypointsFor(PartialTollSkip skip) {
  final geom = skip.detourGeometry;
  if (geom.isEmpty) return const <LatLon>[];
  if (geom.length <= 3) {
    return <LatLon>[geom[geom.length ~/ 2]];
  }
  final iLow = (geom.length * 0.30).round().clamp(0, geom.length - 1);
  final iHigh = (geom.length * 0.70).round().clamp(0, geom.length - 1);
  if (iLow == iHigh) {
    return <LatLon>[geom[iLow]];
  }
  return <LatLon>[geom[iLow], geom[iHigh]];
}

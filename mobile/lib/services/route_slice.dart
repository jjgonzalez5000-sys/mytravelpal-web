import '../api/models.dart' show LatLon;

/// The part of a route between [fromKm] and [toKm], thinned to at most
/// [maxPoints] points (the suggestions endpoint accepts 600).
///
/// The geometry carries no per-point distance, so, like the rest of the
/// result screen, points are assumed evenly spread along [routeKm].
List<LatLon> sliceRoute(
  List<LatLon> geometry,
  double routeKm, {
  required double fromKm,
  required double toKm,
  int maxPoints = 400,
}) {
  if (geometry.length < 2 || routeKm <= 0) return const [];
  final last = geometry.length - 1;
  int indexAt(double km) =>
      ((km / routeKm).clamp(0.0, 1.0) * last).round().clamp(0, last);
  var from = indexAt(fromKm < toKm ? fromKm : toKm);
  var to = indexAt(fromKm < toKm ? toKm : fromKm);
  if (to - from < 1) {
    // A stay-put day or a sliver: widen to one segment so a line exists.
    if (to < last) {
      to += 1;
    } else if (from > 0) {
      from -= 1;
    } else {
      return const [];
    }
  }
  final span = to - from;
  final stride = span + 1 <= maxPoints ? 1 : (span / (maxPoints - 1)).ceil();
  final out = <LatLon>[];
  for (var i = from; i < to; i += stride) {
    out.add(geometry[i]);
  }
  out.add(geometry[to]);
  return out;
}

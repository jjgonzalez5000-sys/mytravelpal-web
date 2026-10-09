import 'dart:math' as math;

import '../api/models.dart' show LatLon;
import '../domain/my_place.dart';
import 'selection_check.dart' show haversineKm;

/// A saved place is offered for a route when it lies within this distance
/// of it. 15 km is a quarter-hour detour at country-road speed: far enough
/// to catch a good viewpoint one exit away, close enough to still be a stop
/// rather than a different trip.
const double kMyPlaceMaxKmFromRoute = 15.0;

/// Minutes assumed for actually visiting a place (stretch the legs, eat,
/// take the photo). Added to the detour when the place joins the route.
const double kMyPlaceVisitMinutes = 30.0;

/// Average speed off the motorway, used only to turn the distance to the
/// route into an approximate detour time.
const double _offRouteKmh = 50.0;

/// A saved place that lies near the current route.
class PlaceOnRoute {
  const PlaceOnRoute({
    required this.place,
    required this.distanceKm,
    required this.alongKm,
  });

  final MyPlace place;

  /// Shortest distance from the place to the route line.
  final double distanceKm;

  /// How far along the route (from the origin) the closest point is.
  final double alongKm;

  /// Approximate extra driving to go there and come back: out and back at
  /// off-route speed, never less than 2 min for leaving and rejoining.
  double get detourMinutes =>
      math.max(2.0, 2 * distanceKm / _offRouteKmh * 60);
}

/// Distance in km from [p] to the polyline [line], and how far along the
/// line the closest point sits. [cumulativeKm] is the running length of
/// [line] (same length as [line], first entry 0).
({double distanceKm, double alongKm}) nearestOnPolyline(
  LatLon p,
  List<LatLon> line,
  List<double> cumulativeKm,
) {
  var bestDist = double.infinity;
  var bestAlong = 0.0;
  // Local flat projection around p: good to well under a metre per km at
  // the distances involved here.
  const kmPerDegree = 111.195;
  final cosLat = math.cos(p.lat * math.pi / 180);
  for (var i = 0; i < line.length - 1; i++) {
    final ax = (line[i].lon - p.lon) * cosLat * kmPerDegree;
    final ay = (line[i].lat - p.lat) * kmPerDegree;
    final bx = (line[i + 1].lon - p.lon) * cosLat * kmPerDegree;
    final by = (line[i + 1].lat - p.lat) * kmPerDegree;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (d < bestDist) {
      bestDist = d;
      bestAlong =
          cumulativeKm[i] + t * (cumulativeKm[i + 1] - cumulativeKm[i]);
    }
  }
  return (distanceKm: bestDist, alongKm: bestAlong);
}

/// The saved [places] within [maxKm] of the route [geometry], in the order
/// they are met along it. Empty when the route has fewer than two points.
List<PlaceOnRoute> matchPlacesToRoute(
  List<MyPlace> places,
  List<LatLon> geometry, {
  double maxKm = kMyPlaceMaxKmFromRoute,
}) {
  if (places.isEmpty || geometry.length < 2) return const [];
  final cumulative = <double>[0.0];
  for (var i = 1; i < geometry.length; i++) {
    cumulative.add(cumulative.last + haversineKm(geometry[i - 1], geometry[i]));
  }
  final out = <PlaceOnRoute>[];
  for (final place in places) {
    final hit = nearestOnPolyline(place.coordinate, geometry, cumulative);
    if (hit.distanceKm <= maxKm) {
      out.add(PlaceOnRoute(
        place: place,
        distanceKm: hit.distanceKm,
        alongKm: hit.alongKm,
      ));
    }
  }
  out.sort((a, b) => a.alongKm.compareTo(b.alongKm));
  return out;
}

final RegExp _coordPair =
    RegExp(r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})');

/// First `lat,lon` pair found in [text] (a pasted map link such as
/// `.../@40.4168,-3.7038,15z` or `?q=40.4168,-3.7038`, or just the two
/// numbers). Null when there is none or it is out of range. Short links
/// (`maps.app.goo.gl/...`) carry no coordinates and are not resolved.
LatLon? parseCoordinates(String text) {
  final m = _coordPair.firstMatch(text);
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lon = double.tryParse(m.group(2)!);
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return LatLon(lat: lat, lon: lon);
}

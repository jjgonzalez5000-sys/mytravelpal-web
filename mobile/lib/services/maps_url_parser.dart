import 'dart:io';

import '../api/models.dart';
import 'trip_sharing.dart';

/// Signature for a place resolver — used when a Maps URL contains a
/// human-readable place name instead of coordinates. Returns the
/// first geocode match, or null on failure.
typedef GeocodeFn = Future<List<GeocodeResult>> Function(String query);

/// Parse a Google Maps directions URL into a [SharedTrip].
///
/// Handles three shapes:
///   1. `google.com/maps/dir/?api=1&origin=…&destination=…&waypoints=…|…`
///      (the "api=1" contract Google publishes — cleanest, no scraping).
///   2. `google.com/maps/dir/A/B/C/@lat,lon,zoom` (path form; each
///      segment is either `lat,lon` or a URL-encoded place name).
///   3. `maps.app.goo.gl/*`, `goo.gl/maps/*` — short-links. We follow
///      redirects manually (up to 3 hops) until we land on a long URL,
///      then recurse.
///
/// Names that aren't coordinates are resolved via [geocode]. If a name
/// fails to geocode, that stop is dropped rather than aborting the
/// whole import — the user can add it manually.
///
/// Departure time is set to "now" — Google's URLs don't carry a
/// desired departure the way MyTravelPal does. The user can edit it
/// on the plan form.
Future<SharedTrip?> parseGoogleMapsUrl(
  String rawUrl, {
  required GeocodeFn geocode,
  int redirectDepth = 0,
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;

  final host = uri.host.toLowerCase();

  // Shortlink expansion — follow one 3xx hop and recurse.
  if ((host == 'maps.app.goo.gl' ||
          host == 'goo.gl' ||
          host == 'g.co') &&
      redirectDepth < 3) {
    final expanded = await _expandShortlink(uri);
    if (expanded == null) return null;
    return parseGoogleMapsUrl(
      expanded,
      geocode: geocode,
      redirectDepth: redirectDepth + 1,
    );
  }

  if (!host.contains('google.') || !uri.path.contains('/maps')) {
    return null;
  }

  // Try the api=1 query params first — they're the contract Google
  // publishes and the most reliable to parse.
  final apiOne = await _parseApiOneShape(uri, geocode);
  if (apiOne != null) return apiOne;

  // Fall back to path form: /maps/dir/A/B/C[/@lat,lon,zoom]
  return _parsePathShape(uri, geocode);
}

Future<String?> _expandShortlink(Uri uri) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    final req = await client.getUrl(uri);
    req.followRedirects = false;
    final res = await req.close();
    // Drain body so the socket returns to the pool cleanly.
    await res.drain<void>();
    if (res.statusCode >= 300 && res.statusCode < 400) {
      final loc = res.headers.value('location');
      if (loc != null && loc.isNotEmpty) return loc;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<SharedTrip?> _parseApiOneShape(Uri uri, GeocodeFn geocode) async {
  final q = uri.queryParameters;
  final originRaw = q['origin'] ?? q['saddr'];
  final destRaw = q['destination'] ?? q['daddr'];
  if (originRaw == null || destRaw == null) return null;
  if (originRaw.isEmpty || destRaw.isEmpty) return null;

  final origin = await _resolveEntry(originRaw, geocode);
  final dest = await _resolveEntry(destRaw, geocode);
  if (origin == null || dest == null) return null;

  final waypoints = <LatLon>[];
  final waypointNames = <String?>[];
  final wpRaw = q['waypoints'];
  if (wpRaw != null && wpRaw.isNotEmpty) {
    for (final entry in wpRaw.split('|')) {
      if (entry.trim().isEmpty) continue;
      final resolved = await _resolveEntry(entry, geocode);
      if (resolved != null) {
        waypoints.add(resolved.coord);
        waypointNames.add(resolved.name);
      }
    }
  }

  return SharedTrip(
    origin: origin.coord,
    destination: dest.coord,
    departureAt: DateTime.now(),
    originName: origin.name,
    destinationName: dest.name,
    waypoints: waypoints,
    waypointNames: waypointNames,
  );
}

Future<SharedTrip?> _parsePathShape(Uri uri, GeocodeFn geocode) async {
  // Path is `/maps/dir/A/B/C[/@lat,lon,z]` — split, find the `dir`
  // segment, everything after (up to a `@…` position segment or the
  // `data=…` blob) is a stop.
  final segments = uri.pathSegments;
  final dirIdx = segments.indexOf('dir');
  if (dirIdx < 0 || dirIdx == segments.length - 1) return null;

  final stops = <String>[];
  for (var i = dirIdx + 1; i < segments.length; i++) {
    final s = segments[i];
    if (s.startsWith('@')) break; // camera position marker
    if (s.startsWith('data=')) break; // encoded protobuf blob
    if (s.isEmpty) continue;
    stops.add(Uri.decodeComponent(s));
  }

  if (stops.length < 2) return null;

  final resolved = <_Resolved>[];
  for (final s in stops) {
    final r = await _resolveEntry(s, geocode);
    if (r != null) resolved.add(r);
  }
  if (resolved.length < 2) return null;

  final origin = resolved.first;
  final dest = resolved.last;
  final wps = resolved.sublist(1, resolved.length - 1);

  return SharedTrip(
    origin: origin.coord,
    destination: dest.coord,
    departureAt: DateTime.now(),
    originName: origin.name,
    destinationName: dest.name,
    waypoints: [for (final w in wps) w.coord],
    waypointNames: [for (final w in wps) w.name],
  );
}

/// Resolve a single URL entry into (coord, name). Order of checks:
///   1. "lat,lon" — cheapest, no network.
///   2. "place_id:XYZ" — Google's opaque place ID; we can't dereference
///      it without the paid Places API, so drop.
///   3. Anything else — treat as a free-form name and geocode it.
Future<_Resolved?> _resolveEntry(String raw, GeocodeFn geocode) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final coord = _tryParseCoord(trimmed);
  if (coord != null) return _Resolved(coord: coord, name: null);

  if (trimmed.startsWith('place_id:')) return null;

  try {
    final results = await geocode(trimmed);
    if (results.isEmpty) return null;
    final first = results.first;
    return _Resolved(coord: first.coordinate, name: first.displayName);
  } catch (_) {
    return null;
  }
}

LatLon? _tryParseCoord(String raw) {
  final parts = raw.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lon = double.tryParse(parts[1].trim());
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return LatLon(lat: lat, lon: lon);
}

class _Resolved {
  const _Resolved({required this.coord, required this.name});
  final LatLon coord;
  final String? name;
}

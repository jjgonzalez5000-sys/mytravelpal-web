import 'dart:developer' as developer;
import 'dart:io';

import '../api/models.dart';
import 'trip_sharing.dart';

/// Signature for a place resolver — used when a Maps URL contains a
/// human-readable place name instead of coordinates. Returns the
/// first geocode match, or null on failure.
typedef GeocodeFn = Future<List<GeocodeResult>> Function(String query);

/// Failure buckets surfaced by [parseGoogleMapsUrl] so the UI can pick
/// a targeted error message instead of a single "not recognised".
enum MapsUrlParseError {
  /// String was empty, unparseable, or missing a scheme.
  malformedUrl,

  /// Recognised as a shortlink but the redirect chain never resolved
  /// (network failure, timeout, unexpected consent page, etc).
  shortlinkUnresolved,

  /// URL is not a Google Maps directions URL we know how to read.
  unknownFormat,

  /// Format matched, but every stop we tried to resolve failed to
  /// geocode (typically a rate limit or offline).
  geocodeFailed,
}

/// Result of a parse attempt. Exactly one of [trip] / [error] is set.
class MapsUrlParseResult {
  const MapsUrlParseResult._({this.trip, this.error});

  factory MapsUrlParseResult.ok(SharedTrip trip) =>
      MapsUrlParseResult._(trip: trip);
  factory MapsUrlParseResult.fail(MapsUrlParseError error) =>
      MapsUrlParseResult._(error: error);

  final SharedTrip? trip;
  final MapsUrlParseError? error;
}

const _logName = 'mtp.mapsUrlParser';
void _log(String msg) => developer.log(msg, name: _logName);

/// Parse a Google Maps directions URL into a [SharedTrip].
///
/// Handles three shapes:
///   1. `google.com/maps/dir/?api=1&origin=…&destination=…&waypoints=…|…`
///      (the "api=1" contract Google publishes — cleanest, no scraping).
///   2. `google.com/maps/dir/A/B/C/@lat,lon,zoom` (path form; each
///      segment is either `lat,lon` or a URL-encoded place name).
///   3. `maps.app.goo.gl/*`, `goo.gl/maps/*` — short-links. We follow
///      redirects manually (up to 5 hops) until we land on a long URL,
///      then recurse.
///
/// Names that aren't coordinates are resolved via [geocode]. If a name
/// fails to geocode we keep the position (origin / destination cannot
/// drop — the trip aborts if either fails), waypoints that don't
/// resolve are dropped rather than aborting the whole import.
///
/// Departure time is set to "now" — Google's URLs don't carry a
/// desired departure the way MyTravelPal does. The user can edit it
/// on the plan form.
///
/// Legacy return contract: `null` on any failure. Prefer
/// [parseGoogleMapsUrlDetailed] to distinguish failure types.
Future<SharedTrip?> parseGoogleMapsUrl(
  String rawUrl, {
  required GeocodeFn geocode,
  int redirectDepth = 0,
}) async {
  final res = await parseGoogleMapsUrlDetailed(
    rawUrl,
    geocode: geocode,
    redirectDepth: redirectDepth,
  );
  return res.trip;
}

/// Same as [parseGoogleMapsUrl] but surfaces a typed error on failure
/// so the caller can render a specific message.
Future<MapsUrlParseResult> parseGoogleMapsUrlDetailed(
  String rawUrl, {
  required GeocodeFn geocode,
  int redirectDepth = 0,
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    _log('empty input');
    return MapsUrlParseResult.fail(MapsUrlParseError.malformedUrl);
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    _log('unparseable URI: $trimmed');
    return MapsUrlParseResult.fail(MapsUrlParseError.malformedUrl);
  }

  final host = uri.host.toLowerCase();
  _log('parsing host=$host depth=$redirectDepth');

  // Shortlink expansion — follow the redirect chain and recurse into
  // the parser with the final URL.
  if (_isShortlinkHost(host) && redirectDepth < 5) {
    final expanded = await _expandShortlink(uri);
    if (expanded == null) {
      _log('shortlink did not expand: $uri');
      return MapsUrlParseResult.fail(MapsUrlParseError.shortlinkUnresolved);
    }
    _log('shortlink expanded to: $expanded');
    return parseGoogleMapsUrlDetailed(
      expanded,
      geocode: geocode,
      redirectDepth: redirectDepth + 1,
    );
  }

  // EU consent gateway sometimes wraps the real URL:
  //   https://consent.google.com/m?continue=<real-url>&...
  if (host == 'consent.google.com') {
    final cont = uri.queryParameters['continue'];
    if (cont != null && cont.isNotEmpty && redirectDepth < 5) {
      _log('consent gateway → continue=$cont');
      return parseGoogleMapsUrlDetailed(
        cont,
        geocode: geocode,
        redirectDepth: redirectDepth + 1,
      );
    }
    return MapsUrlParseResult.fail(MapsUrlParseError.shortlinkUnresolved);
  }

  if (!host.contains('google.') || !uri.path.contains('/maps')) {
    _log('not a google maps URL (host=$host, path=${uri.path})');
    return MapsUrlParseResult.fail(MapsUrlParseError.unknownFormat);
  }

  // Try the api=1 query params first — they're the contract Google
  // publishes and the most reliable to parse.
  final apiOne = await _parseApiOneShape(uri, geocode);
  if (apiOne != null) return apiOne;

  // Fall back to path form: /maps/dir/A/B/C[/@lat,lon,zoom]
  return _parsePathShape(uri, geocode);
}

bool _isShortlinkHost(String host) =>
    host == 'maps.app.goo.gl' || host == 'goo.gl' || host == 'g.co';

/// Follow the redirect chain from a shortlink up to 5 hops. Stops as
/// soon as we land on a non-3xx URL that is no longer a shortlink, or
/// gives up if the chain loops / times out.
Future<String?> _expandShortlink(Uri startUri) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    // A UA header helps: bare requests sometimes trip the consent flow
    // more aggressively than a "browser-shaped" client.
    client.userAgent = 'MyTravelPal/1.0 (+https://mytravelpal-api.fly.dev)';

    var current = startUri;
    for (var i = 0; i < 5; i++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      // Ask for a light body — Google shortlinks respect this and
      // return 302 immediately.
      req.headers.set('accept', 'text/html,*/*;q=0.8');
      final res = await req.close();
      await res.drain<void>();

      _log('hop=$i status=${res.statusCode} url=$current');

      if (res.statusCode >= 300 && res.statusCode < 400) {
        final loc = res.headers.value('location') ??
            res.headers.value('Location');
        if (loc == null || loc.isEmpty) return null;
        final next = Uri.tryParse(loc);
        if (next == null) return null;
        // Some servers return relative locations — resolve against the
        // current URL.
        current = next.hasScheme ? next : current.resolveUri(next);
        // If we've landed somewhere that is neither a shortlink nor
        // consent, hand off — the caller re-enters the top-level parser
        // which does its own consent unwrap.
        if (!_isShortlinkHost(current.host.toLowerCase())) {
          return current.toString();
        }
        continue;
      }
      // 2xx / anything else — return whatever we last had.
      return current.toString();
    }
    _log('shortlink chain exhausted');
    return current.toString();
  } catch (e) {
    _log('shortlink expand error: $e');
    return null;
  } finally {
    client?.close(force: true);
  }
}

Future<MapsUrlParseResult?> _parseApiOneShape(
  Uri uri,
  GeocodeFn geocode,
) async {
  final q = uri.queryParameters;
  final originRaw = q['origin'] ?? q['saddr'];
  final destRaw = q['destination'] ?? q['daddr'];
  if (originRaw == null || destRaw == null) return null;
  if (originRaw.isEmpty || destRaw.isEmpty) return null;

  _log('api=1 shape origin="$originRaw" dest="$destRaw" '
      'waypoints="${q['waypoints'] ?? ''}"');

  final origin = await _resolveEntry(originRaw, geocode);
  final dest = await _resolveEntry(destRaw, geocode);
  if (origin == null || dest == null) {
    _log('api=1: origin/dest geocode failed');
    return MapsUrlParseResult.fail(MapsUrlParseError.geocodeFailed);
  }

  final waypoints = <LatLon>[];
  final waypointNames = <String?>[];
  final wpRaw = q['waypoints'];
  if (wpRaw != null && wpRaw.isNotEmpty) {
    // Google separates multiple waypoints with `|` (already decoded
    // by uri.queryParameters — it handles %7C for us).
    for (final entry in wpRaw.split('|')) {
      if (entry.trim().isEmpty) continue;
      final resolved = await _resolveEntry(entry, geocode);
      if (resolved != null) {
        waypoints.add(resolved.coord);
        waypointNames.add(resolved.name);
      } else {
        _log('api=1: dropped waypoint "$entry" (geocode failed)');
      }
    }
  }

  _log('api=1 parsed: origin=${origin.name} dest=${dest.name} '
      'waypoints=${waypointNames.length}');

  return MapsUrlParseResult.ok(SharedTrip(
    origin: origin.coord,
    destination: dest.coord,
    departureAt: DateTime.now(),
    originName: origin.name,
    destinationName: dest.name,
    waypoints: waypoints,
    waypointNames: waypointNames,
  ));
}

Future<MapsUrlParseResult> _parsePathShape(
  Uri uri,
  GeocodeFn geocode,
) async {
  // Path is `/maps/dir/A/B/C[/@lat,lon,z]` — split, find the `dir`
  // segment, everything after (up to a `@…` position segment or the
  // `data=…` blob) is a stop. `uri.pathSegments` already decodes
  // percent-encoding, so do NOT decode again (double-decode corrupts
  // segments that legitimately contain a `%`).
  final segments = uri.pathSegments;
  final dirIdx = segments.indexOf('dir');
  if (dirIdx < 0 || dirIdx == segments.length - 1) {
    _log('path shape: no /dir/ segment');
    return MapsUrlParseResult.fail(MapsUrlParseError.unknownFormat);
  }

  final stops = <String>[];
  for (var i = dirIdx + 1; i < segments.length; i++) {
    final s = segments[i];
    if (s.startsWith('@')) break; // camera position marker
    if (s.startsWith('data=')) break; // encoded protobuf blob
    if (s.isEmpty) continue;
    stops.add(s);
  }

  _log('path shape: ${stops.length} stops raw=$stops');

  if (stops.length < 2) {
    return MapsUrlParseResult.fail(MapsUrlParseError.unknownFormat);
  }

  // Preserve position: resolve each in order, and only drop
  // intermediate waypoints when they fail — never let a failed origin
  // or destination silently become a different stop.
  final resolvedByIdx = <int, _Resolved>{};
  for (var i = 0; i < stops.length; i++) {
    final r = await _resolveEntry(stops[i], geocode);
    if (r != null) resolvedByIdx[i] = r;
  }

  final origin = resolvedByIdx[0];
  final dest = resolvedByIdx[stops.length - 1];
  if (origin == null || dest == null) {
    _log('path shape: origin(${origin != null}) or '
        'dest(${dest != null}) failed geocode');
    return MapsUrlParseResult.fail(MapsUrlParseError.geocodeFailed);
  }

  final waypoints = <LatLon>[];
  final waypointNames = <String?>[];
  for (var i = 1; i < stops.length - 1; i++) {
    final r = resolvedByIdx[i];
    if (r == null) {
      _log('path shape: dropped waypoint index $i ("${stops[i]}")');
      continue;
    }
    waypoints.add(r.coord);
    waypointNames.add(r.name);
  }

  _log('path shape parsed: origin=${origin.name} dest=${dest.name} '
      'waypoints=${waypoints.length}');

  return MapsUrlParseResult.ok(SharedTrip(
    origin: origin.coord,
    destination: dest.coord,
    departureAt: DateTime.now(),
    originName: origin.name,
    destinationName: dest.name,
    waypoints: waypoints,
    waypointNames: waypointNames,
  ));
}

/// Resolve a single URL entry into (coord, name). Order of checks:
///   1. "lat,lon" — cheapest, no network.
///   2. "place_id:XYZ" — Google's opaque place ID; we can't dereference
///      it without the paid Places API, so drop.
///   3. Anything else — treat as a free-form name and geocode it. `+`
///      is Google's classic separator for spaces in query params, so
///      we normalise it before handing off.
Future<_Resolved?> _resolveEntry(String raw, GeocodeFn geocode) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final coord = _tryParseCoord(trimmed);
  if (coord != null) return _Resolved(coord: coord, name: null);

  if (trimmed.startsWith('place_id:')) {
    _log('drop: place_id token not resolvable without paid API');
    return null;
  }

  // Normalise Google's `+` (space) convention and any lingering
  // percent-encoding — pathSegments already decodes but query params
  // handed in raw may still be encoded when they arrive via `saddr`.
  var query = trimmed.replaceAll('+', ' ');
  try {
    query = Uri.decodeFull(query);
  } catch (_) {
    // If the string wasn't valid percent-encoding, use it as-is.
  }

  try {
    final results = await geocode(query);
    if (results.isEmpty) {
      _log('geocode empty for "$query"');
      return null;
    }
    final first = results.first;
    return _Resolved(coord: first.coordinate, name: first.displayName);
  } catch (e) {
    _log('geocode threw for "$query": $e');
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

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';

/// URL scheme used by outgoing shares. Registered as an Android intent
/// filter in `android/app/src/main/AndroidManifest.xml` and, when we
/// generate the iOS platform folder, an `Info.plist` CFBundleURLTypes
/// entry. The web build falls back to reading `?trip=…` on the origin.
const shareUrlScheme = 'mytravelpal';
const shareUrlHost = 'trip';

/// Build a shareable link that reconstructs the plan on the recipient's
/// device. Stateless — every parameter is in the URL.
String encodeTripLink({
  required LatLon origin,
  required LatLon destination,
  required DateTime departureAt,
  String? originName,
  String? destinationName,
}) {
  final params = <String, String>{
    'o': '${origin.lat.toStringAsFixed(5)},${origin.lon.toStringAsFixed(5)}',
    'd':
        '${destination.lat.toStringAsFixed(5)},${destination.lon.toStringAsFixed(5)}',
    't': departureAt.toUtc().toIso8601String(),
    if (originName != null && originName.isNotEmpty) 'on': originName,
    if (destinationName != null && destinationName.isNotEmpty)
      'dn': destinationName,
  };
  return Uri(
    scheme: shareUrlScheme,
    host: shareUrlHost,
    queryParameters: params,
  ).toString();
}

/// Parse an inbound share link into a `SharedTrip`, or return null if
/// the URL doesn't look like one of ours.
SharedTrip? decodeTripLink(Uri uri) {
  if (uri.scheme != shareUrlScheme || uri.host != shareUrlHost) return null;
  final q = uri.queryParameters;
  final o = _parseLatLon(q['o']);
  final d = _parseLatLon(q['d']);
  final t = _parseIso(q['t']);
  if (o == null || d == null || t == null) return null;
  return SharedTrip(
    origin: o,
    destination: d,
    departureAt: t,
    originName: q['on'],
    destinationName: q['dn'],
  );
}

LatLon? _parseLatLon(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lon = double.tryParse(parts[1]);
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
  return LatLon(lat: lat, lon: lon);
}

DateTime? _parseIso(String? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

class SharedTrip {
  const SharedTrip({
    required this.origin,
    required this.destination,
    required this.departureAt,
    this.originName,
    this.destinationName,
  });

  final LatLon origin;
  final LatLon destination;
  final DateTime departureAt;
  final String? originName;
  final String? destinationName;
}

/// Turn a trip into a short, human-readable share message. No deep link
/// yet — a future backend endpoint could serve a shareable URL that
/// reopens the plan in-app; for now we ship a text summary that reads
/// well in WhatsApp / iMessage / email.
String composeTripShare({
  required String originName,
  required String destinationName,
  required RouteInfo route,
  TimeWindow? recommended,
  TollAlternative? tollAlt,
}) {
  final dateFmt = DateFormat('EEE d MMM · HH:mm');
  final buf = StringBuffer('MyTravelPal — road trip plan\n\n');
  buf.writeln('📍 $originName → $destinationName');
  buf.writeln(
    '🛣️  ${route.distanceKm.toStringAsFixed(0)} km · '
    '${(route.freeFlowMinutes / 60).toStringAsFixed(1)} h free flow · '
    'tolls ${route.tollCostEur.toStringAsFixed(0)} €',
  );
  if (route.countriesCrossed.isNotEmpty) {
    buf.writeln(
      '🌍 ${route.countriesCrossed.map((c) => c.displayName).join(' · ')}',
    );
  }
  if (recommended != null) {
    buf.writeln();
    buf.writeln(
      '⏰ Best time to leave: ${dateFmt.format(recommended.departureAt)} '
      '(${recommended.estimatedMinutes.toStringAsFixed(0)} min total)',
    );
  }
  if (tollAlt != null && tollAlt.worthIt) {
    buf.writeln();
    buf.writeln(
      '💰 Toll-free alt: save €${tollAlt.savingsEur.toStringAsFixed(0)} '
      'for +${tollAlt.timePenaltyMinutes.toStringAsFixed(0)} min',
    );
  }
  return buf.toString();
}

Future<void> shareTrip({
  required String originName,
  required String destinationName,
  required RouteInfo route,
  required LatLon origin,
  required LatLon destination,
  required DateTime departureAt,
  TimeWindow? recommended,
  TollAlternative? tollAlt,
}) async {
  final text = composeTripShare(
    originName: originName,
    destinationName: destinationName,
    route: route,
    recommended: recommended,
    tollAlt: tollAlt,
  );
  final link = encodeTripLink(
    origin: origin,
    destination: destination,
    departureAt: departureAt,
    originName: originName,
    destinationName: destinationName,
  );
  await Share.share(
    '$text\n\nOpen in MyTravelPal:\n$link',
    subject: '$originName → $destinationName',
  );
}

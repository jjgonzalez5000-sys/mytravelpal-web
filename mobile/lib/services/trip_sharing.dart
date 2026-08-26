import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';

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
  required AppLocalizations l,
  required String originName,
  required String destinationName,
  required RouteInfo route,
  TimeWindow? recommended,
  TollAlternative? tollAlt,
  List<Hotel> hotels = const [],
  List<Restaurant> restaurants = const [],
  FuelArbitrage? fuelArbitrage,
  String? localeName,
}) {
  final dateFmt = DateFormat('EEE d MMM · HH:mm', localeName);
  final buf = StringBuffer('${l.shareTitle}\n\n');
  buf.writeln('📍 $originName → $destinationName');
  buf.writeln('🛣️  ${l.shareRouteLine(
    route.distanceKm.toStringAsFixed(0),
    (route.freeFlowMinutes / 60).toStringAsFixed(1),
    route.tollCostEur.toStringAsFixed(0),
  )}');
  if (route.countriesCrossed.isNotEmpty) {
    buf.writeln(
      '🌍 ${route.countriesCrossed.map((c) => c.displayName).join(' · ')}',
    );
  }
  if (recommended != null) {
    buf.writeln();
    buf.writeln('⏰ ${l.shareBestTime(
      dateFmt.format(recommended.departureAt),
      recommended.estimatedMinutes.toStringAsFixed(0),
    )}');
  }
  if (tollAlt != null && tollAlt.worthIt) {
    buf.writeln();
    buf.writeln('💰 ${l.shareTollFreeAlt(
      tollAlt.savingsEur.toStringAsFixed(0),
      tollAlt.timePenaltyMinutes.toStringAsFixed(0),
    )}');
  }
  if (fuelArbitrage != null) {
    buf.writeln();
    buf.writeln('⛽ ${l.shareRefuelHint(
      fuelArbitrage.cheaperCountry.displayName,
      fuelArbitrage.cheaperMedianEurPerL.toStringAsFixed(2),
      fuelArbitrage.pricierCountry.displayName,
      fuelArbitrage.estimatedTankSavingEur.toStringAsFixed(0),
    )}');
  }
  if (hotels.isNotEmpty) {
    buf.writeln();
    buf.writeln('🏨 ${l.shareHotelsHeader}');
    for (final h in hotels.take(3)) {
      buf.writeln('  · ${l.shareHotelLine(
        h.name,
        h.priceEurPerNight.toStringAsFixed(0),
        h.distanceFromRouteKm.toStringAsFixed(1),
      )}');
    }
  }
  if (restaurants.isNotEmpty) {
    buf.writeln();
    buf.writeln('🍽️ ${l.shareRestaurantsHeader}');
    for (final r in restaurants.take(3)) {
      buf.writeln('  · ${l.shareRestaurantLine(
        r.name,
        r.priceEurPerMeal.toStringAsFixed(0),
        r.distanceFromRouteKm.toStringAsFixed(1),
      )}');
    }
  }
  return buf.toString();
}

Future<void> shareTrip({
  required AppLocalizations l,
  required String originName,
  required String destinationName,
  required RouteInfo route,
  required LatLon origin,
  required LatLon destination,
  required DateTime departureAt,
  TimeWindow? recommended,
  TollAlternative? tollAlt,
  List<Hotel> hotels = const [],
  List<Restaurant> restaurants = const [],
  FuelArbitrage? fuelArbitrage,
  String? localeName,
}) async {
  final text = composeTripShare(
    l: l,
    originName: originName,
    destinationName: destinationName,
    route: route,
    recommended: recommended,
    tollAlt: tollAlt,
    hotels: hotels,
    restaurants: restaurants,
    fuelArbitrage: fuelArbitrage,
    localeName: localeName,
  );
  final link = encodeTripLink(
    origin: origin,
    destination: destination,
    departureAt: departureAt,
    originName: originName,
    destinationName: destinationName,
  );
  await Share.share(
    '$text\n\n${l.shareOpenInApp}\n$link',
    subject: '$originName → $destinationName',
  );
}

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Single place that turns a POI into a Google Maps link.
///
/// Why not `geo:` or `?q=lat,lon`: both drop a bare pin, and OSM/Geoapify
/// coordinates sit 10-60 m from Google's own point for the same business,
/// so Maps highlights whichever neighbour is nearest. The documented
/// search URL with `query_place_id` opens the exact place card instead.
/// Fallback order: place id, Google URL, name + address text search (only
/// with an address or city to anchor it), pin.
class MapsPlace {
  const MapsPlace({
    required this.name,
    required this.coordinate,
    this.googlePlaceId,
    this.googleMapsUrl,
    this.address,
    this.city,
    this.pinOnly = false,
  });

  final String name;
  final LatLon coordinate;
  final String? googlePlaceId;
  final String? googleMapsUrl;
  final String? address;
  final String? city;

  /// Parking and the like: a pin at the coordinate, never a name search.
  final bool pinOnly;

  MapsPlace copyWith({
    String? googlePlaceId,
    String? googleMapsUrl,
    String? address,
  }) =>
      MapsPlace(
        name: name,
        coordinate: coordinate,
        googlePlaceId: googlePlaceId ?? this.googlePlaceId,
        googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
        address: address ?? this.address,
        city: city,
        pinOnly: pinOnly,
      );
}

enum MapsPlaceMode { placeId, url, text, pin }

typedef PlaceResolver = Future<ResolvedPlace?> Function({
  required String name,
  required double lat,
  required double lon,
  String? address,
});

typedef UrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

String? _nonEmpty(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Empty, a dash or the backend's "km N" placeholder: not a searchable name.
bool isSyntheticPlaceName(String name) {
  final t = name.trim();
  return t.isEmpty ||
      t == '—' ||
      RegExp(r'^km\s+\d+', caseSensitive: false).hasMatch(t);
}

MapsPlace mapsPlaceFromAttributes({
  required String name,
  required LatLon coordinate,
  required Map<String, String> attributes,
  bool pinOnly = false,
}) {
  String? a(String k) => _nonEmpty(attributes[k]);
  final street = a('addr:street');
  final number = a('addr:housenumber');
  final osmCity = a('addr:city');
  final osmAddress = street == null
      ? null
      : [
          number == null ? street : '$street $number',
          if (osmCity != null) osmCity,
        ].join(', ');
  return MapsPlace(
    name: name,
    coordinate: coordinate,
    googlePlaceId: a('google_place_id'),
    googleMapsUrl: a('google_maps_url'),
    address: a('google_address') ??
        a('here_address') ??
        a('address_line1') ??
        osmAddress,
    city: a('here_city') ?? osmCity ?? a('city'),
    pinOnly: pinOnly,
  );
}

Uri? _validGoogleUrl(String? raw) {
  final v = _nonEmpty(raw);
  if (v == null) return null;
  final u = Uri.tryParse(v);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  return u.host.isEmpty ? null : u;
}

MapsPlaceMode mapsPlaceMode(MapsPlace p) {
  if (p.pinOnly) return MapsPlaceMode.pin;
  if (_nonEmpty(p.googlePlaceId) != null) return MapsPlaceMode.placeId;
  if (_validGoogleUrl(p.googleMapsUrl) != null) return MapsPlaceMode.url;
  // A bare name could match a same-named business in another city.
  final hasContext = _nonEmpty(p.address) != null || _nonEmpty(p.city) != null;
  if (!isSyntheticPlaceName(p.name) && hasContext) return MapsPlaceMode.text;
  return MapsPlaceMode.pin;
}

Uri buildPlaceMapsUri(MapsPlace p) {
  Uri search(String query, [String? placeId]) =>
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
        if (placeId != null) 'query_place_id': placeId,
      });

  final name = p.name.replaceAll(RegExp(r'\s+'), ' ').trim();
  final text = [
    if (!isSyntheticPlaceName(name)) name,
    _nonEmpty(p.address) ?? _nonEmpty(p.city),
  ].whereType<String>().join(', ');
  switch (mapsPlaceMode(p)) {
    case MapsPlaceMode.placeId:
      return search(
        text.isEmpty ? '${p.coordinate.lat},${p.coordinate.lon}' : text,
        _nonEmpty(p.googlePlaceId),
      );
    case MapsPlaceMode.url:
      return _validGoogleUrl(p.googleMapsUrl)!;
    case MapsPlaceMode.text:
      // Coordinates in the text would be parsed as a pin by Maps.
      return search(text);
    case MapsPlaceMode.pin:
      return search('${p.coordinate.lat},${p.coordinate.lon}');
  }
}

String _memoKey(MapsPlace p) =>
    '${p.name.trim().toLowerCase()}|${p.coordinate.lat.toStringAsFixed(4)}'
    '|${p.coordinate.lon.toStringAsFixed(4)}';

final Map<String, ResolvedPlace?> _resolved = {};

@visibleForTesting
void clearMapsPlaceMemo() => _resolved.clear();

/// Asks the backend for the Google place id when the POI has none. At most
/// one request per place per app session; failures fall through silently.
Future<MapsPlace> resolveMapsPlace(
  MapsPlace p, {
  PlaceResolver? resolver,
}) async {
  if (resolver == null ||
      p.pinOnly ||
      isSyntheticPlaceName(p.name) ||
      _nonEmpty(p.googlePlaceId) != null ||
      _validGoogleUrl(p.googleMapsUrl) != null) {
    return p;
  }
  final key = _memoKey(p);
  if (!_resolved.containsKey(key)) {
    ResolvedPlace? r;
    try {
      r = await resolver(
        name: p.name.trim(),
        lat: p.coordinate.lat,
        lon: p.coordinate.lon,
        address: _nonEmpty(p.address) ?? _nonEmpty(p.city),
      );
    } catch (_) {
      r = null;
    }
    _resolved[key] = r;
  }
  final r = _resolved[key];
  if (r == null) return p;
  return p.copyWith(
    googlePlaceId: r.googlePlaceId,
    googleMapsUrl: r.googleMapsUrl,
    address: r.address,
  );
}

PlaceResolver? _contextResolver(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(apiClientProvider)
        .resolvePlace;
  } catch (_) {
    return null;
  }
}

/// Opens [place] in Google Maps (app first, browser as fallback).
Future<bool> openPlaceInMaps(
  BuildContext context,
  MapsPlace place, {
  PlaceResolver? resolver,
  UrlLauncher? launcher,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final launch = launcher ??
      (Uri u, LaunchMode m) => launchUrl(u, mode: m);
  final resolved = await resolveMapsPlace(
    place,
    resolver: resolver ?? _contextResolver(context),
  );
  final uri = buildPlaceMapsUri(resolved);
  developer.log(
    '${mapsPlaceMode(resolved).name} $uri',
    name: 'mtp.mapsPlace',
  );
  var ok = false;
  for (final mode in const [
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
  ]) {
    try {
      ok = await launch(uri, mode);
    } catch (_) {
      ok = false;
    }
    if (ok) return true;
  }
  messenger?.showSnackBar(
    SnackBar(content: Text(l.poiOpenError(uri.toString()))),
  );
  return false;
}

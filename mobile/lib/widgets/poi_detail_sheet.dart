import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import 'osm_attribution.dart';

/// Kind of POI the sheet is describing. Governs which external CTAs
/// appear (a hotel gets Booking + Google Maps; a restaurant gets
/// TheFork + Google Maps + Google reviews; fuel gets Google Maps only).
enum PoiKind { hotel, restaurant, fuel }

/// Reusable detail sheet for hotels, restaurants and fuel stations.
///
/// Shows: header (icon + name + country + price/band), mini-map with
/// the route + POI marker, chip cloud of curated OSM attributes,
/// external CTA row that opens Google Maps / TheFork / Booking with
/// the place pre-searched (no paid APIs yet — we defer ratings to
/// links out).
Future<void> showPoiDetailSheet(
  BuildContext context, {
  required PoiKind kind,
  required String name,
  required String subtitle,
  required LatLon poi,
  required LatLon origin,
  required LatLon destination,
  required List<LatLon> routeGeometry,
  required Map<String, String> attributes,
  required IconData icon,
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PoiDetailSheet(
      kind: kind, name: name, subtitle: subtitle,
      poi: poi, origin: origin, destination: destination,
      routeGeometry: routeGeometry, attributes: attributes,
      icon: icon, accent: accent,
    ),
  );
}

class _PoiDetailSheet extends StatelessWidget {
  const _PoiDetailSheet({
    required this.kind, required this.name, required this.subtitle,
    required this.poi, required this.origin, required this.destination,
    required this.routeGeometry, required this.attributes,
    required this.icon, required this.accent,
  });

  final PoiKind kind;
  final String name;
  final String subtitle;
  final LatLon poi;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;
  final Map<String, String> attributes;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final poiPoint = LatLng(poi.lat, poi.lon);
    final points = _routePoints();
    final bounds = _fitBounds(poiPoint, points);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: t.titleLarge),
                        Text(
                          subtitle,
                          style: t.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(28),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mytravelpal.app',
                        maxZoom: 19,
                      ),
                      if (points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 3,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: poiPoint,
                            width: 40, height: 40,
                            alignment: Alignment.topCenter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white, width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const OsmAttribution(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (attributes.isNotEmpty) ...[
                _AttributeGrid(attributes: attributes),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'No extra info from OSM for this place.',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],
              _ExternalCtaRow(kind: kind, name: name, poi: poi, attributes: attributes),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _routePoints() {
    if (routeGeometry.length >= 2) {
      return routeGeometry.map((c) => LatLng(c.lat, c.lon)).toList();
    }
    return [
      LatLng(origin.lat, origin.lon),
      LatLng(destination.lat, destination.lon),
    ];
  }

  LatLngBounds _fitBounds(LatLng poi, List<LatLng> route) {
    final anchors = <LatLng>{poi};
    if (route.isNotEmpty) {
      var nearest = 0;
      double best =
          (route[0].latitude - poi.latitude).abs() +
              (route[0].longitude - poi.longitude).abs();
      for (var i = 1; i < route.length; i++) {
        final d =
            (route[i].latitude - poi.latitude).abs() +
                (route[i].longitude - poi.longitude).abs();
        if (d < best) { best = d; nearest = i; }
      }
      final lo = (nearest - 3).clamp(0, route.length - 1);
      final hi = (nearest + 3).clamp(0, route.length - 1);
      anchors.addAll(route.sublist(lo, hi + 1));
    }
    return LatLngBounds.fromPoints(anchors.toList());
  }
}

/// Renders each attribute as a chip with a matching icon where we know
/// one (stars → star, wifi → wifi, phone → phone, …). Unknown keys get
/// a bullet chip so nothing is dropped silently.
class _AttributeGrid extends StatelessWidget {
  const _AttributeGrid({required this.attributes});
  final Map<String, String> attributes;

  static const _icons = <String, IconData>{
    'stars': Icons.star_outline,
    'phone': Icons.phone_outlined,
    'website': Icons.language,
    'opening_hours': Icons.schedule,
    'wheelchair': Icons.accessible,
    'wifi': Icons.wifi,
    'internet_access': Icons.wifi,
    'air_conditioning': Icons.ac_unit,
    'breakfast': Icons.free_breakfast,
    'brand': Icons.storefront,
    'operator': Icons.badge_outlined,
    'smoking': Icons.smoking_rooms,
    'cuisine': Icons.restaurant_menu,
    'outdoor_seating': Icons.deck,
    'takeaway': Icons.takeout_dining,
    'delivery': Icons.delivery_dining,
    'dog': Icons.pets,
    'capacity': Icons.people_outline,
    'reservation': Icons.event_seat,
    'payment:contactless': Icons.contactless,
    'contactless': Icons.contactless,
    'payment:credit_cards': Icons.credit_card,
    'credit_cards': Icons.credit_card,
    'fuel:diesel': Icons.local_gas_station,
    'diesel': Icons.local_gas_station,
    'fuel:octane_95': Icons.local_gas_station,
    'octane_95': Icons.local_gas_station,
    'fuel:octane_98': Icons.local_gas_station,
    'octane_98': Icons.local_gas_station,
    'fuel:lpg': Icons.propane,
    'lpg': Icons.propane,
    'fuel:e10': Icons.eco,
    'e10': Icons.eco,
    'fuel:e85': Icons.eco,
    'e85': Icons.eco,
    'fuel:HGV_diesel': Icons.local_shipping,
    'HGV_diesel': Icons.local_shipping,
    'car_wash': Icons.local_car_wash,
    'shop': Icons.storefront,
    'self_service': Icons.self_improvement,
    'toilets': Icons.wc,
  };

  String _prettifyValue(String key, String value) {
    // `yes` on a boolean-ish tag is redundant — show a check.
    if (value == 'yes' || value == 'true') return '✓';
    if (value == 'no' || value == 'false') return '✗';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in attributes.entries)
          _AttrChip(
            icon: _icons[entry.key] ?? Icons.info_outline,
            label: entry.key.replaceAll('_', ' '),
            value: _prettifyValue(entry.key, entry.value),
            scheme: scheme,
          ),
      ],
    );
  }
}

class _AttrChip extends StatelessWidget {
  const _AttrChip({
    required this.icon, required this.label, required this.value,
    required this.scheme,
  });
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final short = value.length > 30 ? '${value.substring(0, 27)}…' : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label: $short',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Row of external-service CTAs. Ratings from Google/TheFork/Booking
/// are behind paid APIs; instead we open a search on their platforms
/// pre-filled with the place name + coordinates so the user gets to
/// the real reviews in one tap.
class _ExternalCtaRow extends StatelessWidget {
  const _ExternalCtaRow({
    required this.kind, required this.name, required this.poi,
    required this.attributes,
  });
  final PoiKind kind;
  final String name;
  final LatLon poi;
  final Map<String, String> attributes;

  Future<void> _launch(BuildContext context, Uri uri) async {
    // Two-step launch:
    // 1. `externalApplication` opens Google Maps / TheFork / Booking
    //    apps when installed on the phone (best UX — deep-link into
    //    the native app with search pre-filled).
    // 2. If no dedicated app is registered as handler, fall back to
    //    `platformDefault` which opens the URL in the system
    //    browser (Chrome / whatever default). Without this fallback
    //    users with no Google Maps app see the button do nothing
    //    silently — the SnackBar recovery was a Band-Aid that never
    //    actually shows because the modal sheet gates it.
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fall through — some ROMs throw PlatformException instead
      // of returning false when no handler is registered.
    }
    if (!ok) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  // Android's geo URI drops a *labeled* pin at exact coordinates
  // and Google Maps opens it directly — no text search, no
  // "just the coords" limbo the previous coord-only https link
  // produced. Format: `geo:<lat>,<lon>?q=<lat>,<lon>(<Label>)`.
  // Parens around the label are the standard way to attach a
  // marker title. Fallback for devices without a geo handler
  // uses the https URL scoped by both name AND coord bounds so
  // Maps text-searches near the point, not globally.
  Uri _geoUri() {
    // Trim / normalize whitespace in the label — some Maps
    // builds refuse geo URIs whose label contains newlines.
    final label = Uri.encodeComponent(
      name.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    return Uri.parse(
      'geo:${poi.lat},${poi.lon}?q=${poi.lat},${poi.lon}($label)',
    );
  }

  Uri _googleMapsHttpsFallback() =>
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        // Coordinates in the query text land the pin exactly;
        // the `center`/`zoom` pair tightens the map viewport so
        // when Maps' web UI decides to render a text search
        // panel, results are bounded around the point instead
        // of matching a same-named business elsewhere.
        'query': '${poi.lat},${poi.lon}',
        'center': '${poi.lat},${poi.lon}',
        'zoom': '17',
      });

  Future<void> _openInMaps(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(_geoUri(),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (!context.mounted) return;
      await _launch(context, _googleMapsHttpsFallback());
    }
  }

  Uri _theFork() {
    // TheFork's public site has no stable deep-link that resolves
    // "restaurant name + city" without their API key. The old
    // `/search?cityId=&searchText=<name>` collapsed to the
    // generic Paris results page (their default city fallback).
    // Route through a Google search scoped to thefork.com — the
    // top hit is almost always the exact restaurant page, and
    // for the handful that aren't listed the user at least sees
    // the correct search results instead of Paris restaurants.
    return Uri.https('www.google.com', '/search', {
      'q': '$name site:thefork.com',
    });
  }

  Uri _booking() => Uri.https('www.booking.com', '/searchresults.html', {
        'ss': name,
      });

  Uri _officialWebsite() {
    final w = attributes['website'] ?? attributes['contact:website'] ?? '';
    return w.startsWith('http') ? Uri.parse(w) : Uri.parse('https://$w');
  }

  Uri _tel() {
    final p = attributes['phone'] ?? attributes['contact:phone'] ?? '';
    return Uri.parse('tel:${p.replaceAll(' ', '')}');
  }

  @override
  Widget build(BuildContext context) {
    final hasWebsite = (attributes['website'] ?? attributes['contact:website']) != null;
    final hasPhone = (attributes['phone'] ?? attributes['contact:phone']) != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CtaButton(
          icon: Icons.map_outlined,
          label: 'Google Maps',
          onPressed: () => _openInMaps(context),
        ),
        if (kind == PoiKind.restaurant)
          _CtaButton(
            icon: Icons.restaurant_menu,
            label: 'TheFork',
            onPressed: () => _launch(context, _theFork()),
          ),
        if (kind == PoiKind.hotel)
          _CtaButton(
            icon: Icons.hotel_outlined,
            label: 'Booking',
            onPressed: () => _launch(context, _booking()),
          ),
        if (hasPhone)
          _CtaButton(
            icon: Icons.phone,
            label: 'Call',
            onPressed: () => _launch(context, _tel()),
          ),
        if (hasWebsite)
          _CtaButton(
            icon: Icons.language,
            label: 'Website',
            onPressed: () => _launch(context, _officialWebsite()),
          ),
      ],
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon, required this.label, required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

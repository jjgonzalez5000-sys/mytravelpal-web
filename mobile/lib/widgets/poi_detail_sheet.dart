import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../screens/parking_search_screen.dart';
import 'osm_attribution.dart';

/// Kind of POI the sheet is describing. Governs which external CTAs
/// appear (a hotel gets Booking + Google Maps; a restaurant gets
/// TheFork + Google Maps + Google reviews; fuel gets Google Maps only;
/// rest stops get Google Maps only — the row already exposes the
/// backend's WHY sheet via the (i) icon so no third-party lookup is
/// warranted here).
enum PoiKind { hotel, restaurant, fuel, rest }

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
  bool isAdded = false,
  VoidCallback? onAddToRoute,
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
      isAdded: isAdded,
      onAddToRoute: onAddToRoute,
    ),
  );
}

class _PoiDetailSheet extends StatefulWidget {
  const _PoiDetailSheet({
    required this.kind, required this.name, required this.subtitle,
    required this.poi, required this.origin, required this.destination,
    this.onAddToRoute,
    required this.routeGeometry, required this.attributes,
    required this.icon, required this.accent,
    this.isAdded = false,
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
  final bool isAdded;
  final VoidCallback? onAddToRoute;

  @override
  State<_PoiDetailSheet> createState() => _PoiDetailSheetState();
}

class _PoiDetailSheetState extends State<_PoiDetailSheet> {
  late bool _isAdded;

  @override
  void initState() {
    super.initState();
    _isAdded = widget.isAdded;
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final name = widget.name;
    final subtitle = widget.subtitle;
    final poi = widget.poi;
    final attributes = widget.attributes;
    final icon = widget.icon;
    final accent = widget.accent;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
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
              // Spotlight strip: big-ticket numbers (price / stars /
              // rating). Rendered only when at least one signal is
              // present — an empty attributes map falls through to a
              // subtle "no extra info" line as before.
              _PoiSpotlight(
                kind: kind,
                subtitle: subtitle,
                attributes: attributes,
                accent: accent,
              ),
              // Feature tiles: iconic 3-column grid of amenities
              // (breakfast / wifi / parking / etc.). Empty grid is
              // hidden — nothing rendered when nothing to show.
              const SizedBox(height: 12),
              _FeatureTiles(attributes: attributes, accent: accent),
              // Fallback for POIs with zero attributes at all — the
              // sheet still shows the map + external CTAs.
              if (attributes.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No extra info from OSM for this place.',
                  style: t.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              // Everything not promoted into spotlight or tiles is
              // available in a collapsible "más info" section — kept
              // out of the primary view but not lost.
              _MoreInfoSection(attributes: attributes),
              const SizedBox(height: 16),
              if (widget.onAddToRoute != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => _isAdded = !_isAdded);
                      widget.onAddToRoute!();
                    },
                    icon: Icon(_isAdded
                        ? Icons.remove_circle_outline
                        : Icons.add_location_alt_outlined),
                    label: Text(_isAdded
                        ? l.removeFromRouteTooltip
                        : l.addToRouteLabel),
                    style: _isAdded
                        ? FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onErrorContainer,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _ExternalCtaRow(kind: kind, name: name, poi: poi, attributes: attributes),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _routePoints() {
    if (widget.routeGeometry.length >= 2) {
      return widget.routeGeometry.map((c) => LatLng(c.lat, c.lon)).toList();
    }
    return [
      LatLng(widget.origin.lat, widget.origin.lon),
      LatLng(widget.destination.lat, widget.destination.lon),
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

/// Attributes that get an icon + friendly label. Every OSM tag we
/// know about gets a visual entry so the sheet reads like Booking's
/// "Most popular facilities" strip (icon in accent colour, plain
/// text label next to it) instead of a wall of `key: value` pills.
///
/// Keys are OSM-normalized: `yes` / `true` renders the entry
/// "on", `no` / `false` hides it (we never advertise a missing
/// amenity). Non-boolean tags (e.g. `cuisine: italian`) render the
/// value as a short second line.
const Map<String, ({IconData icon, String label})> _featureCatalogue = {
  // Hotel amenities
  'breakfast': (icon: Icons.free_breakfast_outlined, label: 'Breakfast'),
  'restaurant': (icon: Icons.restaurant_outlined, label: 'Restaurant'),
  'bar': (icon: Icons.local_bar_outlined, label: 'Bar'),
  'wifi': (icon: Icons.wifi, label: 'Free Wi-Fi'),
  'internet_access': (icon: Icons.wifi, label: 'Free Wi-Fi'),
  'parking': (icon: Icons.local_parking_outlined, label: 'Parking'),
  'air_conditioning': (icon: Icons.ac_unit, label: 'Air conditioning'),
  'pool': (icon: Icons.pool, label: 'Swimming pool'),
  'swimming_pool': (icon: Icons.pool, label: 'Swimming pool'),
  'sauna': (icon: Icons.hot_tub_outlined, label: 'Sauna'),
  'spa': (icon: Icons.spa_outlined, label: 'Spa'),
  'gym': (icon: Icons.fitness_center_outlined, label: 'Gym'),
  'room_service': (icon: Icons.room_service_outlined, label: 'Room service'),
  'laundry_service':
      (icon: Icons.local_laundry_service_outlined, label: 'Laundry service'),
  'terrace': (icon: Icons.deck_outlined, label: 'Terrace'),
  'garden': (icon: Icons.grass_outlined, label: 'Garden'),
  'safe': (icon: Icons.lock_outline, label: 'Safe'),
  'baggage_storage':
      (icon: Icons.luggage_outlined, label: 'Baggage storage'),
  'reception_24_7':
      (icon: Icons.access_time_filled_outlined, label: '24h reception'),
  'business_center':
      (icon: Icons.business_center_outlined, label: 'Business center'),
  'family_rooms': (icon: Icons.family_restroom, label: 'Family rooms'),
  'child_friendly': (icon: Icons.child_care, label: 'Child friendly'),
  'kid_friendly': (icon: Icons.child_care, label: 'Child friendly'),
  'bicycle_rental':
      (icon: Icons.pedal_bike_outlined, label: 'Bicycle rental'),
  'smoking': (icon: Icons.smoking_rooms, label: 'Smoking area'),
  'non_smoking':
      (icon: Icons.smoke_free_outlined, label: 'Non-smoking'),
  'pets': (icon: Icons.pets, label: 'Pets allowed'),
  'dog': (icon: Icons.pets, label: 'Pets allowed'),
  'pet_friendly': (icon: Icons.pets, label: 'Pets allowed'),
  'wheelchair':
      (icon: Icons.accessible_forward, label: 'Wheelchair accessible'),
  'elevator': (icon: Icons.elevator_outlined, label: 'Elevator'),
  'lift': (icon: Icons.elevator_outlined, label: 'Elevator'),
  // Restaurant / cafe extras
  'outdoor_seating':
      (icon: Icons.deck_outlined, label: 'Outdoor seating'),
  'takeaway': (icon: Icons.takeout_dining_outlined, label: 'Takeaway'),
  'delivery': (icon: Icons.delivery_dining_outlined, label: 'Delivery'),
  'reservation':
      (icon: Icons.event_seat_outlined, label: 'Reservation'),
  'drive_through':
      (icon: Icons.drive_eta_outlined, label: 'Drive-through'),
  // Universal
  'toilets': (icon: Icons.wc, label: 'Toilets'),
  'shop': (icon: Icons.storefront_outlined, label: 'Shop'),
  'atm': (icon: Icons.atm_outlined, label: 'ATM'),
  'self_service':
      (icon: Icons.self_improvement, label: 'Self-service'),
  'contactless':
      (icon: Icons.contactless_outlined, label: 'Contactless payment'),
  'payment:contactless':
      (icon: Icons.contactless_outlined, label: 'Contactless payment'),
  'credit_cards': (icon: Icons.credit_card, label: 'Cards accepted'),
  'payment:credit_cards':
      (icon: Icons.credit_card, label: 'Cards accepted'),
  // Fuel station specifics
  'car_wash': (icon: Icons.local_car_wash_outlined, label: 'Car wash'),
  'fuel:diesel': (icon: Icons.local_gas_station_outlined, label: 'Diesel'),
  'fuel:octane_95':
      (icon: Icons.local_gas_station_outlined, label: 'Petrol 95'),
  'fuel:octane_98':
      (icon: Icons.local_gas_station_outlined, label: 'Petrol 98'),
  'fuel:lpg': (icon: Icons.propane_tank_outlined, label: 'LPG'),
  'fuel:e10': (icon: Icons.eco_outlined, label: 'E10'),
  'fuel:e85': (icon: Icons.eco_outlined, label: 'E85'),
  'fuel:HGV_diesel':
      (icon: Icons.local_shipping_outlined, label: 'HGV diesel'),
};

/// Turn an OSM tag key like `outdoor_seating` or `payment:contactless`
/// into a title-cased human label ("Outdoor seating", "Payment
/// contactless"). Used by the fallback "más info" section for tags
/// we haven't curated a pictogram for.
String _prettyKey(String key) {
  final cleaned = key.replaceAll(':', ' ').replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return key;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

bool _tagIsOn(String v) {
  final s = v.toLowerCase();
  return s == 'yes' || s == 'true' || s == '1' || s == 'designated';
}

bool _tagIsOff(String v) {
  final s = v.toLowerCase();
  return s == 'no' || s == 'false' || s == '0';
}

/// Compact hero strip at the top of the sheet body: 1-2 large stats
/// (price, stars, rating) rendered as tinted "spotlight" chips so
/// the driver reads the important numbers at a glance instead of
/// digging through label:value pills.
class _PoiSpotlight extends StatelessWidget {
  const _PoiSpotlight({
    required this.kind,
    required this.subtitle,
    required this.attributes,
    required this.accent,
  });

  final PoiKind kind;
  final String subtitle;
  final Map<String, String> attributes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // Star rating (1-5) — hotels usually carry `stars`.
    final rawStars = attributes['stars'];
    final stars = rawStars == null ? null : int.tryParse(rawStars.trim());
    // Google Places rating (0.0-5.0) — currently populated for
    // restaurants; hotels once enrichment ships.
    final ratingStr = attributes['rating'];
    final rating = ratingStr == null ? null : double.tryParse(ratingStr);
    final ratingCountStr = attributes['rating_count'];
    // Extract the "€ per meal / per night" figure from the caller's
    // subtitle — the subtitle already carries the price string, so
    // rather than duplicating it in attributes we lift it out for
    // the spotlight card. Rough regex: first "NN €" cluster.
    final priceMatch =
        RegExp(r'(\d+[\d,\.]*)\s*€').firstMatch(subtitle);
    final priceStr = priceMatch?.group(1);

    final tiles = <Widget>[];
    if (priceStr != null) {
      tiles.add(_SpotlightTile(
        icon: Icons.payments_outlined,
        value: '$priceStr €',
        caption: kind == PoiKind.hotel
            ? l.poiSpotlightPricePerNight
            : kind == PoiKind.restaurant
                ? l.poiSpotlightPricePerMeal
                : l.poiSpotlightPricePerL,
        accent: accent,
      ));
    }
    if (stars != null && stars > 0 && stars <= 5) {
      tiles.add(_SpotlightTile(
        icon: Icons.star_rounded,
        value: '★' * stars + '☆' * (5 - stars),
        caption: l.poiSpotlightStars,
        accent: Colors.amber.shade700,
        monospaceValue: true,
      ));
    }
    if (rating != null && rating > 0) {
      final subtitle2 = ratingCountStr == null
          ? l.poiSpotlightRating
          : l.poiSpotlightReviews(ratingCountStr);
      tiles.add(_SpotlightTile(
        icon: Icons.reviews_outlined,
        value: rating.toStringAsFixed(1),
        caption: subtitle2,
        accent: scheme.tertiary,
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: tiles);
  }
}

class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({
    required this.icon,
    required this.value,
    required this.caption,
    required this.accent,
    this.monospaceValue = false,
  });
  final IconData icon;
  final String value;
  final String caption;
  final Color accent;
  final bool monospaceValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: monospaceValue ? 0.5 : 0,
                ),
              ),
              Text(
                caption,
                style: t.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Icon-first grid of amenities. Each tile is bigger and more
/// scannable than the previous `label: value` pills — the driver
/// glances at icons instead of parsing prose. Boolean-off keys
/// (`no`, `false`) are dropped; non-boolean keys render the value
/// as a short second line.
class _FeatureTiles extends StatelessWidget {
  const _FeatureTiles({required this.attributes, required this.accent});
  final Map<String, String> attributes;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final entries = <(IconData, String, String?, Color)>[];
    for (final entry in attributes.entries) {
      final def = _featureCatalogue[entry.key];
      if (def == null) continue;
      if (_tagIsOff(entry.value)) continue;
      final valueLine = _tagIsOn(entry.value) ? null : entry.value;
      entries.add(
        (def.icon, def.label, valueLine, _tintForFeature(entry.key, scheme)),
      );
    }
    // Cuisine gets special treatment for restaurants — always show
    // the cuisine type as a feature tile.
    final cuisine = attributes['cuisine'];
    if (cuisine != null && cuisine.isNotEmpty) {
      entries.insert(0, (
        Icons.restaurant_menu,
        cuisine.split(';').first.trim(),
        null,
        _tintForFeature('cuisine', scheme),
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.poiFeaturesHeading,
          style: t.labelLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 12),
        // Booking-style flow: icon (in accent) + label right next to
        // it, no boxes, no borders, no filled backgrounds. Wraps
        // freely so 10+ amenities read as an airy grid instead of a
        // wall of pills. `runSpacing` gives vertical breathing room
        // between rows; `spacing: 20` matches Booking's horizontal
        // gap between adjacent items.
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            for (final (icon, label, valueLine, tint) in entries)
              _FeatureItem(
                icon: icon,
                label: label,
                valueLine: valueLine,
                tint: tint,
              ),
          ],
        ),
      ],
    );
  }
}

/// Palette of per-category tint colors so amenities aren't all the
/// same visual color. Each icon lands in a tinted circle that
/// matches its "family" (wellness → teal, food → orange, transport
/// → blue, comfort → violet, etc.). Gives the sheet a splash of
/// personality without depending on brand colors that would clash
/// with the app's dark theme.
Color _tintForFeature(String key, ColorScheme scheme) {
  const wellness = {'pool', 'swimming_pool', 'sauna', 'spa', 'gym'};
  const food = {'breakfast', 'restaurant', 'bar', 'cuisine', 'outdoor_seating',
    'takeaway', 'delivery', 'drive_through'};
  const connectivity = {'wifi', 'internet_access'};
  const transport = {'parking', 'car_wash', 'bicycle_rental', 'elevator',
    'lift'};
  const family = {'family_rooms', 'child_friendly', 'kid_friendly',
    'pets', 'dog', 'pet_friendly'};
  const service = {'room_service', 'laundry_service', 'reception_24_7',
    'business_center', 'safe', 'baggage_storage'};
  const outdoors = {'terrace', 'garden'};
  const accessibility = {'wheelchair', 'non_smoking'};
  const payment = {'contactless', 'payment:contactless',
    'credit_cards', 'payment:credit_cards', 'atm'};
  const fuel = {'fuel:diesel', 'fuel:octane_95', 'fuel:octane_98',
    'fuel:lpg', 'fuel:e10', 'fuel:e85', 'fuel:HGV_diesel'};

  if (wellness.contains(key)) return Colors.teal.shade600;
  if (food.contains(key)) return Colors.orange.shade700;
  if (connectivity.contains(key)) return Colors.blue.shade600;
  if (transport.contains(key)) return Colors.indigo.shade500;
  if (family.contains(key)) return Colors.pink.shade400;
  if (service.contains(key)) return Colors.deepPurple.shade400;
  if (outdoors.contains(key)) return Colors.green.shade700;
  if (accessibility.contains(key)) return Colors.cyan.shade700;
  if (payment.contains(key)) return Colors.brown.shade500;
  if (fuel.contains(key)) return Colors.deepOrange.shade600;
  // Fallback: keep it aligned with the sheet's accent color so the
  // "más info" items still read as coherent.
  return scheme.primary;
}

/// Guess an icon for an unknown OSM tag based on the tag name.
/// Prevents the fallback "más info" list from degenerating into a
/// sea of identical check marks — most OSM tags fall into a small
/// number of semantic buckets we can pattern-match on.
IconData _guessIconForKey(String key) {
  final k = key.toLowerCase();
  if (k.contains('phone') || k.contains('call')) return Icons.phone_outlined;
  if (k.contains('email') || k.contains('mail')) return Icons.email_outlined;
  if (k.contains('web') || k.contains('url')) return Icons.language;
  if (k.contains('hour') || k.contains('open') || k.contains('time')) {
    return Icons.schedule;
  }
  if (k.contains('star') || k.contains('rating')) return Icons.star_border;
  if (k.contains('price') || k.contains('cost') || k.contains('euro')) {
    return Icons.euro_outlined;
  }
  if (k.contains('addr') || k.contains('street') || k.contains('city')) {
    return Icons.place_outlined;
  }
  if (k.contains('brand') || k.contains('operator')) {
    return Icons.storefront_outlined;
  }
  if (k.contains('smoke') || k.contains('smoking')) return Icons.smoking_rooms;
  if (k.contains('capacity') || k.contains('seat')) {
    return Icons.people_outline;
  }
  if (k.contains('level') || k.contains('floor')) {
    return Icons.stairs_outlined;
  }
  if (k.contains('bed') || k.contains('room')) return Icons.bed_outlined;
  if (k.contains('shower') || k.contains('bath')) return Icons.shower;
  if (k.contains('drink') || k.contains('beer') || k.contains('wine')) {
    return Icons.local_bar_outlined;
  }
  if (k.contains('coffee') || k.contains('cafe')) return Icons.local_cafe;
  if (k.contains('note') || k.contains('description')) {
    return Icons.notes_outlined;
  }
  // Semantic-neutral fallback that still reads as "extra info" without
  // looking like a checkbox tick.
  return Icons.local_offer_outlined;
}

/// One "icon in tinted circle + label" amenity item. Booking-style
/// but with per-category color tints so the strip has visual variety
/// instead of the "sea of identical ticks" the flat version produced.
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.tint,
    this.valueLine,
  });
  final IconData icon;
  final String label;
  final String? valueLine;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (valueLine != null && valueLine!.isNotEmpty)
                  Text(
                    valueLine!,
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible "más info" section that carries every attribute not
/// promoted into the spotlight or the feature grid. Keeps power-user
/// info reachable without leaking OSM tag names into the primary view.
class _MoreInfoSection extends StatefulWidget {
  const _MoreInfoSection({required this.attributes});
  final Map<String, String> attributes;

  @override
  State<_MoreInfoSection> createState() => _MoreInfoSectionState();
}

class _MoreInfoSectionState extends State<_MoreInfoSection> {
  bool _open = false;

  // Keys already visible in the spotlight or feature tiles — no
  // need to duplicate them under "más info".
  static const Set<String> _promoted = {
    'stars',
    'rating',
    'rating_count',
    'google_price_level',
    'google_maps_url',
    'cuisine',
    'phone',
    'contact:phone',
    'website',
    'contact:website',
    ..._featureCatalogueKeys,
  };

  // Set-of-keys view of the catalogue. Kept as a static const so
  // the diff filter above stays cheap. Must stay in sync with
  // `_featureCatalogue` at the top of the file.
  static const Set<String> _featureCatalogueKeys = {
    'breakfast', 'restaurant', 'bar',
    'wifi', 'internet_access',
    'parking', 'air_conditioning',
    'pool', 'swimming_pool',
    'sauna', 'spa', 'gym',
    'room_service', 'laundry_service',
    'terrace', 'garden',
    'safe', 'baggage_storage', 'reception_24_7',
    'business_center', 'family_rooms', 'child_friendly', 'kid_friendly',
    'bicycle_rental', 'smoking', 'non_smoking',
    'pets', 'dog', 'pet_friendly',
    'wheelchair', 'elevator', 'lift',
    'outdoor_seating', 'takeaway', 'delivery', 'reservation',
    'drive_through',
    'toilets', 'shop', 'atm', 'self_service',
    'contactless', 'payment:contactless',
    'credit_cards', 'payment:credit_cards',
    'car_wash',
    'fuel:diesel', 'fuel:octane_95', 'fuel:octane_98',
    'fuel:lpg', 'fuel:e10', 'fuel:e85', 'fuel:HGV_diesel',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // The "rest": attributes not already surfaced above.
    final rest = <MapEntry<String, String>>[];
    for (final entry in widget.attributes.entries) {
      if (_promoted.contains(entry.key)) continue;
      // Booleans that are OFF are noise — skip.
      if (_tagIsOff(entry.value)) continue;
      rest.add(entry);
    }
    if (rest.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _open ? l.poiMoreInfoHide : l.poiMoreInfoLabel,
                  style: t.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          // Same icon+label pattern as the primary feature grid,
          // just with a neutral bullet icon since these are OSM tags
          // we don't have a curated pictogram for. Value line reads
          // the tag value (usually short — "yes", a brand, an hour
          // range); truncated to stay on a single line.
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              for (final entry in rest)
                _FeatureItem(
                  icon: _guessIconForKey(entry.key),
                  label: _prettyKey(entry.key),
                  valueLine: _tagIsOn(entry.value) ? null : entry.value,
                  tint: _tintForFeature(entry.key, scheme),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Renders each attribute as a chip with a matching icon where we know
/// one (stars → star, wifi → wifi, phone → phone, …). Unknown keys get
/// a bullet chip so nothing is dropped silently.
///
/// Deprecated: kept only as the fallback renderer inside
/// [_MoreInfoSection]. The primary layout uses [_PoiSpotlight] +
/// [_FeatureTiles] which are far more scannable.
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
    'parking': Icons.local_parking,
    'pool': Icons.pool,
    'swimming_pool': Icons.pool,
    'dog': Icons.pets,
    'pets': Icons.pets,
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
    // Google Places enrichment — real rating + count. Rendered
    // like any other attribute chip so the layout stays clean.
    'rating': Icons.star_rate,
    'rating_count': Icons.people_alt_outlined,
    'google_price_level': Icons.euro,
    'google_maps_url': Icons.link,
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

  /// Deterministic Google Maps URL when the POI carries a
  /// `google_maps_url` attribute (fed in by the backend's Google
  /// Places enricher). This links to the exact Google Place page
  /// — right business, right coords, no name-search fuzzy match.
  /// Returns null when the attribute isn't present, e.g. hotels
  /// before Places enrichment ships for them.
  Uri? _placeUrl() {
    final raw = attributes['google_maps_url'];
    if (raw == null || raw.isEmpty) return null;
    final u = Uri.tryParse(raw);
    if (u == null || !u.hasScheme) return null;
    return u;
  }

  Future<void> _openInMaps(BuildContext context) async {
    var ok = false;
    // Preferred path: Places-enriched URL that resolves to the
    // exact Google Place. This eliminates the "wrong hotel across
    // Europe" bug when Google's name search overrode the coord
    // hint. Restaurants already carry this attribute; hotels get
    // it once we extend enrichment to them.
    final place = _placeUrl();
    if (place != null) {
      try {
        ok = await launchUrl(
          place, mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        ok = false;
      }
      if (ok) return;
    }
    // Fallback: geo pin at the exact coord with the POI's name as
    // the pin label. No name search happens here — Maps just
    // drops a marker at the given lat/lon. Reliable across every
    // POI kind (hotels, restaurants, fuel, viewpoints).
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

  // Booking.com Affiliate tracking ID. Register at
  // affiliate.booking.com to get your own `aid`.
  static const _bookingAid = '2418471';

  // TheFork / TripAdvisor affiliate ref tag.
  static const _theForkRef = 'mytravelpal';

  Uri _theFork() {
    return Uri.https('www.google.com', '/search', {
      'q': '$name site:thefork.com ref=$_theForkRef',
    });
  }

  Uri _booking() => Uri.https('www.booking.com', '/searchresults.html', {
        'ss': name,
        'aid': _bookingAid,
        'label': 'mytravelpal-hotel-deeplink',
      });

  /// Deep-link to Airbnb searching short-term rentals in a small
  /// bounding box around this hotel's coordinates. Airbnb has no
  /// public affiliate API, so this is unmonetised — but it closes
  /// the "I want to check Airbnb here" gap without kicking users
  /// out of the app's flow completely. ±0.03° ~= ±3.3 km at 45°N.
  Uri _airbnb() {
    const halfDeg = 0.03;
    return Uri.https('www.airbnb.com', '/s/homes', {
      'refinement_paths[]': '/homes',
      'query': name,
      'ne_lat': (poi.lat + halfDeg).toStringAsFixed(5),
      'ne_lng': (poi.lon + halfDeg).toStringAsFixed(5),
      'sw_lat': (poi.lat - halfDeg).toStringAsFixed(5),
      'sw_lng': (poi.lon - halfDeg).toStringAsFixed(5),
      'zoom': '13',
      'search_type': 'filter_change',
    });
  }

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
        if (kind == PoiKind.hotel) ...[
          _CtaButton(
            icon: Icons.hotel_outlined,
            label: 'Booking',
            onPressed: () => _launch(context, _booking()),
          ),
          _CtaButton(
            icon: Icons.home_work_outlined,
            label: 'Airbnb',
            onPressed: () => _launch(context, _airbnb()),
          ),
        ],
        // Parking CTA for hotels + restaurants. Not every POI is
        // reachable on foot from a random spot — surfacing "find
        // parking nearby" here means the driver decides where to
        // sleep / eat AND has an obvious next step for the car
        // without navigating back to the plan.
        if (kind == PoiKind.hotel || kind == PoiKind.restaurant)
          _CtaButton(
            icon: Icons.local_parking_outlined,
            label: AppLocalizations.of(context).poiFindParking,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ParkingSearchScreen(
                  initialQuery: GeocodeResult(
                    displayName: name,
                    coordinate: poi,
                    country: Country.fr, // best-guess; used only as label
                  ),
                ),
              ),
            ),
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

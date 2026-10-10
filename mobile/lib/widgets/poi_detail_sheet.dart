import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../screens/parking_search_screen.dart';
import 'osm_attribution.dart';
import 'skeleton.dart';

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
  String? photoUrl,
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
      photoUrl: photoUrl,
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
    this.photoUrl,
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
  final String? photoUrl;

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
    // Strip OSM metadata / lat-lon / wiki links / duplicate name
    // variants BEFORE any sub-widget sees the map, so the feature
    // grid + "más info" both work off the same user-relevant slice.
    // Spotlight still reads the raw map — it needs the numeric
    // rating / stars / price values that would otherwise be blocked.
    final attributes = _userVisibleAttrs(widget.attributes);
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
              if (widget.photoUrl != null) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    widget.photoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Skeleton(width: double.infinity, height: 200),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Wikimedia Commons',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                        // HERE Places official name badge — shown when
                        // the backend's HerePlacesEnricher resolved the
                        // canonical chain name (e.g. "Ibis Budget" instead
                        // of the OSM freeform tag).
                        if (widget.attributes['here_name'] case final hereName?)
                          Text(
                            hereName,
                            style: t.labelSmall?.copyWith(
                              color: scheme.tertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Structured contact info (address / phone / website /
              // hours / check-in·out) between the header and the map.
              // Reads from the raw attribute map so Geoapify top-level
              // address fields are available.
              _ContactInfoRow(
                kind: kind,
                attributes: widget.attributes,
                poi: poi,
              ),
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
                // Spotlight needs the RAW attribute map because it
                // reads `stars`, `rating`, `rating_count` etc. — some
                // of which our own filter could over-eagerly drop
                // in a future revision.
                attributes: widget.attributes,
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
                  l.poiNoExtraInfo,
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
  // Hotel check-in / check-out
  'check_in': (icon: Icons.login_outlined, label: 'Check-in'),
  'check_out': (icon: Icons.logout_outlined, label: 'Check-out'),
  // Dietary restrictions (restaurant)
  'diet:vegetarian': (icon: Icons.eco_outlined, label: 'Vegetarian'),
  'diet:vegan': (icon: Icons.nature_outlined, label: 'Vegan'),
  'diet:halal': (icon: Icons.star_half_outlined, label: 'Halal'),
  'diet:kosher': (icon: Icons.verified_outlined, label: 'Kosher'),
  'diet:gluten_free': (icon: Icons.no_meals_outlined, label: 'Gluten-free'),
};

/// Return the localized label for a feature catalogue key, falling back
/// to the English string stored in `_featureCatalogue` for any key not
/// yet covered by translations.
String _featureLabelL10n(String key, AppLocalizations l) {
  switch (key) {
    case 'wifi':
    case 'internet_access':
      return l.poiAttr_wifi;
    case 'parking':
      return l.poiAttr_parking;
    case 'pool':
    case 'swimming_pool':
      return l.poiAttr_pool;
    case 'air_conditioning':
      return l.poiAttr_airConditioning;
    case 'breakfast':
      return l.poiAttr_breakfast;
    case 'pets':
    case 'dog':
    case 'pet_friendly':
      return l.poiAttr_petFriendly;
    case 'child_friendly':
    case 'kid_friendly':
      return l.poiAttr_childFriendly;
    case 'family_rooms':
      return l.poiAttr_childFriendly;
    case 'wheelchair':
      return l.poiAttr_wheelchairAccess;
    case 'toilets':
      return l.poiAttr_toilets;
    case 'restaurant':
      return l.poiAttr_restaurant;
    case 'bar':
      return l.poiAttr_bar;
    case 'shop':
      return l.poiAttr_shop;
    case 'outdoor_seating':
      return l.poiAttr_outdoorSeating;
    case 'takeaway':
      return l.poiAttr_takeaway;
    case 'delivery':
      return l.poiAttr_delivery;
    case 'credit_cards':
    case 'payment:credit_cards':
    case 'contactless':
    case 'payment:contactless':
      return l.poiAttr_creditCards;
    case 'car_wash':
      return l.poiAttr_carWash;
    case 'smoking':
      return l.poiAttr_smoking;
    case 'non_smoking':
      return l.poiAttr_nonSmoking;
    case 'elevator':
    case 'lift':
      return l.poiAttr_elevator;
    case 'check_in':
      return l.poiAttr_checkIn;
    case 'check_out':
      return l.poiAttr_checkOut;
    case 'diet:vegetarian':
      return l.poiAttr_dietVegetarian;
    case 'diet:vegan':
      return l.poiAttr_dietVegan;
    case 'diet:halal':
      return l.poiAttr_dietHalal;
    case 'diet:kosher':
      return l.poiAttr_dietKosher;
    case 'diet:gluten_free':
      return l.poiAttr_dietGlutenFree;
    case 'brand':
    case 'operator':
      return l.poiAttr_brand;
    case 'city':
    case 'addr:city':
    case 'here_city':
      return l.poiAttr_city;
    case 'street':
    case 'addr:street':
      return l.poiAttr_street;
    case 'address':
    case 'here_address':
    case 'addr:full':
      return l.poiAttr_address;
    case 'opening_hours':
      return l.poiAttr_openingHours;
    case 'name':
      return l.poiAttr_name;
    case 'phone':
    case 'contact:phone':
      return l.poiAttr_phone;
    case 'stars':
    case 'hotel_stars':
      return l.poiAttr_stars;
    case 'website':
    case 'contact:website':
    case 'url':
      return l.poiAttr_website;
    default:
      // Fall back to the English label already stored in the catalogue.
      return _featureCatalogue[key]?.label ?? _prettyKey(key);
  }
}

/// Turn an OSM tag key like `outdoor_seating` or `payment:contactless`
/// into a title-cased human label ("Outdoor seating", "Payment
/// contactless"). Used by the fallback "más info" section for tags
/// we haven't curated a pictogram for.
String _prettyKey(String key) {
  final cleaned = key.replaceAll(':', ' ').replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return key;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

/// OSM tag keys the driver never cares about — internal identifiers,
/// data-source metadata, geographic ids, cross-references, wiki
/// links. Filtered out at the sheet body level so they never reach
/// the feature grid OR the "más info" fallback (they were producing
/// a "sea of ticks" in the collapsible when a POI came back with
/// 8-10 metadata tags).
///
/// Also filters via prefix / substring in [_isVisibleAttrKey] for
/// families where enumerating every variant is impractical (any
/// `*:wikidata`, any `ref:*`, any `check_date:*`, etc.).
const Set<String> _ATTR_BLOCKLIST = {
  // Geographic identifiers — the sheet already renders the POI on
  // the map; the raw coord numbers add nothing.
  'lat', 'lon', 'latitude', 'longitude',
  // OSM internals.
  'osm_id', 'osm_type', 'osm_key', 'osm_value',
  'id', 'type', 'timestamp', 'version', 'changeset',
  // Data provenance / cross-references — power-user metadata.
  'source', 'source:name', 'source:date', 'source:website',
  'import', 'imported', 'note', 'fixme', 'attribution',
  'ref', 'ref:vatin', 'ref:sirene',
  'wikidata', 'wikipedia',
  'brand:wikidata', 'brand:wikipedia',
  'operator:wikidata', 'operator:wikipedia',
  'name:wikidata', 'name:wikipedia',
  // Naming variants that duplicate `name` — one is enough.
  'alt_name', 'old_name', 'loc_name', 'short_name', 'name:en',
  'name:es', 'name:fr', 'name:it', 'name:de',
  // Rendered by our own spotlight / structured chips already.
  'rating_source', 'rating_scale',
  // POI-kind tag itself — inferred from `PoiKind` in the header.
  'amenity', 'tourism',
};

/// Same-purpose filter with prefix / substring rules for tag
/// families that would explode a static set (`check_date:opening_hours`,
/// `ref:eu:vat`, `name:zh-Hant`, etc.).
bool _isVisibleAttrKey(String k) {
  if (_ATTR_BLOCKLIST.contains(k)) return false;
  final lower = k.toLowerCase();
  if (lower.startsWith('check_date')) return false;
  if (lower.startsWith('survey:')) return false;
  if (lower.startsWith('addr:full')) return false;
  if (lower.contains(':wikidata')) return false;
  if (lower.contains(':wikipedia')) return false;
  if (lower.startsWith('name:')) return false; // localized names.
  if (lower.startsWith('ref:')) return false;
  return true;
}

/// Filter an attributes map down to the entries the driver actually
/// cares about. Applied uniformly by the feature grid + the "más
/// info" fallback so no widget has to redo the blocklist.
Map<String, String> _userVisibleAttrs(Map<String, String> src) {
  final out = <String, String>{};
  for (final entry in src.entries) {
    if (!_isVisibleAttrKey(entry.key)) continue;
    if (_tagIsOff(entry.value)) continue;
    out[entry.key] = entry.value;
  }
  return out;
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
        (def.icon, _featureLabelL10n(entry.key, l), valueLine, _tintForFeature(entry.key, scheme)),
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
    'takeaway', 'delivery', 'drive_through',
    'diet:vegetarian', 'diet:vegan', 'diet:halal', 'diet:kosher', 'diet:gluten_free'};
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
/// Returns null when no semantic pattern matches — the caller is
/// expected to DROP the entry rather than render a generic
/// placeholder icon that produced the "sea of ticks" tester
/// feedback. Better a shorter list than a noisy one.
IconData? _guessIconForKey(String key) {
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
  if (k.contains('description')) return Icons.notes_outlined;
  // No semantic match → tell the caller to skip this entry.
  return null;
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

  // Keys already visible in the spotlight, contact-info row or feature
  // tiles — no need to duplicate them under "más info".
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
    'opening_hours',
    'address_line1',
    'addr:street',
    'addr:housenumber',
    'addr:city',
    // The address row above already carries the city, and the price is the
    // spotlight tile (an estimate we compute, not a listed price); showing
    // them again here produced an untranslated "Price" and a "City" that
    // held a street.
    'city',
    'here_city',
    'here_address',
    'here_postal_code',
    'here_country',
    'here_id',
    'price',
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
    // check_in / check_out are shown by _ContactInfoRow so keep them
    // out of _FeatureTiles to avoid duplication. 2026-09-30 review.
    'diet:vegetarian', 'diet:vegan', 'diet:halal', 'diet:kosher', 'diet:gluten_free',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // The "rest": attributes not already surfaced above, further
    // constrained to keys we can render with a semantic icon. Tags
    // without a matched icon are dropped rather than shown with a
    // generic pictogram — tester feedback rejected the "sea of
    // ticks" look the previous generic-fallback pattern produced.
    final rest = <MapEntry<String, String>>[];
    for (final entry in widget.attributes.entries) {
      if (_promoted.contains(entry.key)) continue;
      if (!_isVisibleAttrKey(entry.key)) continue;
      if (_tagIsOff(entry.value)) continue;
      if (_guessIconForKey(entry.key) == null) continue;
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
                if (_guessIconForKey(entry.key) != null)
                  _FeatureItem(
                    icon: _guessIconForKey(entry.key)!,
                    label: _featureLabelL10n(entry.key, AppLocalizations.of(context)),
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

/// Structured contact-info section shown between the POI header and the
/// mini-map. Renders any of: address, phone, website, opening hours,
/// check-in / check-out (hotels only). Each row is tappable where it
/// makes sense (phone → tel: URI, website → browser, address → Maps).
///
/// Receives the RAW attributes map so address / contact fields are
/// available even before `_userVisibleAttrs` filtering.
class _ContactInfoRow extends StatelessWidget {
  const _ContactInfoRow({
    required this.kind,
    required this.attributes,
    required this.poi,
  });

  final PoiKind kind;
  final Map<String, String> attributes;
  final LatLon poi;

  Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
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
        SnackBar(content: Text(AppLocalizations.of(context).poiOpenError(uri.toString()))),
      );
    }
  }

  /// Build the full address string from available fields, preferring
  /// address_line1 (Geoapify) over the OSM addr:* components.
  String? _buildAddress() {
    // Prefer the HERE-enriched canonical address when present — it's
    // the official formatted string from Google/HERE and is more
    // complete than ad-hoc OSM addr:* tags.
    final hereAddr = attributes['here_address'];
    if (hereAddr != null && hereAddr.isNotEmpty) return hereAddr;
    final a1 = attributes['address_line1'];
    if (a1 != null && a1.isNotEmpty) return a1;
    final street = attributes['addr:street'];
    final number = attributes['addr:housenumber'];
    final city = attributes['addr:city'];
    if (street != null && street.isNotEmpty) {
      final parts = <String>[
        if (number != null && number.isNotEmpty) '$street $number' else street,
        if (city != null && city.isNotEmpty) city,
      ];
      return parts.join(', ');
    }
    return null;
  }

  Uri _mapsForAddress(String address) =>
      Uri.parse('https://maps.google.com/?q=${poi.lat},${poi.lon}&z=17');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final address = _buildAddress();
    final phone = attributes['phone'] ?? attributes['contact:phone'];
    final website = attributes['website'] ?? attributes['contact:website'];
    final hours = attributes['opening_hours'];
    final checkIn = kind == PoiKind.hotel ? attributes['check_in'] : null;
    final checkOut = kind == PoiKind.hotel ? attributes['check_out'] : null;

    if (address == null && phone == null && website == null &&
        hours == null && checkIn == null && checkOut == null) {
      return const SizedBox.shrink();
    }

    Widget infoRow({
      required IconData icon,
      required String label,
      required String value,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: t.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      value,
                      style: t.bodyMedium?.copyWith(
                        color: onTap != null
                            ? scheme.primary
                            : scheme.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (address != null)
            infoRow(
              icon: Icons.place_outlined,
              label: l.poiContactAddress,
              value: address,
              onTap: () => _open(context, _mapsForAddress(address)),
            ),
          if (phone != null)
            infoRow(
              icon: Icons.phone_outlined,
              label: l.poiContactPhone,
              value: phone,
              onTap: () => _open(context, Uri.parse('tel:${phone.replaceAll(' ', '')}')),
            ),
          if (website != null)
            infoRow(
              icon: Icons.language,
              label: l.poiContactWebsite,
              value: website.replaceAll(RegExp(r'^https?://'), ''),
              onTap: () => _open(
                context,
                website.startsWith('http')
                    ? Uri.parse(website)
                    : Uri.parse('https://$website'),
              ),
            ),
          if (hours != null)
            infoRow(
              icon: Icons.schedule,
              label: l.poiContactHours,
              value: hours,
            ),
          if (checkIn != null)
            infoRow(
              icon: Icons.login_outlined,
              label: l.poiContactCheckin,
              value: checkIn,
            ),
          if (checkOut != null)
            infoRow(
              icon: Icons.logout_outlined,
              label: l.poiContactCheckout,
              value: checkOut,
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
        SnackBar(content: Text(AppLocalizations.of(context).poiOpenError(uri.toString()))),
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

  // maps.google.com/?q=lat,lon drops a pin at the EXACT coordinates
  // without any address geocoding. The /maps/search/ endpoint
  // resolves coords to the nearest known address (can be 10-50 m off);
  // the direct ?q= format pins the raw coordinate every time.
  Uri _googleMapsHttpsFallback() =>
      Uri.parse('https://maps.google.com/?q=${poi.lat},${poi.lon}&z=17');

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

  /// True when the visible name is a synthesized "km N" fallback
  /// rather than a real POI label. Backend emits these when Overpass
  /// didn't match a named place within the search radius; passing
  /// "km 184" as a Google Maps search query resolves to garbage
  /// ("kilometer 184" as a text search).
  bool get _isFallbackName {
    final trimmed = name.trim();
    return trimmed.isEmpty ||
        trimmed == '—' ||
        RegExp(r'^km\s+\d+', caseSensitive: false).hasMatch(trimmed);
  }

  /// Google Maps search URL biased to the POI coord — Maps performs a
  /// name lookup within the map viewport so it lands on the ACTUAL
  /// business card (not a bare lat/lon pin the user has to close +
  /// zoom + tap again to reach). Tester 2026-09-30: geo: URIs opened
  /// an unnamed pin; users had to deselect and hunt for the POI on
  /// the map. This format resolves the POI directly.
  ///
  /// When the label is a "km N" fallback (backend couldn't name the
  /// POI), fall back to coord-only query — Maps drops a pin at the
  /// right coord instead of searching for the literal string "km 184"
  /// which resolves to nothing useful.
  Uri _mapsSearchUri() {
    if (_isFallbackName) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${poi.lat},${poi.lon}',
      });
    }
    final label = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      // "<name> <lat>,<lon>" as a single query — Google Maps interprets
      // this as "search NAME near LAT,LON" and picks the closest match.
      'query': '$label ${poi.lat},${poi.lon}',
    });
  }

  Future<void> _openInMaps(BuildContext context) async {
    var ok = false;
    // 1. Places-enriched URL: resolves to the exact Google Place card.
    final place = _placeUrl();
    if (place != null) {
      try {
        ok = await launchUrl(place, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
      if (ok) return;
    }
    // 2. Coord-only Maps URL: query=lat,lon drops an exact pin with no
    //    text search. geo: URIs look correct but Google Maps treats the
    //    q= parameter as a text search query, showing global results
    //    instead of pinning the location. HTTPS + externalApplication
    //    opens the Maps app directly on Android.
    if (!context.mounted) return;
    await _launch(context, _googleMapsHttpsFallback());
  }

  // Booking.com Affiliate tracking ID. Register at
  // affiliate.booking.com to get your own `aid`.
  static const _bookingAid = '2418471';
  static const _hotelsCamref = '1110lR637';
  static const _hotelsCreativeref = '1011l66481';
  static const _hotelsAdref = 'PZ3qdnq8sf';

  // TheFork / TripAdvisor affiliate ref tag.
  static const _theForkRef = 'mytravelpal';

  Uri _theFork() {
    final encoded = Uri.encodeComponent(
      name.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    return Uri.parse(
      'https://www.thefork.com/search'
      '#cityId=0&query=$encoded'
      '&lat=${poi.lat}&lng=${poi.lon}&radius=10',
    );
  }

  Uri _booking() => Uri.https('www.booking.com', '/searchresults.html', {
        'ss': name,
        'aid': _bookingAid,
        'label': 'mytravelpal-hotel-deeplink',
      });

  Uri _hotelsCom() {
    final searchUrl = Uri.https('www.hotels.com', '/search.do', {
      'destination': name,
    }).toString();
    return Uri.https('www.hotels.com', '/affiliate', {
      'landingPage': searchUrl,
      'camref': _hotelsCamref,
      'creativeref': _hotelsCreativeref,
      'adref': _hotelsAdref,
    });
  }

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
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CtaButton(
          icon: Icons.map_outlined,
          label: l.poiCtaGoogleMaps,
          onPressed: () => _openInMaps(context),
        ),
        if (kind == PoiKind.restaurant)
          _CtaButton(
            icon: Icons.restaurant_menu,
            label: l.poiCtaTheFork,
            onPressed: () => _launch(context, _theFork()),
          ),
        if (kind == PoiKind.hotel) ...[
          _CtaButton(
            icon: Icons.hotel_outlined,
            label: l.poiCtaBooking,
            onPressed: () => _launch(context, _booking()),
          ),
          _CtaButton(
            icon: Icons.hotel_outlined,
            label: 'Hotels.com',
            onPressed: () => _launch(context, _hotelsCom()),
          ),
          _CtaButton(
            icon: Icons.home_work_outlined,
            label: l.poiCtaAirbnb,
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
            label: l.poiFindParking,
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
            label: l.poiCtaCall,
            onPressed: () => _launch(context, _tel()),
          ),
        if (hasWebsite)
          _CtaButton(
            icon: Icons.language,
            label: l.poiCtaWebsite,
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Public entry points
// ---------------------------------------------------------------------------

/// Opens a full-screen-ish picker sheet for hotel alternatives.
///
/// [entries] are (Hotel, kmDistance) pairs already sorted by the caller.
/// [currentHotel] is highlighted so the driver knows what is already picked.
/// [onPicked] fires when the driver taps "ELEGIR"; the sheet closes itself.
Future<void> showHotelPickerSheet(
  BuildContext context, {
  required String title,
  required List<(Hotel, double)> entries,
  Hotel? currentHotel,
  required void Function(Hotel hotel) onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HotelPickerSheet(
      title: title,
      entries: entries,
      currentHotel: currentHotel,
      onPicked: onPicked,
    ),
  );
}

/// Opens a full-screen-ish picker sheet for restaurant alternatives near a
/// meal stop. [restaurants] is the full trip-level list; the sheet renders
/// them in the order supplied (caller should pre-filter + sort by proximity).
///
/// [onPicked] fires when the driver taps "ELEGIR"; the sheet closes itself.
Future<void> showRestaurantPickerSheet(
  BuildContext context, {
  required String title,
  required List<(Restaurant, double)> entries,
  required void Function(Restaurant restaurant) onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RestaurantPickerSheet(
      title: title,
      entries: entries,
      onPicked: onPicked,
    ),
  );
}

// ---------------------------------------------------------------------------
// Hotel picker
// ---------------------------------------------------------------------------

class _HotelPickerSheet extends StatefulWidget {
  const _HotelPickerSheet({
    required this.title,
    required this.entries,
    this.currentHotel,
    required this.onPicked,
  });

  final String title;
  final List<(Hotel, double)> entries;
  final Hotel? currentHotel;
  final void Function(Hotel) onPicked;

  @override
  State<_HotelPickerSheet> createState() => _HotelPickerSheetState();
}

class _HotelPickerSheetState extends State<_HotelPickerSheet> {
  bool _mapVisible = false;
  // Tracks whether the map has been rendered after the open animation
  // completes. flutter_map calculates initialCameraFit based on the
  // widget's size at first render — if the AnimatedContainer is still
  // animating (height near 0) the fit lands on the world view. We
  // delay rendering until the animation finishes so the map sees
  // its full 200 px height on the very first layout pass.
  bool _mapRendered = false;

  bool _isCurrent(Hotel h) {
    final c = widget.currentHotel;
    if (c == null) return false;
    return c.name == h.name &&
        c.coordinate.lat == h.coordinate.lat &&
        c.coordinate.lon == h.coordinate.lon;
  }

  void _openDetail(BuildContext ctx, Hotel hotel, double km) {
    showHotelDetailSheet(
      ctx,
      hotel: hotel,
      km: km,
      isPicked: _isCurrent(hotel),
      onElegir: () {
        // Close detail sheet then picker sheet, then notify parent.
        Navigator.of(ctx).pop();
        Navigator.of(ctx).pop();
        widget.onPicked(hotel);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    if (widget.entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: Center(child: Text(l.daySleepHotelsNotFound)),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (sheetCtx, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + map toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Tokens.space20, 0, Tokens.space8, Tokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: t.titleMedium),
                ),
                IconButton(
                  icon: Icon(
                    _mapVisible ? Icons.map : Icons.map_outlined,
                    color: _mapVisible
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  tooltip: _mapVisible ? 'Ocultar mapa' : 'Ver en mapa',
                  onPressed: () {
                    setState(() {
                      _mapVisible = !_mapVisible;
                      if (!_mapVisible) _mapRendered = false;
                    });
                    if (_mapVisible) {
                      // Delay until the 280 ms open animation finishes.
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() => _mapRendered = true);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          // Overview map — collapsible, shows all hotel pins.
          // Only rendered after the open animation completes so
          // flutter_map sees its full height on the first layout.
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: _mapVisible ? 200 : 0,
            child: _mapVisible && _mapRendered
                ? _HotelOverviewMap(
                    entries: widget.entries,
                    currentHotel: widget.currentHotel,
                    onMarkerTap: (hotel, km) =>
                        _openDetail(sheetCtx, hotel, km),
                  )
                : const SizedBox.shrink(),
          ),
          if (_mapVisible)
            const Divider(height: 1),
          // Hotel list
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                  Tokens.space16, Tokens.space8,
                  Tokens.space16, Tokens.space24),
              itemCount: widget.entries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Tokens.space8),
              itemBuilder: (ctx, i) {
                final (hotel, km) = widget.entries[i];
                final picked = _isCurrent(hotel);
                return _HotelCard(
                  hotel: hotel,
                  km: km,
                  isPicked: picked,
                  onPick: () {
                    Navigator.of(sheetCtx).pop();
                    widget.onPicked(hotel);
                  },
                  onDetail: () => _openDetail(sheetCtx, hotel, km),
                  scheme: scheme,
                  t: t,
                  l: l,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview map (all hotel pins)
// ---------------------------------------------------------------------------

class _HotelOverviewMap extends StatelessWidget {
  const _HotelOverviewMap({
    required this.entries,
    required this.currentHotel,
    required this.onMarkerTap,
  });

  final List<(Hotel, double)> entries;
  final Hotel? currentHotel;
  final void Function(Hotel hotel, double km) onMarkerTap;

  bool _isCurrent(Hotel h) {
    final c = currentHotel;
    if (c == null) return false;
    return c.name == h.name &&
        c.coordinate.lat == h.coordinate.lat &&
        c.coordinate.lon == h.coordinate.lon;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = entries
        .map((e) => ll.LatLng(e.$1.coordinate.lat, e.$1.coordinate.lon))
        .toList();

    final center = ll.LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
    );

    // Build bounds from all points, but enforce a minimum span of ~2 km so
    // flutter_map doesn't zoom out to world-level when hotels are identical
    // or extremely close together.
    const minSpan = 0.02; // ~2 km in degrees
    var bounds = fmap.LatLngBounds.fromPoints(points);
    final latSpan = bounds.north - bounds.south;
    final lonSpan = bounds.east - bounds.west;
    if (latSpan < minSpan || lonSpan < minSpan) {
      bounds = fmap.LatLngBounds(
        ll.LatLng(center.latitude - minSpan / 2, center.longitude - minSpan / 2),
        ll.LatLng(center.latitude + minSpan / 2, center.longitude + minSpan / 2),
      );
    }

    final mapWidget = fmap.FlutterMap(
      options: fmap.MapOptions(
        initialCenter: center,
        initialZoom: 13,
        initialCameraFit: fmap.CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
          maxZoom: 15,
        ),
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mytravelpal.travel',
        ),
        fmap.MarkerLayer(
          markers: [
            for (final (hotel, km) in entries)
              fmap.Marker(
                point: ll.LatLng(
                    hotel.coordinate.lat, hotel.coordinate.lon),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => onMarkerTap(hotel, km),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isCurrent(hotel)
                          ? scheme.primary
                          : scheme.tertiary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.hotel,
                      size: 18,
                      color: _isCurrent(hotel)
                          ? scheme.onPrimary
                          : scheme.onTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        mapWidget,
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openFullscreenMap(context),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullscreenMap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).hotelMapFullscreenTitle),
            backgroundColor: Colors.transparent,
          ),
          extendBodyBehindAppBar: true,
          body: fmap.FlutterMap(
            options: fmap.MapOptions(
              initialCenter: ll.LatLng(
                entries.map((e) => e.$1.coordinate.lat).reduce((a, b) => a + b) /
                    entries.length,
                entries.map((e) => e.$1.coordinate.lon).reduce((a, b) => a + b) /
                    entries.length,
              ),
              initialZoom: 14,
            ),
            children: [
              fmap.TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mytravelpal.travel',
              ),
              fmap.MarkerLayer(
                markers: [
                  for (final (hotel, km) in entries)
                    fmap.Marker(
                      point: ll.LatLng(
                          hotel.coordinate.lat, hotel.coordinate.lon),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => onMarkerTap(hotel, km),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isCurrent(hotel)
                                ? scheme.primary
                                : scheme.tertiary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.hotel, size: 22,
                              color: _isCurrent(hotel)
                                  ? scheme.onPrimary
                                  : scheme.onTertiary),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hotel detail sheet
// ---------------------------------------------------------------------------

Future<void> showHotelDetailSheet(
  BuildContext context, {
  required Hotel hotel,
  required double km,
  bool isPicked = false,
  VoidCallback? onElegir,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HotelDetailSheet(
      hotel: hotel,
      km: km,
      isPicked: isPicked,
      onElegir: onElegir,
    ),
  );
}

class _HotelDetailSheet extends StatelessWidget {
  const _HotelDetailSheet({
    required this.hotel,
    required this.km,
    required this.isPicked,
    this.onElegir,
  });

  final Hotel hotel;
  final double km;
  final bool isPicked;
  final VoidCallback? onElegir;

  static const _bookingAid = '2418471';
  static const _hotelsCamref = '1110lR637';
  static const _hotelsCreativeref = '1011l66481';
  static const _hotelsAdref = 'PZ3qdnq8sf';

  Future<void> _openBooking(BuildContext context) async {
    final uri = Uri.https('www.booking.com', '/searchresults.html', {
      'ss': hotel.name,
      'aid': _bookingAid,
      'label': 'mytravelpal-hotel-picker',
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openHotelsCom(BuildContext context) async {
    final searchUrl = Uri.https('www.hotels.com', '/search.do', {
      'destination': hotel.name,
    }).toString();
    final uri = Uri.https('www.hotels.com', '/affiliate', {
      'landingPage': searchUrl,
      'camref': _hotelsCamref,
      'creativeref': _hotelsCreativeref,
      'adref': _hotelsAdref,
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openMaps(BuildContext context) async {
    final lat = hotel.coordinate.lat;
    final lon = hotel.coordinate.lon;
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lon&z=17');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);

    final starsRaw = hotel.attributes['stars'];
    final stars = starsRaw == null ? null : int.tryParse(starsRaw.trim());
    final hasWifi = hotel.attributes.containsKey('wifi') ||
        hotel.attributes.containsKey('internet_access');
    final hasParking = hotel.attributes.containsKey('parking');
    final hasBreakfast = hotel.attributes.containsKey('breakfast');
    final hasPool = hotel.attributes.containsKey('swimming_pool') ||
        hotel.attributes['leisure'] == 'swimming_pool';
    final hasRestaurant = hotel.attributes['restaurant'] == 'yes';
    final checkIn = hotel.attributes['check_in'];
    final checkOut = hotel.attributes['check_out'];
    final address = hotel.attributes['addr:street'] != null
        ? [
            hotel.attributes['addr:street'],
            hotel.attributes['addr:housenumber'],
            hotel.attributes['addr:city'],
          ].whereType<String>().join(' ')
        : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            Tokens.space20, 0, Tokens.space20, Tokens.space32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + stars
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hotel.name,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (stars != null && stars > 0 && stars <= 5) ...[
                  const SizedBox(width: Tokens.space8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '★' * stars,
                      style: t.bodyMedium?.copyWith(
                        color: Colors.amber.shade700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Tokens.space4),
            Text(
              '${km.toStringAsFixed(1)} km',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                address,
                style:
                    t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Tokens.space16),

            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: hotel.photoUrl != null
                  ? Image.network(
                      hotel.photoUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PhotoPlaceholder(scheme: scheme),
                    )
                  : _PhotoPlaceholder(scheme: scheme),
            ),
            const SizedBox(height: Tokens.space16),

            // Amenity chips
            if (hasWifi || hasParking || hasBreakfast ||
                hasPool || hasRestaurant) ...[
              Wrap(
                spacing: Tokens.space4,
                runSpacing: Tokens.space4,
                children: [
                  if (hasParking)
                    _AmenityChip(
                        icon: Icons.local_parking_outlined,
                        label: l.poiAttr_parking,
                        scheme: scheme),
                  if (hasWifi)
                    _AmenityChip(
                        icon: Icons.wifi,
                        label: l.poiAttr_wifi,
                        scheme: scheme),
                  if (hasBreakfast)
                    _AmenityChip(
                        icon: Icons.free_breakfast_outlined,
                        label: l.poiAttr_breakfast,
                        scheme: scheme),
                  if (hasPool)
                    _AmenityChip(
                        icon: Icons.pool_outlined,
                        label: 'Piscina',
                        scheme: scheme),
                  if (hasRestaurant)
                    _AmenityChip(
                        icon: Icons.restaurant_outlined,
                        label: 'Restaurante',
                        scheme: scheme),
                ],
              ),
              const SizedBox(height: Tokens.space12),
            ],

            // Check-in / check-out
            if (checkIn != null || checkOut != null) ...[
              Row(
                children: [
                  if (checkIn != null) ...[
                    Icon(Icons.login_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Check-in: $checkIn',
                        style: t.bodySmall),
                    const SizedBox(width: Tokens.space16),
                  ],
                  if (checkOut != null) ...[
                    Icon(Icons.logout_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Check-out: $checkOut',
                        style: t.bodySmall),
                  ],
                ],
              ),
              const SizedBox(height: Tokens.space12),
            ],

            // Mini-map
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: SizedBox(
                height: 160,
                child: fmap.FlutterMap(
                  options: fmap.MapOptions(
                    initialCenter: ll.LatLng(
                        hotel.coordinate.lat, hotel.coordinate.lon),
                    initialZoom: 14,
                  ),
                  children: [
                    fmap.TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mytravelpal.travel',
                    ),
                    fmap.MarkerLayer(
                      markers: [
                        fmap.Marker(
                          point: ll.LatLng(hotel.coordinate.lat,
                              hotel.coordinate.lon),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.tertiary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.hotel,
                                size: 18, color: scheme.onTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.space20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(l.exportOpenInMaps),
                    onPressed: () => _openMaps(context),
                  ),
                ),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.hotel_outlined, size: 18),
                    label: const Text('Booking'),
                    onPressed: () => _openBooking(context),
                  ),
                ),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.hotel_outlined, size: 18),
                    label: const Text('Hotels.com'),
                    onPressed: () => _openHotelsCom(context),
                  ),
                ),
              ],
            ),
            if (onElegir != null) ...[
              const SizedBox(height: Tokens.space12),
              SizedBox(
                width: double.infinity,
                child: isPicked
                    ? OutlinedButton.icon(
                        icon: Icon(Icons.check_circle,
                            size: 18, color: scheme.primary),
                        label: Text(
                          l.poiPickerSelected,
                          style: TextStyle(color: scheme.primary),
                        ),
                        onPressed: onElegir,
                      )
                    : FilledButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(l.poiPickerChoose),
                        onPressed: onElegir,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_outlined,
              size: 48,
              color: scheme.tertiary.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hotel card
// ---------------------------------------------------------------------------

class _HotelCard extends StatelessWidget {
  const _HotelCard({
    required this.hotel,
    required this.km,
    required this.isPicked,
    required this.onPick,
    required this.onDetail,
    required this.scheme,
    required this.t,
    required this.l,
  });

  final Hotel hotel;
  final double km;
  final bool isPicked;
  final VoidCallback onPick;
  final VoidCallback onDetail;
  final ColorScheme scheme;
  final TextTheme t;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final starsRaw = hotel.attributes['stars'];
    final stars = starsRaw == null ? null : int.tryParse(starsRaw.trim());
    final hasWifi = hotel.attributes.containsKey('wifi') ||
        hotel.attributes.containsKey('internet_access');
    final hasParking = hotel.attributes.containsKey('parking');
    final hasBreakfast = hotel.attributes.containsKey('breakfast');

    final borderColor = isPicked ? scheme.primary : scheme.outlineVariant;
    final bg = isPicked
        ? scheme.primaryContainer.withValues(alpha: 0.18)
        : scheme.surfaceContainerLow;

    return InkWell(
      onTap: onDetail,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PoiPhoto(
                size: 80,
                url: hotel.photoUrl,
                fallbackIcon: Icons.hotel_outlined,
                color: scheme.tertiary,
              ),
              const SizedBox(width: Tokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            hotel.name,
                            style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (stars != null && stars > 0 && stars <= 5) ...[
                          const SizedBox(width: Tokens.space4),
                          Text(
                            '★' * stars,
                            style: t.bodySmall?.copyWith(
                              color: Colors.amber.shade700,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Tokens.space4),
                    Text(
                      '${km.toStringAsFixed(1)} km',
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasWifi || hasParking || hasBreakfast) ...[
                      const SizedBox(height: Tokens.space4),
                      Wrap(
                        spacing: Tokens.space4,
                        children: [
                          if (hasParking)
                            _AmenityChip(
                              icon: Icons.local_parking_outlined,
                              label: l.poiAttr_parking,
                              scheme: scheme,
                            ),
                          if (hasWifi)
                            _AmenityChip(
                              icon: Icons.wifi,
                              label: l.poiAttr_wifi,
                              scheme: scheme,
                            ),
                          if (hasBreakfast)
                            _AmenityChip(
                              icon: Icons.free_breakfast_outlined,
                              label: l.poiAttr_breakfast,
                              scheme: scheme,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Tokens.space8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: isPicked
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 16, color: scheme.primary),
                                const SizedBox(width: Tokens.space4),
                                Text(
                                  l.poiPickerSelected,
                                  style: t.labelSmall
                                      ?.copyWith(color: scheme.primary),
                                ),
                              ],
                            )
                          : FilledButton.tonal(
                              onPressed: onPick,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Tokens.space12,
                                  vertical: Tokens.space4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l.poiPickerChoose,
                                style: t.labelSmall,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Restaurant picker
// ---------------------------------------------------------------------------

class _RestaurantPickerSheet extends StatefulWidget {
  const _RestaurantPickerSheet({
    required this.title,
    required this.entries,
    required this.onPicked,
  });

  final String title;
  final List<(Restaurant, double)> entries;
  final void Function(Restaurant) onPicked;

  @override
  State<_RestaurantPickerSheet> createState() => _RestaurantPickerSheetState();
}

class _RestaurantPickerSheetState extends State<_RestaurantPickerSheet> {
  bool _mapRendered = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _mapRendered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    final entries = widget.entries;
    final title = widget.title;
    final onPicked = widget.onPicked;

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Tokens.space24),
        child: Center(child: Text(l.daySleepHotelsNotFound)),
      );
    }

    // Build map points from restaurant coordinates
    final mapPoints = entries
        .map((e) => ll.LatLng(e.$1.coordinate.lat, e.$1.coordinate.lon))
        .toList();
    const minSpan = 0.02;
    final center = mapPoints.isEmpty
        ? ll.LatLng(0, 0)
        : ll.LatLng(
            mapPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                mapPoints.length,
            mapPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                mapPoints.length,
          );
    var bounds = mapPoints.length > 1
        ? fmap.LatLngBounds.fromPoints(mapPoints)
        : fmap.LatLngBounds(
            ll.LatLng(center.latitude - minSpan / 2,
                center.longitude - minSpan / 2),
            ll.LatLng(center.latitude + minSpan / 2,
                center.longitude + minSpan / 2),
          );
    final latSpan = bounds.north - bounds.south;
    final lonSpan = bounds.east - bounds.west;
    if (latSpan < minSpan || lonSpan < minSpan) {
      bounds = fmap.LatLngBounds(
        ll.LatLng(center.latitude - minSpan / 2,
            center.longitude - minSpan / 2),
        ll.LatLng(center.latitude + minSpan / 2,
            center.longitude + minSpan / 2),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Tokens.space20, 0, Tokens.space20, Tokens.space8),
            child: Text(title, style: t.titleMedium),
          ),
          // Overview map — restaurant pins (delayed render like hotel map)
          if (mapPoints.isNotEmpty && _mapRendered)
            SizedBox(
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space16),
                  child: Stack(
                    children: [
                      fmap.FlutterMap(
                    options: fmap.MapOptions(
                      initialCenter: center,
                      initialCameraFit: fmap.CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(32),
                        maxZoom: 15,
                      ),
                    ),
                    children: [
                      fmap.TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mytravelpal.travel',
                      ),
                      fmap.MarkerLayer(
                        markers: [
                          for (final (restaurant, _) in entries)
                            fmap.Marker(
                              point: ll.LatLng(restaurant.coordinate.lat,
                                  restaurant.coordinate.lon),
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.tertiary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.restaurant,
                                    size: 16,
                                    color: scheme.onTertiary),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _openFullscreenRestaurantMap(
                                context, mapPoints, center, scheme, l),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.fullscreen,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: Tokens.space8),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                  Tokens.space16, 0, Tokens.space16, Tokens.space24),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Tokens.space8),
              itemBuilder: (context, i) {
                final (restaurant, km) = entries[i];
                return _RestaurantCard(
                  restaurant: restaurant,
                  km: km,
                  onPick: () {
                    Navigator.of(context).pop();
                    onPicked(restaurant);
                  },
                  scheme: scheme,
                  t: t,
                  l: l,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreenRestaurantMap(
    BuildContext context,
    List<ll.LatLng> points,
    ll.LatLng center,
    ColorScheme scheme,
    AppLocalizations l,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(l.restaurantMapFullscreenTitle),
            backgroundColor: Colors.transparent,
          ),
          extendBodyBehindAppBar: true,
          body: fmap.FlutterMap(
            options: fmap.MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              fmap.TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mytravelpal.travel',
              ),
              fmap.MarkerLayer(
                markers: [
                  for (final pt in points)
                    fmap.Marker(
                      point: pt,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.restaurant,
                            size: 22, color: scheme.onTertiary),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({
    required this.restaurant,
    required this.km,
    required this.onPick,
    required this.scheme,
    required this.t,
    required this.l,
  });

  final Restaurant restaurant;
  final double km;
  final VoidCallback onPick;
  final ColorScheme scheme;
  final TextTheme t;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final cuisine = restaurant.attributes['cuisine'];
    final hasOutdoor = restaurant.attributes['outdoor_seating'] == 'yes';
    final hasDog = restaurant.attributes['dog'] == 'yes';
    final ratingRaw = restaurant.attributes['rating'];
    final rating = ratingRaw == null ? null : double.tryParse(ratingRaw);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PoiPhoto(
              size: 80,
              url: restaurant.photoUrl,
              fallbackIcon: Icons.restaurant_menu,
              color: scheme.tertiary,
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(width: Tokens.space4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: t.bodySmall?.copyWith(
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Tokens.space4),
                  Text(
                    '${restaurant.priceEurPerMeal.toStringAsFixed(0)} €/menú  ·  '
                    '${km.toStringAsFixed(1)} km',
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (cuisine != null || hasOutdoor || hasDog) ...[
                    const SizedBox(height: Tokens.space4),
                    Wrap(
                      spacing: Tokens.space4,
                      children: [
                        if (cuisine != null)
                          _AmenityChip(
                            icon: Icons.restaurant,
                            label: cuisine,
                            scheme: scheme,
                          ),
                        if (hasOutdoor)
                          _AmenityChip(
                            icon: Icons.outdoor_grill_outlined,
                            label: l.poiAttr_outdoorSeating,
                            scheme: scheme,
                          ),
                        if (hasDog)
                          _AmenityChip(
                            icon: Icons.pets,
                            label: l.poiAttr_dog,
                            scheme: scheme,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Tokens.space8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.map_outlined, size: 18),
                        tooltip: 'Ver en Maps',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _openRestaurantMaps(
                          context,
                          restaurant.coordinate.lat,
                          restaurant.coordinate.lon,
                        ),
                      ),
                      const SizedBox(width: Tokens.space8),
                      FilledButton.tonal(
                        onPressed: onPick,
                        child: Text(l.poiPickerChoose),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openRestaurantMaps(
    BuildContext context, double lat, double lon) async {
  final uri = Uri.parse('https://maps.google.com/?q=$lat,$lon&z=17');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Shows a network photo thumbnail when [url] is non-null, otherwise
/// falls back to a colored box with a centred icon.
class _PoiPhoto extends StatelessWidget {
  const _PoiPhoto({
    required this.size,
    required this.fallbackIcon,
    required this.color,
    this.url,
  });

  final double size;
  final String? url;
  final IconData fallbackIcon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Icon(fallbackIcon,
          size: size * 0.42, color: color.withValues(alpha: 0.6)),
    );

    if (url == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: t.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proximity helper (reused by callers that need to pre-sort)
// ---------------------------------------------------------------------------

const double _earthRadiusKm = 6371.0088;

/// Great-circle distance in km.
double poiPickerHaversineKm(LatLon a, LatLon b) {
  final lat1 = a.lat * math.pi / 180.0;
  final lat2 = b.lat * math.pi / 180.0;
  final dLat = (b.lat - a.lat) * math.pi / 180.0;
  final dLon = (b.lon - a.lon) * math.pi / 180.0;
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return _earthRadiusKm * 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
}

/// Return up to [maxCount] restaurants near [coord] within [maxKm],
/// sorted by distance.
List<(Restaurant, double)> restaurantsNear(
  List<Restaurant> all,
  LatLon coord, {
  double maxKm = 50.0,
  int maxCount = 8,
}) {
  final scored = <(Restaurant, double)>[];
  for (final r in all) {
    final km = poiPickerHaversineKm(coord, r.coordinate);
    if (km <= maxKm) scored.add((r, km));
  }
  scored.sort((a, b) => a.$2.compareTo(b.$2));
  return scored.take(maxCount).toList(growable: false);
}

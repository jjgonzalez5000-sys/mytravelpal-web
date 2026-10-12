import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import '../design/tokens.dart';
import '../services/maps_place_url.dart';
import 'osm_attribution.dart';

/// Icon + colour signal for each supported stop type. Kept in one
/// place so the marker on the map matches the tile / detail sheet the
/// user tapped from.
enum AddedStopKind { hotel, restaurant, fuel, place }

class AddedStop {
  const AddedStop({
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.coordinate,
    this.distanceFromOriginKm,
    this.onRemove,
    this.isAi = false,
    this.plannedAt,
    this.visitMinutes,
    this.onEditTime,
    this.attributes = const {},
  });

  final AddedStopKind kind;
  final String label;
  final String subtitle;
  final LatLon coordinate;

  /// Approximate km from trip origin along the route. Used by
  /// [DayPlanSection] to slot this stop into the correct day card.
  /// Null when it can't be estimated (no geometry available).
  final double? distanceFromOriginKm;

  /// Called when the user taps the X button on this stop.
  /// Wired by result_screen.dart to remove the stop from _addedStops.
  final VoidCallback? onRemove;

  /// The stop was suggested by the AI; the day plan marks it with a tag.
  final bool isAi;

  /// Approximate local time the driver plans to be there.
  final DateTime? plannedAt;
  final int? visitMinutes;

  /// Lets the driver move the stop to another time of the day.
  final VoidCallback? onEditTime;

  /// Place facts (Google ids, address) for the Maps button.
  final Map<String, String> attributes;

  IconData get icon => switch (kind) {
        AddedStopKind.hotel => Icons.hotel_outlined,
        AddedStopKind.restaurant => Icons.restaurant_outlined,
        AddedStopKind.fuel => Icons.local_gas_station,
        AddedStopKind.place => Icons.place_outlined,
      };
}

/// Show a bottom sheet with a map that plots the route and every stop
/// the driver has toggled "add to route". Tapping a marker pops a
/// callout with the stop name so the user can identify which of the
/// tiny pins corresponds to which POI they added upstream.
Future<void> showAddedStopsMapSheet(
  BuildContext context, {
  required List<AddedStop> stops,
  required LatLon origin,
  required LatLon destination,
  required List<LatLon> routeGeometry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddedStopsMapSheet(
      stops: stops,
      origin: origin,
      destination: destination,
      routeGeometry: routeGeometry,
    ),
  );
}

class _AddedStopsMapSheet extends StatefulWidget {
  const _AddedStopsMapSheet({
    required this.stops,
    required this.origin,
    required this.destination,
    required this.routeGeometry,
  });

  final List<AddedStop> stops;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;

  @override
  State<_AddedStopsMapSheet> createState() => _AddedStopsMapSheetState();
}

class _AddedStopsMapSheetState extends State<_AddedStopsMapSheet> {
  AddedStop? _selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final routePoints = widget.routeGeometry.isNotEmpty
        ? widget.routeGeometry
            .map((c) => LatLng(c.lat, c.lon))
            .toList(growable: false)
        : [
            LatLng(widget.origin.lat, widget.origin.lon),
            LatLng(widget.destination.lat, widget.destination.lon),
          ];

    // Camera fit: include route endpoints + every added stop so the
    // user sees the whole picture without pinch-to-zoom.
    final anchors = <LatLng>[
      LatLng(widget.origin.lat, widget.origin.lon),
      LatLng(widget.destination.lat, widget.destination.lon),
      for (final s in widget.stops) LatLng(s.coordinate.lat, s.coordinate.lon),
    ];
    final bounds = LatLngBounds.fromPoints(anchors);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => SafeArea(
        top: false,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            Tokens.space16, Tokens.space4, Tokens.space16, Tokens.space16,
          ),
          children: [
            Text(
              'Your added stops',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Tokens.space4),
            Text(
              widget.stops.length == 1
                  ? '1 stop on this route'
                  : '${widget.stops.length} stops on this route',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.space12),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(36),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mytravelpal.app',
                      maxZoom: 19,
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        _endpointMarker(
                          LatLng(widget.origin.lat, widget.origin.lon),
                          'A', scheme.primary,
                        ),
                        _endpointMarker(
                          LatLng(widget.destination.lat,
                              widget.destination.lon),
                          'B', scheme.primary,
                        ),
                        for (final s in widget.stops)
                          _stopMarker(s, scheme),
                      ],
                    ),
                    const OsmAttribution(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.space12),
            if (_selected != null)
              _StopCallout(
                stop: _selected!,
                onClose: () => setState(() => _selected = null),
                onRemove: () {
                  _selected!.onRemove?.call();
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: Tokens.space8),
            // Flat list of added stops as a legend / quick nav — tapping
            // one selects it on the map (centres callout).
            for (final s in widget.stops)
              _StopListRow(
                stop: s,
                selected: identical(_selected, s),
                onTap: () => setState(() => _selected = s),
              ),
          ],
        ),
      ),
    );
  }

  Marker _stopMarker(AddedStop stop, ColorScheme scheme) {
    final tint = switch (stop.kind) {
      AddedStopKind.hotel => scheme.tertiary,
      AddedStopKind.restaurant => scheme.tertiary,
      AddedStopKind.fuel => scheme.onSurfaceVariant,
      AddedStopKind.place => scheme.primary,
    };
    return Marker(
      point: LatLng(stop.coordinate.lat, stop.coordinate.lon),
      width: 36, height: 36,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => setState(() => _selected = stop),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(stop.icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Marker _endpointMarker(LatLng at, String label, Color color) => Marker(
        point: at,
        width: 28, height: 28,
        alignment: Alignment.topCenter,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class _StopCallout extends StatelessWidget {
  const _StopCallout({
    required this.stop,
    required this.onClose,
    required this.onRemove,
  });

  final AddedStop stop;
  final VoidCallback onClose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stop.icon, color: scheme.primary),
          const SizedBox(width: Tokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.label,
                    style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                if (stop.subtitle.isNotEmpty)
                  Text(stop.subtitle,
                      style: t.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in Google Maps',
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => openPlaceInMaps(
              context,
              mapsPlaceFromAttributes(
                name: stop.label,
                coordinate: stop.coordinate,
                attributes: stop.attributes,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar parada',
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _StopListRow extends StatelessWidget {
  const _StopListRow({
    required this.stop,
    required this.selected,
    required this.onTap,
  });

  final AddedStop stop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space8, vertical: Tokens.space8,
        ),
        child: Row(
          children: [
            Icon(
              stop.icon,
              size: 20,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Tokens.space12),
            Expanded(
              child: Text(
                stop.label,
                style: t.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              stop.subtitle,
              style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

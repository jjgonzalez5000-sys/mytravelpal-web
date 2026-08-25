import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';

/// Show a bottom sheet with the event details and a mini-map plotting
/// the incident inside the trip's route so the user sees at a glance
/// where along their drive it lands.
Future<void> showAdverseEventSheet(
  BuildContext context, {
  required AdverseEvent event,
  required LatLon origin,
  required LatLon destination,
  required List<LatLon> routeGeometry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AdverseEventSheet(
      event: event,
      origin: origin,
      destination: destination,
      routeGeometry: routeGeometry,
    ),
  );
}

class _AdverseEventSheet extends StatelessWidget {
  const _AdverseEventSheet({
    required this.event,
    required this.origin,
    required this.destination,
    required this.routeGeometry,
  });

  final AdverseEvent event;
  final LatLon origin;
  final LatLon destination;
  final List<LatLon> routeGeometry;

  Color _severityColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (event.severity) {
      AdverseEventSeverity.critical => scheme.error,
      AdverseEventSeverity.warning => scheme.tertiary,
      AdverseEventSeverity.info => scheme.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = _severityColor(context);
    final points = _routePoints();
    final eventPoint = LatLng(event.coordinate.lat, event.coordinate.lon);
    // Camera fit: event + a bit of the route around it so the user
    // sees both context and precise location.
    final bounds = _fitBounds(eventPoint, points);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(event.type.icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.type.displayName, style: t.titleLarge),
                      Text(
                        event.severity.displayName,
                        style: t.labelSmall
                            ?.copyWith(color: color, letterSpacing: 1.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(32),
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
                        polylines: _splitPolylineAroundEvent(
                          points: points,
                          event: eventPoint,
                          baseColor: scheme.primary,
                          accentColor: color,
                        ),
                      ),
                    MarkerLayer(
                      markers: [
                        _endpointMarker(
                          LatLng(origin.lat, origin.lon), 'A', scheme.primary,
                        ),
                        _endpointMarker(
                          LatLng(destination.lat, destination.lon), 'B',
                          scheme.primary,
                        ),
                        Marker(
                          point: eventPoint,
                          width: 40, height: 40,
                          alignment: Alignment.topCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
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
                            child: Icon(
                              event.type.icon, color: Colors.white, size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(event.description, style: t.bodyMedium),
            const SizedBox(height: 8),
            Text(
              _timeFootnote(),
              style: t.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
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

  /// Split the route polyline into three visual segments: `before`
  /// (route up to just before the event), `near` (a window centred on
  /// the event, rendered in the severity accent + thicker), and
  /// `after` (the rest of the route back in the base colour). Users
  /// see at a glance which stretch of their drive is affected without
  /// hunting for a lone marker.
  static List<Polyline> _splitPolylineAroundEvent({
    required List<LatLng> points,
    required LatLng event,
    required Color baseColor,
    required Color accentColor,
  }) {
    if (points.length < 3) {
      return [
        Polyline(points: points, strokeWidth: 3, color: baseColor),
      ];
    }
    // Nearest point index — same cheap L1 metric we use elsewhere.
    var nearest = 0;
    double best = (points[0].latitude - event.latitude).abs() +
        (points[0].longitude - event.longitude).abs();
    for (var i = 1; i < points.length; i++) {
      final d = (points[i].latitude - event.latitude).abs() +
          (points[i].longitude - event.longitude).abs();
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    // Window: ±4 samples or ~8 % of total length, whichever is larger,
    // so long routes get a proportional accent band and short ones a
    // sensible minimum.
    final radius = (points.length * 0.04).round().clamp(4, 12);
    final lo = (nearest - radius).clamp(0, points.length - 1);
    final hi = (nearest + radius).clamp(0, points.length - 1);
    final polylines = <Polyline>[];
    if (lo > 0) {
      polylines.add(Polyline(
        points: points.sublist(0, lo + 1),
        strokeWidth: 3,
        color: baseColor,
      ));
    }
    polylines.add(Polyline(
      points: points.sublist(lo, hi + 1),
      strokeWidth: 5,
      color: accentColor,
    ));
    if (hi < points.length - 1) {
      polylines.add(Polyline(
        points: points.sublist(hi, points.length),
        strokeWidth: 3,
        color: baseColor,
      ));
    }
    return polylines;
  }

  /// Fit around the event with a slice of the route on either side so
  /// the user sees where it lands relative to the drive. We include
  /// the nearest ~8 route points to the event and always the endpoints
  /// as anchors; then bounds cover all of them.
  LatLngBounds _fitBounds(LatLng event, List<LatLng> route) {
    final anchors = <LatLng>{event};
    if (route.isNotEmpty) {
      // Find nearest route index to the event; include ±4 samples.
      var nearestIndex = 0;
      double nearestDelta =
          (route[0].latitude - event.latitude).abs() +
              (route[0].longitude - event.longitude).abs();
      for (var i = 1; i < route.length; i++) {
        final d =
            (route[i].latitude - event.latitude).abs() +
                (route[i].longitude - event.longitude).abs();
        if (d < nearestDelta) {
          nearestDelta = d;
          nearestIndex = i;
        }
      }
      final lo = (nearestIndex - 4).clamp(0, route.length - 1);
      final hi = (nearestIndex + 4).clamp(0, route.length - 1);
      anchors.addAll(route.sublist(lo, hi + 1));
    }
    return LatLngBounds.fromPoints(anchors.toList());
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

  String _timeFootnote() {
    final fmt = DateFormat('d MMM · HH:mm');
    return 'Reported ${fmt.format(event.reportedAt.toLocal())}';
  }
}

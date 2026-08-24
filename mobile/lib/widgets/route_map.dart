import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.mytravelpal.app';

/// Map showing the planned route.
///
/// - When `geometry` has points, we draw the real road-following polyline
///   (OSRM / HERE / TomTom output).
/// - Otherwise we fall back to a dashed straight line between origin and
///   destination so the user still gets a visual — the mock backend is
///   honest about being an approximation.
/// - An optional `alternativeGeometry` is drawn dimmed for comparison
///   (used by the toll-savings preview).
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.destination,
    this.geometry = const [],
    this.alternativeGeometry = const [],
  });

  final LatLon origin;
  final LatLon destination;
  final List<LatLon> geometry;
  final List<LatLon> alternativeGeometry;

  @override
  Widget build(BuildContext context) {
    final o = LatLng(origin.lat, origin.lon);
    final d = LatLng(destination.lat, destination.lon);
    final scheme = Theme.of(context).colorScheme;

    final hasReal = geometry.isNotEmpty;
    final main = hasReal
        ? geometry.map((p) => LatLng(p.lat, p.lon)).toList(growable: false)
        : <LatLng>[o, d];
    final alt = alternativeGeometry
        .map((p) => LatLng(p.lat, p.lon))
        .toList(growable: false);

    final boundsPoints = [
      ...main,
      ...alt,
      if (main.isEmpty) o,
      if (main.isEmpty) d,
    ];

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(boundsPoints),
          padding: const EdgeInsets.all(40),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: _userAgent,
          maxZoom: 19,
        ),
        if (alt.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: alt,
                strokeWidth: 3,
                color: scheme.tertiary.withValues(alpha: 0.7),
                pattern: StrokePattern.dashed(segments: const [8, 6]),
              ),
            ],
          ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: main,
              strokeWidth: hasReal ? 4 : 3,
              color: scheme.primary,
              pattern: hasReal
                  ? const StrokePattern.solid()
                  : StrokePattern.dashed(segments: const <double>[8, 6]),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            _endpoint(o, 'A', scheme),
            _endpoint(d, 'B', scheme),
          ],
        ),
      ],
    );
  }

  Marker _endpoint(LatLng at, String label, ColorScheme scheme) {
    return Marker(
      point: at,
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: _EndpointPin(label: label, color: scheme.primary),
    );
  }
}

class _EndpointPin extends StatelessWidget {
  const _EndpointPin({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';

/// OpenStreetMap raster tiles. Free, no key needed, adequate for the MVP.
/// Swap to HERE/TomTom tiles once a paid provider is contracted.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.mytravelpal.app';

class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.destination,
  });

  final LatLon origin;
  final LatLon destination;

  @override
  Widget build(BuildContext context) {
    final o = LatLng(origin.lat, origin.lon);
    final d = LatLng(destination.lat, destination.lon);
    final scheme = Theme.of(context).colorScheme;

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([o, d]),
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
        PolylineLayer(
          polylines: [
            Polyline(
              points: [o, d],
              strokeWidth: 3,
              color: scheme.primary,
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


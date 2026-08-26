import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import 'osm_attribution.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.mytravelpal.app';

class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.destination,
    this.geometry = const [],
    this.alternativeGeometry = const [],
    this.hotelMarkers = const [],
    this.restaurantMarkers = const [],
    this.tollMarkers = const [],
  });

  final LatLon origin;
  final LatLon destination;
  final List<LatLon> geometry;
  final List<LatLon> alternativeGeometry;
  final List<Hotel> hotelMarkers;
  final List<Restaurant> restaurantMarkers;
  final List<PartialTollSkip> tollMarkers;

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

    final poiMarkers = <Marker>[
      for (final h in hotelMarkers)
        _poiMarker(
          LatLng(h.coordinate.lat, h.coordinate.lon),
          Icons.hotel_outlined,
          scheme.tertiary,
        ),
      for (final r in restaurantMarkers)
        _poiMarker(
          LatLng(r.coordinate.lat, r.coordinate.lon),
          Icons.restaurant_outlined,
          scheme.primary,
        ),
      for (final t in tollMarkers)
        _poiMarker(
          LatLng(t.coordinate.lat, t.coordinate.lon),
          Icons.alt_route,
          scheme.error,
        ),
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
        if (poiMarkers.isNotEmpty) MarkerLayer(markers: poiMarkers),
        MarkerLayer(
          markers: [
            _endpoint(o, 'A', scheme),
            _endpoint(d, 'B', scheme),
          ],
        ),
        const OsmAttribution(),
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

  Marker _poiMarker(LatLng at, IconData icon, Color color) {
    return Marker(
      point: at,
      width: 28,
      height: 28,
      child: _PoiPin(icon: icon, color: color),
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

class _PoiPin extends StatelessWidget {
  const _PoiPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

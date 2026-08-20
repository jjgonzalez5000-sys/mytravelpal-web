import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/models.dart';

/// Free demo tiles from OpenFreeMap. Replace with HERE/TomTom tiles when a
/// paid provider is contracted.
const _mapStyle = 'https://tiles.openfreemap.org/styles/liberty';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.destination,
  });

  final LatLon origin;
  final LatLon destination;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final midLat = (widget.origin.lat + widget.destination.lat) / 2;
    final midLon = (widget.origin.lon + widget.destination.lon) / 2;
    return MapLibreMap(
      styleString: _mapStyle,
      initialCameraPosition: CameraPosition(
        target: LatLng(midLat, midLon),
        zoom: 5,
      ),
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: _addMarkers,
    );
  }

  Future<void> _addMarkers() async {
    final c = _controller;
    if (c == null) return;
    await c.addSymbol(SymbolOptions(
      geometry: LatLng(widget.origin.lat, widget.origin.lon),
      iconImage: 'marker-15',
      textField: 'A',
      textOffset: const Offset(0, 1.2),
    ));
    await c.addSymbol(SymbolOptions(
      geometry: LatLng(widget.destination.lat, widget.destination.lon),
      iconImage: 'marker-15',
      textField: 'B',
      textOffset: const Offset(0, 1.2),
    ));
    await c.addLine(LineOptions(
      geometry: [
        LatLng(widget.origin.lat, widget.origin.lon),
        LatLng(widget.destination.lat, widget.destination.lon),
      ],
      lineWidth: 3.0,
      lineColor: '#1F6FEB',
    ));
  }
}

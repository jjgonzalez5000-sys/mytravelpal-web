import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/models.dart';
import 'osm_attribution.dart';
import 'poi_detail_sheet.dart';

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _userAgent = 'com.mytravelpal.app';

/// The layers the driver can toggle on/off. Each corresponds to a
/// distinct marker set the parent passes in.
enum MapLayer { hotels, restaurants, fuel, adverseEvents, tollSkips }

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.origin,
    required this.destination,
    this.geometry = const [],
    this.alternativeGeometry = const [],
    this.hotelMarkers = const [],
    this.restaurantMarkers = const [],
    this.tollMarkers = const [],
    this.fuelMarkers = const [],
    this.adverseEventMarkers = const [],
    this.enabledLayers,
  });

  final LatLon origin;
  final LatLon destination;
  final List<LatLon> geometry;
  final List<LatLon> alternativeGeometry;
  final List<Hotel> hotelMarkers;
  final List<Restaurant> restaurantMarkers;
  final List<PartialTollSkip> tollMarkers;

  /// Fuel stations to plot as markers. Caller sends the top-N
  /// cheapest so we don't drown the map in stations; the layer
  /// toggle still lets the driver hide them.
  final List<FuelPrice> fuelMarkers;

  /// Live adverse events (fires, strikes, closures) with a
  /// coordinate — rendered with a red warning pin.
  final List<AdverseEvent> adverseEventMarkers;

  /// Which layers start visible. When null, all layers with
  /// content are on by default. Pass an empty set to start
  /// everything hidden.
  final Set<MapLayer>? enabledLayers;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  late Set<MapLayer> _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabledLayers ??
        {
          if (widget.hotelMarkers.isNotEmpty) MapLayer.hotels,
          if (widget.restaurantMarkers.isNotEmpty) MapLayer.restaurants,
          if (widget.fuelMarkers.isNotEmpty) MapLayer.fuel,
          if (widget.adverseEventMarkers.isNotEmpty)
            MapLayer.adverseEvents,
          if (widget.tollMarkers.isNotEmpty) MapLayer.tollSkips,
        };
  }

  void _toggle(MapLayer layer) {
    setState(() {
      if (_enabled.contains(layer)) {
        _enabled.remove(layer);
      } else {
        _enabled.add(layer);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = LatLng(widget.origin.lat, widget.origin.lon);
    final d = LatLng(widget.destination.lat, widget.destination.lon);
    final scheme = Theme.of(context).colorScheme;

    final hasReal = widget.geometry.isNotEmpty;
    final main = hasReal
        ? widget.geometry.map((p) => LatLng(p.lat, p.lon)).toList(
            growable: false,
          )
        : <LatLng>[o, d];
    final alt = widget.alternativeGeometry
        .map((p) => LatLng(p.lat, p.lon))
        .toList(growable: false);

    final boundsPoints = [
      ...main,
      ...alt,
      if (main.isEmpty) o,
      if (main.isEmpty) d,
    ];

    final poiMarkers = <Marker>[
      if (_enabled.contains(MapLayer.hotels))
        for (final h in widget.hotelMarkers)
          _tappablePoiMarker(
            context,
            LatLng(h.coordinate.lat, h.coordinate.lon),
            Icons.hotel_outlined,
            scheme.tertiary,
            () => showPoiDetailSheet(
              context,
              kind: PoiKind.hotel,
              name: h.name,
              subtitle: '${h.priceEurPerNight.toStringAsFixed(0)} €/night',
              poi: h.coordinate,
              origin: widget.origin,
              destination: widget.destination,
              routeGeometry: widget.geometry,
              attributes: h.attributes,
              icon: Icons.hotel_outlined,
              accent: scheme.tertiary,
            ),
          ),
      if (_enabled.contains(MapLayer.restaurants))
        for (final r in widget.restaurantMarkers)
          _tappablePoiMarker(
            context,
            LatLng(r.coordinate.lat, r.coordinate.lon),
            Icons.restaurant_outlined,
            scheme.primary,
            () => showPoiDetailSheet(
              context,
              kind: PoiKind.restaurant,
              name: r.name,
              subtitle: '${r.priceEurPerMeal.toStringAsFixed(0)} €/meal',
              poi: r.coordinate,
              origin: widget.origin,
              destination: widget.destination,
              routeGeometry: widget.geometry,
              attributes: r.attributes,
              icon: Icons.restaurant_outlined,
              accent: scheme.primary,
            ),
          ),
      if (_enabled.contains(MapLayer.fuel))
        for (final f in widget.fuelMarkers)
          if (f.coordinate != null)
            _tappablePoiMarker(
              context,
              LatLng(f.coordinate!.lat, f.coordinate!.lon),
              f.isChargingStation
                  ? Icons.ev_station
                  : Icons.local_gas_station,
              // Green when this station is below its country
              // median (savings positive); neutral surface
              // when the field isn't populated by the backend.
              (f.savingsVsCountryMedianEurPerL != null &&
                      f.savingsVsCountryMedianEurPerL! > 0)
                  ? Colors.green.shade600
                  : scheme.secondary,
              () => showPoiDetailSheet(
                context,
                kind: PoiKind.fuel,
                name: f.stationName,
                subtitle: f.priceAvailable
                    ? '${f.priceEurPerL.toStringAsFixed(3)} ${f.unitLabel}'
                    : '${f.distanceFromOriginKm.toStringAsFixed(0)} km',
                poi: f.coordinate!,
                origin: widget.origin,
                destination: widget.destination,
                routeGeometry: widget.geometry,
                attributes: f.attributes,
                icon: Icons.local_gas_station,
                accent: scheme.secondary,
              ),
            ),
      if (_enabled.contains(MapLayer.adverseEvents))
        for (final e in widget.adverseEventMarkers)
          _poiMarker(
            LatLng(e.coordinate.lat, e.coordinate.lon),
            Icons.warning_amber_outlined,
            scheme.error,
          ),
      if (_enabled.contains(MapLayer.tollSkips))
        for (final t in widget.tollMarkers)
          _poiMarker(
            LatLng(t.coordinate.lat, t.coordinate.lon),
            Icons.alt_route,
            scheme.error,
          ),
    ];

    return Stack(
      children: [
        FlutterMap(
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
        ),
        // Layer picker chip in the top-right corner. Only shown
        // when there's at least one layer with content — a bare
        // trip with no POIs, events or fuel stations gets a clean
        // map with no floating UI.
        if (_hasAnyLayer())
          Positioned(
            top: 8,
            right: 8,
            child: _LayerPicker(
              enabled: _enabled,
              available: _availableLayers(),
              onToggle: _toggle,
            ),
          ),
      ],
    );
  }

  bool _hasAnyLayer() =>
      widget.hotelMarkers.isNotEmpty ||
      widget.restaurantMarkers.isNotEmpty ||
      widget.fuelMarkers.isNotEmpty ||
      widget.adverseEventMarkers.isNotEmpty ||
      widget.tollMarkers.isNotEmpty;

  Set<MapLayer> _availableLayers() => {
        if (widget.hotelMarkers.isNotEmpty) MapLayer.hotels,
        if (widget.restaurantMarkers.isNotEmpty) MapLayer.restaurants,
        if (widget.fuelMarkers.isNotEmpty) MapLayer.fuel,
        if (widget.adverseEventMarkers.isNotEmpty) MapLayer.adverseEvents,
        if (widget.tollMarkers.isNotEmpty) MapLayer.tollSkips,
      };

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

  Marker _tappablePoiMarker(
    BuildContext context,
    LatLng at,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Marker(
      point: at,
      width: 32,
      height: 32,
      child: GestureDetector(
        onTap: onTap,
        child: _PoiPin(icon: icon, color: color),
      ),
    );
  }
}

/// Small floating button that opens a checkbox popup where the
/// driver picks which marker layers to display. Placed as a chip
/// so it doesn't cover the endpoint pins.
class _LayerPicker extends StatelessWidget {
  const _LayerPicker({
    required this.enabled,
    required this.available,
    required this.onToggle,
  });
  final Set<MapLayer> enabled;
  final Set<MapLayer> available;
  final ValueChanged<MapLayer> onToggle;

  IconData _iconFor(MapLayer l) => switch (l) {
        MapLayer.hotels => Icons.hotel_outlined,
        MapLayer.restaurants => Icons.restaurant_outlined,
        MapLayer.fuel => Icons.local_gas_station,
        MapLayer.adverseEvents => Icons.warning_amber_outlined,
        MapLayer.tollSkips => Icons.alt_route,
      };

  String _labelFor(MapLayer l) => switch (l) {
        MapLayer.hotels => 'Hoteles',
        MapLayer.restaurants => 'Restaurantes',
        MapLayer.fuel => 'Gasolineras',
        MapLayer.adverseEvents => 'Alertas',
        MapLayer.tollSkips => 'Saltos de peaje',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: PopupMenuButton<MapLayer>(
        tooltip: 'Capas',
        icon: Icon(Icons.layers_outlined, color: scheme.primary),
        onSelected: onToggle,
        itemBuilder: (context) => [
          for (final l in available)
            CheckedPopupMenuItem<MapLayer>(
              value: l,
              checked: enabled.contains(l),
              child: Row(
                children: [
                  Icon(_iconFor(l), size: 18, color: scheme.onSurface),
                  const SizedBox(width: 8),
                  Text(_labelFor(l)),
                ],
              ),
            ),
        ],
      ),
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

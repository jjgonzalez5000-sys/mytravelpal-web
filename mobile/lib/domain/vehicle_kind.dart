import 'dart:convert';

import 'package:flutter/material.dart';

import 'trip_profile.dart' show FuelType, VehicleType;

/// What kind of vehicle a garage entry is. Broader than [VehicleType], which
/// is what the server plans with: a truck has no server type yet.
enum VehicleKind {
  car('car', Icons.directions_car),
  motorbike('motorbike', Icons.two_wheeler),
  van('van', Icons.airport_shuttle),
  camper('camper', Icons.rv_hookup),
  truck('truck', Icons.local_shipping);

  const VehicleKind(this.code, this.icon);
  final String code;
  final IconData icon;

  static VehicleKind fromCode(String? c) =>
      values.firstWhere((k) => k.code == c, orElse: () => VehicleKind.car);

  /// The type sent to the server. It has no truck type, so a truck is
  /// planned as a van (the closest it can do for now).
  VehicleType get planningType => switch (this) {
        VehicleKind.car => VehicleType.car,
        VehicleKind.motorbike => VehicleType.motorbike,
        VehicleKind.van => VehicleType.van,
        VehicleKind.camper => VehicleType.camper,
        VehicleKind.truck => VehicleType.van,
      };

  /// Height, length and weight matter (bridges, tunnels, ferries, tolls).
  bool get needsDimensions =>
      this == VehicleKind.van ||
      this == VehicleKind.camper ||
      this == VehicleKind.truck;

  /// The catalogue only lists cars.
  bool get hasCatalogue => this == VehicleKind.car;
}

/// Everything a garage entry knows about its vehicle beyond name and tank
/// level, stored as compact JSON in the entry's `notes` (the server keeps it
/// as an opaque string of at most 280 characters).
///
/// Keys: k kind, f fuel type, t tank L (or battery kWh), c consumption per
/// 100 km, h height m, l length m, w weight t, a axles. `f`, `t` and `c`
/// were already used by custom vehicles, so older entries still read.
@immutable
class VehicleSpecs {
  const VehicleSpecs({
    this.kind = VehicleKind.car,
    this.fuelType,
    this.tankL,
    this.consumptionL100km,
    this.heightM,
    this.lengthM,
    this.weightT,
    this.axles,
  });

  final VehicleKind kind;
  final FuelType? fuelType;

  /// Litres, or kWh for an electric vehicle.
  final double? tankL;

  /// L/100 km, or kWh/100 km for an electric vehicle.
  final double? consumptionL100km;
  final double? heightM;
  final double? lengthM;
  final double? weightT;
  final int? axles;

  bool get hasEngineSpecs => tankL != null && consumptionL100km != null;

  String toNotes() {
    String n(double v) => v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(1);
    return jsonEncode({
      'k': kind.code,
      if (fuelType != null) 'f': fuelType!.name,
      if (tankL != null) 't': double.parse(n(tankL!)),
      if (consumptionL100km != null) 'c': double.parse(n(consumptionL100km!)),
      if (heightM != null) 'h': double.parse(n(heightM!)),
      if (lengthM != null) 'l': double.parse(n(lengthM!)),
      if (weightT != null) 'w': double.parse(n(weightT!)),
      if (axles != null) 'a': axles,
    });
  }

  /// Tolerant: null, an empty string, free text or a half-filled object all
  /// give a plain car with no specs.
  factory VehicleSpecs.fromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return const VehicleSpecs();
    try {
      final m = jsonDecode(notes);
      if (m is! Map<String, dynamic>) return const VehicleSpecs();
      double? d(String k) => (m[k] as num?)?.toDouble();
      final fuel = m['f'] as String?;
      return VehicleSpecs(
        kind: VehicleKind.fromCode(m['k'] as String?),
        fuelType: fuel == null
            ? null
            : FuelType.values.cast<FuelType?>().firstWhere(
                  (e) => e!.name == fuel,
                  orElse: () => null,
                ),
        tankL: d('t'),
        consumptionL100km: d('c'),
        heightM: d('h'),
        lengthM: d('l'),
        weightT: d('w'),
        axles: (m['a'] as num?)?.toInt(),
      );
    } catch (_) {
      return const VehicleSpecs();
    }
  }
}

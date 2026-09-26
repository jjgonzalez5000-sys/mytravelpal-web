import 'package:flutter/foundation.dart';

import 'trip_profile.dart' show FuelType;

/// Mirror of the backend `VehicleModel` catalogue entry.
///
/// Fetched from `/v1/vehicles` on cold-start and cached client-side by
/// a Riverpod `FutureProvider`. The user picks their model in
/// `VehiclePickerScreen`; the id lands in `TripProfile.vehicleModelId`
/// and rides on every plan request so the backend can substitute the
/// catalogue's tank + consumption for the profile sliders and compute
/// the refuel window.
@immutable
class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.make,
    required this.model,
    required this.yearFrom,
    required this.yearTo,
    required this.fuelType,
    required this.tankLiters,
    required this.consumptionL100km,
  });

  final String id;
  final String make;
  final String model;
  final int yearFrom;
  final int? yearTo;
  final FuelType fuelType;
  final double tankLiters;
  final double consumptionL100km;

  /// Rendered in the picker row and next to the "Modelo" field.
  /// Example: "Golf 8 · 2019+ · Petrol · 50 L · 6.5 L/100km".
  String get shortLabel {
    final years = yearTo == null ? '$yearFrom+' : '$yearFrom-$yearTo';
    return '$model · $years · ${fuelType.label} · '
        '${tankLiters.toStringAsFixed(0)} L · '
        '${consumptionL100km.toStringAsFixed(1)} L/100km';
  }

  factory VehicleModel.fromJson(Map<String, dynamic> j) => VehicleModel(
        id: j['id'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        yearFrom: (j['year_from'] as num).toInt(),
        yearTo: (j['year_to'] as num?)?.toInt(),
        fuelType: FuelType.fromCode(j['fuel_type'] as String? ?? 'petrol'),
        tankLiters: (j['tank_liters'] as num).toDouble(),
        consumptionL100km: (j['consumption_l100km'] as num).toDouble(),
      );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/garage_vehicle.dart';
import '../domain/trip_profile.dart';
import '../domain/vehicle_model.dart';
import '../providers.dart';
import '../screens/vehicle_picker_screen.dart' show kCustomVehicleId;

// What /v1/trips/plan accepts for a vehicle (VehicleIn). Anything beyond
// these is clamped here, because the server answers 422 and the trip could
// not be planned at all.
const double kMaxTankL = 1000;
const double kMaxConsumptionL100 = 80;
const double kMaxConsumptionKwh100 = 150;
const double kMaxEvRangeKm = 1500;

double _clamp(double v, double max) => v < 0 ? 0 : (v > max ? max : v);

/// The garage vehicle a trip is planned for: the one picked for the trip, or
/// else the first one, which is the one the plan screen shows as active.
GarageVehicle? activeGarageVehicle(WidgetRef ref) {
  final garage = ref.read(garageProvider);
  if (garage.isEmpty) return null;
  final selected = ref.read(selectedGarageVehicleIdProvider);
  return garage.where((v) => v.id == selected).firstOrNull ?? garage.first;
}

/// The profile this trip is planned with: [override] (a per-trip override)
/// or the saved profile, with the active garage vehicle on top. Plan and
/// re-plan both use it, so a vehicle never silently falls back to the saved
/// one.
TripProfile? effectiveTripProfile(WidgetRef ref, {TripProfile? override}) {
  final base = override ?? ref.read(tripProfileProvider);
  final vehicle = activeGarageVehicle(ref);
  if (vehicle == null) return base;
  VehicleModel? model;
  if (vehicle.modelId != kCustomVehicleId) {
    final catalogue = ref.read(vehicleCatalogueProvider).valueOrNull;
    model = catalogue?.where((m) => m.id == vehicle.modelId).firstOrNull;
  }
  return applyGarageVehicle(
    base ?? const TripProfile(),
    vehicle,
    catalogueModel: model,
  );
}

/// The trip profile with the chosen garage vehicle applied: its type
/// (car, motorbike, van, camper, truck planned as a van) and its engine
/// figures: the ones the driver typed in for a custom vehicle, or the
/// catalogue model's when [catalogueModel] is given. The garage entry's
/// starting tank level fills the profile's only when the profile has none.
TripProfile applyGarageVehicle(
  TripProfile base,
  GarageVehicle v, {
  VehicleModel? catalogueModel,
}) {
  final specs = v.specs;
  var vehicle = base.vehicle.copyWith(type: specs.kind.planningType);

  FuelType? fuel;
  double? tank;
  double? perHundred;
  if (v.modelId == kCustomVehicleId && specs.hasEngineSpecs) {
    fuel = specs.fuelType ?? vehicle.fuelType;
    tank = specs.tankL;
    perHundred = specs.consumptionL100km;
  } else if (catalogueModel != null) {
    fuel = catalogueModel.fuelType;
    tank = catalogueModel.tankLiters > 0 ? catalogueModel.tankLiters : null;
    perHundred = catalogueModel.consumptionL100km > 0
        ? catalogueModel.consumptionL100km
        : null;
  }

  if (fuel != null && tank != null && perHundred != null) {
    if (fuel == FuelType.electric) {
      // Tank is the battery in kWh and the consumption is kWh/100 km.
      final kwh100 = _clamp(perHundred, kMaxConsumptionKwh100);
      vehicle = vehicle.copyWith(
        fuelType: fuel,
        consumptionKwhPer100km: kwh100,
        evRangeKm: kwh100 > 0
            ? _clamp(tank / kwh100 * 100, kMaxEvRangeKm)
            : null,
      );
    } else {
      vehicle = vehicle.copyWith(
        fuelType: fuel,
        fuelTankL: _clamp(tank, kMaxTankL),
        consumptionLPer100km: _clamp(perHundred, kMaxConsumptionL100),
      );
    }
  }

  return base.copyWith(
    vehicle: vehicle,
    vehicleModelId: v.modelId,
    currentTankLevelPercent:
        base.currentTankLevelPercent ?? v.defaultTankPercent,
  );
}

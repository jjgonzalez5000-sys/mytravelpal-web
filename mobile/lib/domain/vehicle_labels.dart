import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'trip_profile.dart';

/// Localised labels for [VehicleType]/[FuelType].
///
/// Kept out of the enums so the enum definitions stay context-free (no
/// dependency on the l10n code that gets regenerated on every ARB
/// change). Widgets that need to show one call these helpers with the
/// build context; the enum's own `label` field remains as an English
/// fallback for logging and for places without a context handy.
String vehicleTypeLabel(BuildContext context, VehicleType type) {
  final l = AppLocalizations.of(context);
  return switch (type) {
    VehicleType.car => l.vehicleTypeCar,
    VehicleType.motorbike => l.vehicleTypeMotorbike,
    VehicleType.van => l.vehicleTypeVan,
    VehicleType.camper => l.vehicleTypeCamper,
  };
}

String fuelTypeLabel(BuildContext context, FuelType type) {
  final l = AppLocalizations.of(context);
  return switch (type) {
    FuelType.petrol => l.fuelTypePetrol,
    FuelType.diesel => l.fuelTypeDiesel,
    FuelType.hybrid => l.fuelTypeHybrid,
    FuelType.electric => l.fuelTypeElectric,
    FuelType.lpg => l.fuelTypeLpg,
  };
}

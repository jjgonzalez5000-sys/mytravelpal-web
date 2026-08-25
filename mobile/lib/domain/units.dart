/// User-selectable unit system for displayed measurements.
///
/// Backend always speaks metric; we convert at the presentation layer
/// so switching systems doesn't require re-planning the trip.
enum UnitSystem {
  metric,
  imperial;

  String get code => name;

  static UnitSystem fromCode(String? code) => switch (code) {
        'imperial' => UnitSystem.imperial,
        _ => UnitSystem.metric,
      };
}

/// Formatter helpers scoped to a specific unit system. Kept as an
/// immutable value so widgets can pass one around instead of threading
/// the enum through every callsite.
class UnitFormatter {
  const UnitFormatter(this.system);
  final UnitSystem system;

  bool get isImperial => system == UnitSystem.imperial;

  /// Kilometres → localised distance string.
  String distance(double km, {int fractionDigits = 0}) {
    if (isImperial) {
      final miles = km * 0.621371;
      return '${miles.toStringAsFixed(fractionDigits)} mi';
    }
    return '${km.toStringAsFixed(fractionDigits)} km';
  }

  /// Litres of fuel → localised volume string.
  String fuelVolume(double litres, {int fractionDigits = 1}) {
    if (isImperial) {
      final gallons = litres * 0.264172;
      return '${gallons.toStringAsFixed(fractionDigits)} gal';
    }
    return '${litres.toStringAsFixed(fractionDigits)} L';
  }

  /// L/100 km ↔ US MPG.
  String consumptionFuel(double lPer100km) {
    if (isImperial) {
      if (lPer100km <= 0) return '—';
      final mpg = 235.214583 / lPer100km;
      return '${mpg.toStringAsFixed(0)} mpg';
    }
    return '${lPer100km.toStringAsFixed(1)} L/100km';
  }

  /// kWh/100 km ↔ mi/kWh (EV efficiency).
  String consumptionElectric(double kwhPer100km) {
    if (isImperial) {
      if (kwhPer100km <= 0) return '—';
      final miPerKwh = 62.1371 / kwhPer100km;
      return '${miPerKwh.toStringAsFixed(1)} mi/kWh';
    }
    return '${kwhPer100km.toStringAsFixed(1)} kWh/100km';
  }
}

import '../api/models.dart' show FuelCost;
import 'trip_profile.dart' show FuelType;

/// Tailpipe CO2 per litre of fuel burned (kg). Standard conversion factors:
/// petrol 2.31, diesel 2.68, LPG 1.51. E85 is ~1.6 counting only the fossil
/// share. A hybrid burns petrol.
const Map<FuelType, double> kCo2KgPerLitre = {
  FuelType.petrol: 2.31,
  FuelType.hybrid: 2.31,
  FuelType.diesel: 2.68,
  FuelType.lpg: 1.51,
  FuelType.e85: 1.6,
};

/// Average EU grid mix, kg CO2 per kWh (about 0.25). An electric car has no
/// tailpipe emissions; this attributes the electricity it charges.
const double kGridKgCo2PerKwh = 0.25;

class TripEmissions {
  const TripEmissions({
    required this.totalKg,
    required this.perPassengerKg,
    required this.electric,
  });

  final double totalKg;
  final double perPassengerKg;

  /// True when the figure comes from grid electricity, not burnt fuel.
  final bool electric;
}

/// CO2 of the planned drive, or null when the fuel used is unknown.
TripEmissions? tripEmissions({
  required FuelCost fuelCost,
  required int travellers,
}) {
  final units = fuelCost.fuelUnits;
  if (units <= 0) return null;
  final electric = fuelCost.fuelType == FuelType.electric;
  final factor =
      electric ? kGridKgCo2PerKwh : kCo2KgPerLitre[fuelCost.fuelType];
  if (factor == null) return null;
  final total = units * factor;
  final people = travellers < 1 ? 1 : travellers;
  return TripEmissions(
    totalKg: total,
    perPassengerKg: total / people,
    electric: electric,
  );
}

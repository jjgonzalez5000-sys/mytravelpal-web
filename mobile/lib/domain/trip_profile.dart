import 'package:flutter/material.dart';

/// Vehicle + travellers + meal preferences bundled as one "trip profile".
///
/// Persisted in [AppPrefs] as a single JSON blob so the user configures it
/// once and every plan request picks it up. Kept in `domain/` (not
/// `api/`) because the backend has its own `TripProfileIn` schema — we
/// map to JSON at the ApiClient boundary.

enum VehicleType {
  car('car', 'Car', Icons.directions_car),
  motorbike('motorbike', 'Motorbike', Icons.two_wheeler),
  van('van', 'Van', Icons.airport_shuttle),
  camper('camper', 'Camper', Icons.rv_hookup);

  const VehicleType(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;

  static VehicleType fromCode(String c) =>
      values.firstWhere((v) => v.code == c, orElse: () => VehicleType.car);
}

enum FuelType {
  petrol('petrol', 'Petrol'),
  diesel('diesel', 'Diesel'),
  hybrid('hybrid', 'Hybrid'),
  electric('electric', 'Electric'),
  lpg('lpg', 'LPG');

  const FuelType(this.code, this.label);
  final String code;
  final String label;

  static FuelType fromCode(String c) =>
      values.firstWhere((v) => v.code == c, orElse: () => FuelType.petrol);
}

@immutable
class Vehicle {
  const Vehicle({
    this.type = VehicleType.car,
    this.fuelType = FuelType.petrol,
    this.consumptionLPer100km = 6.5,
    this.consumptionKwhPer100km = 18.0,
    this.fuelTankL = 50.0,
    this.evRangeKm = 350.0,
  });

  final VehicleType type;
  final FuelType fuelType;
  final double consumptionLPer100km;
  final double consumptionKwhPer100km;
  final double fuelTankL;
  final double evRangeKm;

  Vehicle copyWith({
    VehicleType? type,
    FuelType? fuelType,
    double? consumptionLPer100km,
    double? consumptionKwhPer100km,
    double? fuelTankL,
    double? evRangeKm,
  }) =>
      Vehicle(
        type: type ?? this.type,
        fuelType: fuelType ?? this.fuelType,
        consumptionLPer100km: consumptionLPer100km ?? this.consumptionLPer100km,
        consumptionKwhPer100km:
            consumptionKwhPer100km ?? this.consumptionKwhPer100km,
        fuelTankL: fuelTankL ?? this.fuelTankL,
        evRangeKm: evRangeKm ?? this.evRangeKm,
      );

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'fuel_type': fuelType.code,
        'consumption_l_per_100km': consumptionLPer100km,
        'consumption_kwh_per_100km': consumptionKwhPer100km,
        'fuel_tank_l': fuelTankL,
        'ev_range_km': evRangeKm,
      };

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        type: VehicleType.fromCode(j['type'] as String? ?? 'car'),
        fuelType: FuelType.fromCode(j['fuel_type'] as String? ?? 'petrol'),
        consumptionLPer100km:
            (j['consumption_l_per_100km'] as num?)?.toDouble() ?? 6.5,
        consumptionKwhPer100km:
            (j['consumption_kwh_per_100km'] as num?)?.toDouble() ?? 18.0,
        fuelTankL: (j['fuel_tank_l'] as num?)?.toDouble() ?? 50.0,
        evRangeKm: (j['ev_range_km'] as num?)?.toDouble() ?? 350.0,
      );
}

@immutable
class MealPreferences {
  const MealPreferences({
    this.breakfastHour = 8,
    this.lunchHour = 13,
    this.dinnerHour = 20,
    this.typicalStopMinutes = 45,
  });

  final int breakfastHour;
  final int lunchHour;
  final int dinnerHour;
  final int typicalStopMinutes;

  MealPreferences copyWith({
    int? breakfastHour,
    int? lunchHour,
    int? dinnerHour,
    int? typicalStopMinutes,
  }) =>
      MealPreferences(
        breakfastHour: breakfastHour ?? this.breakfastHour,
        lunchHour: lunchHour ?? this.lunchHour,
        dinnerHour: dinnerHour ?? this.dinnerHour,
        typicalStopMinutes: typicalStopMinutes ?? this.typicalStopMinutes,
      );

  Map<String, dynamic> toJson() => {
        'breakfast_hour': breakfastHour,
        'lunch_hour': lunchHour,
        'dinner_hour': dinnerHour,
        'typical_stop_minutes': typicalStopMinutes,
      };

  factory MealPreferences.fromJson(Map<String, dynamic> j) => MealPreferences(
        breakfastHour: (j['breakfast_hour'] as num?)?.toInt() ?? 8,
        lunchHour: (j['lunch_hour'] as num?)?.toInt() ?? 13,
        dinnerHour: (j['dinner_hour'] as num?)?.toInt() ?? 20,
        typicalStopMinutes: (j['typical_stop_minutes'] as num?)?.toInt() ?? 45,
      );
}

@immutable
class TripProfile {
  const TripProfile({
    this.travellers = 1,
    this.hasKids = false,
    this.hasPets = false,
    this.vehicle = const Vehicle(),
    this.meals = const MealPreferences(),
  });

  final int travellers;
  final bool hasKids;
  final bool hasPets;
  final Vehicle vehicle;
  final MealPreferences meals;

  TripProfile copyWith({
    int? travellers,
    bool? hasKids,
    bool? hasPets,
    Vehicle? vehicle,
    MealPreferences? meals,
  }) =>
      TripProfile(
        travellers: travellers ?? this.travellers,
        hasKids: hasKids ?? this.hasKids,
        hasPets: hasPets ?? this.hasPets,
        vehicle: vehicle ?? this.vehicle,
        meals: meals ?? this.meals,
      );

  Map<String, dynamic> toJson() => {
        'travellers': travellers,
        'has_kids': hasKids,
        'has_pets': hasPets,
        'vehicle': vehicle.toJson(),
        'meals': meals.toJson(),
      };

  factory TripProfile.fromJson(Map<String, dynamic> j) => TripProfile(
        travellers: (j['travellers'] as num?)?.toInt() ?? 1,
        hasKids: j['has_kids'] as bool? ?? false,
        hasPets: j['has_pets'] as bool? ?? false,
        vehicle: j['vehicle'] == null
            ? const Vehicle()
            : Vehicle.fromJson(j['vehicle'] as Map<String, dynamic>),
        meals: j['meals'] == null
            ? const MealPreferences()
            : MealPreferences.fromJson(j['meals'] as Map<String, dynamic>),
      );
}

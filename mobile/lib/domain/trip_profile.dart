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

/// How aggressively the driver wants to eat kilometres.
enum TravelPace {
  push('push'),
  steady('steady'),
  savour('savour');

  const TravelPace(this.code);
  final String code;

  static TravelPace fromCode(String? c) =>
      values.firstWhere((v) => v.code == c, orElse: () => TravelPace.steady);
}

/// When to surface hotels mid-trip.
enum OvernightPolicy {
  never('never'),
  ifNeeded('if_needed'),
  alwaysIfLong('always_if_long');

  const OvernightPolicy(this.code);
  final String code;

  static OvernightPolicy fromCode(String? c) => values.firstWhere(
        (v) => v.code == c,
        orElse: () => OvernightPolicy.ifNeeded,
      );
}

/// Flavour of rest-stop / restaurant suggestions.
enum BreakStyle {
  minimal('minimal'),
  scenic('scenic'),
  foodie('foodie');

  const BreakStyle(this.code);
  final String code;

  static BreakStyle fromCode(String? c) =>
      values.firstWhere((v) => v.code == c, orElse: () => BreakStyle.scenic);
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
    this.breakfastMinute = 0,
    this.lunchHour = 13,
    this.lunchMinute = 0,
    this.dinnerHour = 20,
    this.dinnerMinute = 0,
    this.typicalStopMinutes = 45,
    this.reminderMinutesBefore = 30,
  });

  final int breakfastHour;
  final int breakfastMinute;
  final int lunchHour;
  final int lunchMinute;
  final int dinnerHour;
  final int dinnerMinute;
  final int typicalStopMinutes;

  /// How many minutes before the recommended departure to fire a local
  /// notification. 0 disables. Defaults to 30 minutes.
  final int reminderMinutesBefore;

  MealPreferences copyWith({
    int? breakfastHour,
    int? breakfastMinute,
    int? lunchHour,
    int? lunchMinute,
    int? dinnerHour,
    int? dinnerMinute,
    int? typicalStopMinutes,
    int? reminderMinutesBefore,
  }) =>
      MealPreferences(
        breakfastHour: breakfastHour ?? this.breakfastHour,
        breakfastMinute: breakfastMinute ?? this.breakfastMinute,
        lunchHour: lunchHour ?? this.lunchHour,
        lunchMinute: lunchMinute ?? this.lunchMinute,
        dinnerHour: dinnerHour ?? this.dinnerHour,
        dinnerMinute: dinnerMinute ?? this.dinnerMinute,
        typicalStopMinutes: typicalStopMinutes ?? this.typicalStopMinutes,
        reminderMinutesBefore:
            reminderMinutesBefore ?? this.reminderMinutesBefore,
      );

  Map<String, dynamic> toJson() => {
        'breakfast_hour': breakfastHour,
        'breakfast_minute': breakfastMinute,
        'lunch_hour': lunchHour,
        'lunch_minute': lunchMinute,
        'dinner_hour': dinnerHour,
        'dinner_minute': dinnerMinute,
        'typical_stop_minutes': typicalStopMinutes,
        'reminder_minutes_before': reminderMinutesBefore,
      };

  factory MealPreferences.fromJson(Map<String, dynamic> j) => MealPreferences(
        breakfastHour: (j['breakfast_hour'] as num?)?.toInt() ?? 8,
        breakfastMinute: (j['breakfast_minute'] as num?)?.toInt() ?? 0,
        lunchHour: (j['lunch_hour'] as num?)?.toInt() ?? 13,
        lunchMinute: (j['lunch_minute'] as num?)?.toInt() ?? 0,
        dinnerHour: (j['dinner_hour'] as num?)?.toInt() ?? 20,
        dinnerMinute: (j['dinner_minute'] as num?)?.toInt() ?? 0,
        typicalStopMinutes: (j['typical_stop_minutes'] as num?)?.toInt() ?? 45,
        reminderMinutesBefore:
            (j['reminder_minutes_before'] as num?)?.toInt() ?? 30,
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
    this.travelPace = TravelPace.steady,
    this.overnightPolicy = OvernightPolicy.ifNeeded,
    this.dailyDrivingCapHours = 8,
    this.bedtimeHour = 22,
    this.wakeHour = 8,
    this.breakStyle = BreakStyle.scenic,
    this.vehicleModelId,
    this.currentTankLevelPercent,
  });

  final int travellers;
  final bool hasKids;
  final bool hasPets;
  final Vehicle vehicle;
  final MealPreferences meals;

  // -- Travel style --
  final TravelPace travelPace;
  final OvernightPolicy overnightPolicy;
  final int dailyDrivingCapHours;
  final int bedtimeHour;
  final int wakeHour;
  final BreakStyle breakStyle;

  /// Optional link to a curated catalogue entry from
  /// `/v1/vehicles`. When set the backend substitutes the catalogue's
  /// tank size + real-world consumption for the manual `vehicle`
  /// sliders.
  final String? vehicleModelId;

  /// Current fuel level in the tank (0-100). Common notches from the
  /// picker: 25 / 50 / 75 / 100. When paired with `vehicleModelId`
  /// the backend returns a `refuel_window` hint.
  final int? currentTankLevelPercent;

  TripProfile copyWith({
    int? travellers,
    bool? hasKids,
    bool? hasPets,
    Vehicle? vehicle,
    MealPreferences? meals,
    TravelPace? travelPace,
    OvernightPolicy? overnightPolicy,
    int? dailyDrivingCapHours,
    int? bedtimeHour,
    int? wakeHour,
    BreakStyle? breakStyle,
    // Sentinel-style opt-in: pass `clearVehicleModelId: true` to wipe
    // the field. `vehicleModelId: null` on its own would collide with
    // the "not passed" case.
    Object? vehicleModelId = _sentinel,
    Object? currentTankLevelPercent = _sentinel,
  }) =>
      TripProfile(
        travellers: travellers ?? this.travellers,
        hasKids: hasKids ?? this.hasKids,
        hasPets: hasPets ?? this.hasPets,
        vehicle: vehicle ?? this.vehicle,
        meals: meals ?? this.meals,
        travelPace: travelPace ?? this.travelPace,
        overnightPolicy: overnightPolicy ?? this.overnightPolicy,
        dailyDrivingCapHours:
            dailyDrivingCapHours ?? this.dailyDrivingCapHours,
        bedtimeHour: bedtimeHour ?? this.bedtimeHour,
        wakeHour: wakeHour ?? this.wakeHour,
        breakStyle: breakStyle ?? this.breakStyle,
        vehicleModelId: vehicleModelId == _sentinel
            ? this.vehicleModelId
            : vehicleModelId as String?,
        currentTankLevelPercent: currentTankLevelPercent == _sentinel
            ? this.currentTankLevelPercent
            : currentTankLevelPercent as int?,
      );

  Map<String, dynamic> toJson() => {
        'travellers': travellers,
        'has_kids': hasKids,
        'has_pets': hasPets,
        'vehicle': vehicle.toJson(),
        'meals': meals.toJson(),
        'travel_pace': travelPace.code,
        'overnight_policy': overnightPolicy.code,
        'daily_driving_cap_hours': dailyDrivingCapHours,
        'bedtime_hour': bedtimeHour,
        'wake_hour': wakeHour,
        'break_style': breakStyle.code,
        if (vehicleModelId != null) 'vehicle_model_id': vehicleModelId,
        if (currentTankLevelPercent != null)
          'current_tank_level_percent': currentTankLevelPercent,
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
        travelPace: TravelPace.fromCode(j['travel_pace'] as String?),
        overnightPolicy:
            OvernightPolicy.fromCode(j['overnight_policy'] as String?),
        dailyDrivingCapHours:
            (j['daily_driving_cap_hours'] as num?)?.toInt() ?? 8,
        bedtimeHour: (j['bedtime_hour'] as num?)?.toInt() ?? 22,
        wakeHour: (j['wake_hour'] as num?)?.toInt() ?? 8,
        breakStyle: BreakStyle.fromCode(j['break_style'] as String?),
        vehicleModelId: j['vehicle_model_id'] as String?,
        currentTankLevelPercent:
            (j['current_tank_level_percent'] as num?)?.toInt(),
      );
}

// Sentinel used by `TripProfile.copyWith` so callers can distinguish
// "leave the field alone" (default) from "set it to null" (explicit).
const Object _sentinel = Object();

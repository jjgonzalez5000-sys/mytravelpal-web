import 'package:flutter/foundation.dart';

import '../api/models.dart';
import '../domain/trip_profile.dart';

/// A trip the user chose to remember: enough to re-plan it later plus a
/// small summary card for the history list.
@immutable
class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.desiredDepartureAt,
    required this.savedAt,
    required this.distanceKm,
    required this.recommendedDepartureAt,
    required this.recommendedMinutes,
    required this.countriesCrossed,
    this.savedMinutesVsDesired = 0,
    this.savedEurVsTolls = 0,
    this.fuelCostEur = 0,
    this.reminderMinutesBefore = 0,
    this.notificationId,
    this.userSelections,
    this.tripProfile,
  });

  final String id;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final DateTime desiredDepartureAt;
  final DateTime savedAt;

  final double distanceKm;
  final DateTime recommendedDepartureAt;
  final double recommendedMinutes;
  final List<Country> countriesCrossed;

  /// Minutes the driver saved by taking our recommended departure over
  /// the sample closest to their desired departure. Persisted so the
  /// dashboard can sum real savings across trips.
  final double savedMinutesVsDesired;

  /// Euros saved by taking the toll-free alternative (only when the
  /// heuristic flagged it "worth it" at plan time).
  final double savedEurVsTolls;

  /// Fuel budget estimated for the trip from the profile+vehicle. Zero
  /// when the trip was planned without a profile.
  final double fuelCostEur;

  /// How many minutes before the recommended departure a local
  /// notification was scheduled. Zero when no reminder was requested.
  final int reminderMinutesBefore;

  /// The `flutter_local_notifications` ID used when scheduling this
  /// trip's reminder — kept so we can cancel/reschedule cleanly.
  /// Null for trips saved before Sprint 15 or when notifications were
  /// disabled at save time.
  final int? notificationId;

  /// Free-form JSON blob capturing the user's per-trip tweaks that
  /// the /plan response alone can't reconstruct: picked fuel-station
  /// keys, selected per-night hotel keys, picked meal-restaurant
  /// keys, the departure window they chose (if not the recommended
  /// one) and any per-day override sheet edits.
  ///
  /// Kept as an opaque map so we can grow it without a migration
  /// path every sprint. Consumer of the field is
  /// [ResultScreen], which rehydrates known shape keys on load:
  ///   picked_fuel_keys: [String]
  ///   picked_restaurant_keys: [String]
  ///   picked_hotel_keys_by_day: {String dayIndex: {name,lat,lon}}
  ///   chosen_departure_at: ISO String (only when not the recommended)
  ///   day_overrides: {String dayIndex: {start_hour, cap_hours}}
  ///   destination_hotel: {name,lat,lon}
  final Map<String, dynamic>? userSelections;

  /// Snapshot of the TripProfile used when this trip was planned.
  /// Restored as _overrideProfile when the user taps "repetir" so the
  /// re-plan uses the same overnight policy, daily cap, vehicle, etc.
  /// Null for trips saved before this field was added (backward-compat).
  final TripProfile? tripProfile;

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': _geocodeJson(origin),
        'destination': _geocodeJson(destination),
        'desired_departure_at': desiredDepartureAt.toIso8601String(),
        'saved_at': savedAt.toIso8601String(),
        'distance_km': distanceKm,
        'recommended_departure_at': recommendedDepartureAt.toIso8601String(),
        'recommended_minutes': recommendedMinutes,
        'countries_crossed':
            countriesCrossed.map((c) => c.code).toList(growable: false),
        'saved_minutes_vs_desired': savedMinutesVsDesired,
        'saved_eur_vs_tolls': savedEurVsTolls,
        'fuel_cost_eur': fuelCostEur,
        'reminder_minutes_before': reminderMinutesBefore,
        if (notificationId != null) 'notification_id': notificationId,
        if (userSelections != null && userSelections!.isNotEmpty)
          'user_selections': userSelections,
        if (tripProfile != null)
          'trip_profile': tripProfile!.toJson(),
      };

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
        id: json['id'] as String,
        origin: _geocodeFrom(json['origin'] as Map<String, dynamic>),
        destination: _geocodeFrom(json['destination'] as Map<String, dynamic>),
        desiredDepartureAt: DateTime.parse(json['desired_departure_at'] as String),
        savedAt: DateTime.parse(json['saved_at'] as String),
        distanceKm: (json['distance_km'] as num).toDouble(),
        recommendedDepartureAt:
            DateTime.parse(json['recommended_departure_at'] as String),
        recommendedMinutes: (json['recommended_minutes'] as num).toDouble(),
        countriesCrossed: (json['countries_crossed'] as List<dynamic>)
            .map((c) => Country.fromCode(c as String))
            .toList(growable: false),
        savedMinutesVsDesired:
            (json['saved_minutes_vs_desired'] as num?)?.toDouble() ?? 0,
        savedEurVsTolls:
            (json['saved_eur_vs_tolls'] as num?)?.toDouble() ?? 0,
        fuelCostEur: (json['fuel_cost_eur'] as num?)?.toDouble() ?? 0,
        reminderMinutesBefore:
            (json['reminder_minutes_before'] as num?)?.toInt() ?? 0,
        notificationId: (json['notification_id'] as num?)?.toInt(),
        userSelections: json['user_selections'] as Map<String, dynamic>?,
        tripProfile: json['trip_profile'] == null
            ? null
            : TripProfile.fromJson(
                json['trip_profile'] as Map<String, dynamic>),
      );
}

Map<String, dynamic> _geocodeJson(GeocodeResult r) => {
      'display_name': r.displayName,
      'coordinate': {'lat': r.coordinate.lat, 'lon': r.coordinate.lon},
      'country': r.country.code,
    };

GeocodeResult _geocodeFrom(Map<String, dynamic> json) => GeocodeResult(
      displayName: json['display_name'] as String,
      coordinate: LatLon(
        lat: ((json['coordinate'] as Map<String, dynamic>)['lat'] as num).toDouble(),
        lon: ((json['coordinate'] as Map<String, dynamic>)['lon'] as num).toDouble(),
      ),
      country: Country.fromCode(json['country'] as String),
    );

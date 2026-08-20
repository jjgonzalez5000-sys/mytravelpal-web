import 'package:flutter/foundation.dart';

import '../api/models.dart';

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

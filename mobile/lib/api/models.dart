import 'package:flutter/foundation.dart';

enum Country {
  ch,
  fr,
  it,
  es;

  String get code => switch (this) {
        Country.ch => 'CH',
        Country.fr => 'FR',
        Country.it => 'IT',
        Country.es => 'ES',
      };

  String get displayName => switch (this) {
        Country.ch => 'Switzerland',
        Country.fr => 'France',
        Country.it => 'Italy',
        Country.es => 'Spain',
      };

  static Country fromCode(String code) => switch (code.toUpperCase()) {
        'CH' => Country.ch,
        'FR' => Country.fr,
        'IT' => Country.it,
        'ES' => Country.es,
        _ => throw ArgumentError('Unknown country: $code'),
      };
}

@immutable
class LatLon {
  const LatLon({required this.lat, required this.lon});

  final double lat;
  final double lon;

  Map<String, double> toJson() => {'lat': lat, 'lon': lon};

  @override
  bool operator ==(Object other) =>
      other is LatLon && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

@immutable
class TripPlanRequest {
  const TripPlanRequest({
    required this.origin,
    required this.destination,
    required this.desiredDepartureAt,
    this.countries,
  });

  final LatLon origin;
  final LatLon destination;
  final DateTime desiredDepartureAt;

  /// Optional. When null the backend infers countries from the coordinates.
  final List<Country>? countries;

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'desired_departure_at': desiredDepartureAt.toIso8601String(),
        if (countries != null)
          'countries': countries!.map((c) => c.code).toList(),
      };
}

@immutable
class GeocodeResult {
  const GeocodeResult({
    required this.displayName,
    required this.coordinate,
    required this.country,
  });

  final String displayName;
  final LatLon coordinate;
  final Country country;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    final coord = json['coordinate'] as Map<String, dynamic>;
    return GeocodeResult(
      displayName: json['display_name'] as String,
      coordinate: LatLon(
        lat: (coord['lat'] as num).toDouble(),
        lon: (coord['lon'] as num).toDouble(),
      ),
      country: Country.fromCode(json['country'] as String),
    );
  }
}

@immutable
class RouteInfo {
  const RouteInfo({
    required this.distanceKm,
    required this.freeFlowMinutes,
    required this.polyline,
    required this.tollCostEur,
    required this.countriesCrossed,
  });

  final double distanceKm;
  final double freeFlowMinutes;
  final String polyline;
  final double tollCostEur;
  final List<Country> countriesCrossed;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        distanceKm: (json['distance_km'] as num).toDouble(),
        freeFlowMinutes: (json['free_flow_minutes'] as num).toDouble(),
        polyline: json['polyline'] as String,
        tollCostEur: (json['toll_cost_eur'] as num).toDouble(),
        countriesCrossed: (json['countries_crossed'] as List<dynamic>)
            .map((c) => Country.fromCode(c as String))
            .toList(growable: false),
      );
}

@immutable
class TimeWindow {
  const TimeWindow({
    required this.departureAt,
    required this.estimatedMinutes,
    required this.trafficFactor,
    required this.recommended,
  });

  final DateTime departureAt;
  final double estimatedMinutes;
  final double trafficFactor;
  final bool recommended;

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
        departureAt: DateTime.parse(json['departure_at'] as String),
        estimatedMinutes: (json['estimated_minutes'] as num).toDouble(),
        trafficFactor: (json['traffic_factor'] as num).toDouble(),
        recommended: json['recommended'] as bool,
      );
}

@immutable
class FuelPrice {
  const FuelPrice({
    required this.stationName,
    required this.country,
    required this.priceEurPerL,
    required this.distanceFromOriginKm,
  });

  final String stationName;
  final Country country;
  final double priceEurPerL;
  final double distanceFromOriginKm;

  factory FuelPrice.fromJson(Map<String, dynamic> json) => FuelPrice(
        stationName: json['station_name'] as String,
        country: Country.fromCode(json['country'] as String),
        priceEurPerL: (json['price_eur_per_l'] as num).toDouble(),
        distanceFromOriginKm:
            (json['distance_from_origin_km'] as num).toDouble(),
      );
}

@immutable
class TripPlanResponse {
  const TripPlanResponse({
    required this.route,
    required this.timeWindows,
    required this.fuelPrices,
  });

  final RouteInfo route;
  final List<TimeWindow> timeWindows;
  final List<FuelPrice> fuelPrices;

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      TripPlanResponse(
        route: RouteInfo.fromJson(json['route'] as Map<String, dynamic>),
        timeWindows: (json['time_windows'] as List<dynamic>)
            .map((w) => TimeWindow.fromJson(w as Map<String, dynamic>))
            .toList(growable: false),
        fuelPrices: (json['fuel_prices'] as List<dynamic>)
            .map((f) => FuelPrice.fromJson(f as Map<String, dynamic>))
            .toList(growable: false),
      );
}

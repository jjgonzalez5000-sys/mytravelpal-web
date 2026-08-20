import 'package:flutter/material.dart';

enum AdverseEventType {
  fire,
  strike,
  weather,
  accident,
  roadwork,
  flood,
  snow,
  protest,
  other;

  String get code => name;

  String get displayName => switch (this) {
        AdverseEventType.fire => 'Fire',
        AdverseEventType.strike => 'Strike',
        AdverseEventType.weather => 'Adverse weather',
        AdverseEventType.accident => 'Accident',
        AdverseEventType.roadwork => 'Roadwork',
        AdverseEventType.flood => 'Flood',
        AdverseEventType.snow => 'Snow',
        AdverseEventType.protest => 'Protest',
        AdverseEventType.other => 'Other',
      };

  IconData get icon => switch (this) {
        AdverseEventType.fire => Icons.local_fire_department,
        AdverseEventType.strike => Icons.record_voice_over,
        AdverseEventType.weather => Icons.cloud,
        AdverseEventType.accident => Icons.car_crash,
        AdverseEventType.roadwork => Icons.construction,
        AdverseEventType.flood => Icons.water_damage,
        AdverseEventType.snow => Icons.ac_unit,
        AdverseEventType.protest => Icons.groups,
        AdverseEventType.other => Icons.warning,
      };

  static AdverseEventType fromCode(String code) => values.firstWhere(
        (t) => t.code == code.toLowerCase(),
        orElse: () => AdverseEventType.other,
      );
}

enum AdverseEventSeverity {
  info,
  warning,
  critical;

  String get code => name;

  String get displayName => switch (this) {
        AdverseEventSeverity.info => 'Info',
        AdverseEventSeverity.warning => 'Warning',
        AdverseEventSeverity.critical => 'Critical',
      };

  static AdverseEventSeverity fromCode(String code) => values.firstWhere(
        (s) => s.code == code.toLowerCase(),
        orElse: () => AdverseEventSeverity.info,
      );
}

enum PriceBand {
  budget,
  mid,
  lux,
  any;

  String get code => switch (this) {
        PriceBand.budget => 'budget',
        PriceBand.mid => 'mid',
        PriceBand.lux => 'lux',
        PriceBand.any => 'any',
      };

  String get displayName => switch (this) {
        PriceBand.budget => 'Budget',
        PriceBand.mid => 'Mid',
        PriceBand.lux => 'Luxury',
        PriceBand.any => 'Any',
      };

  /// A compact symbolic label suitable for buttons and chips.
  String get symbol => switch (this) {
        PriceBand.budget => '€',
        PriceBand.mid => '€€',
        PriceBand.lux => '€€€',
        PriceBand.any => '€–€€€',
      };

  static PriceBand fromCode(String code) => switch (code.toLowerCase()) {
        'budget' => PriceBand.budget,
        'mid' => PriceBand.mid,
        'lux' => PriceBand.lux,
        'any' => PriceBand.any,
        _ => throw ArgumentError('Unknown price band: $code'),
      };
}

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
    this.hotelMaxDetourMinutes,
    this.hotelPriceBand,
    this.restaurantMaxDetourMinutes,
    this.restaurantPriceBand,
    this.includeAdverseEvents = false,
    this.adverseEventsMaxDistanceKm = 25.0,
  });

  final LatLon origin;
  final LatLon destination;
  final DateTime desiredDepartureAt;

  /// Optional. When null the backend infers countries from the coordinates.
  final List<Country>? countries;

  /// When > 0, the backend searches for hotels within this round-trip
  /// detour off the route. Null or 0 disables the hotel search.
  final int? hotelMaxDetourMinutes;

  /// Only applied when `hotelMaxDetourMinutes` is > 0.
  final PriceBand? hotelPriceBand;

  /// When > 0, the backend searches for restaurants within this
  /// round-trip detour off the route. Null or 0 disables.
  final int? restaurantMaxDetourMinutes;

  /// Only applied when `restaurantMaxDetourMinutes` is > 0.
  final PriceBand? restaurantPriceBand;

  /// If true, include known adverse events (fires, strikes, weather,
  /// accidents, roadworks, floods, snow, protests) along the route.
  final bool includeAdverseEvents;

  /// Max great-circle distance from the route for an adverse event to
  /// be included. Only meaningful when [includeAdverseEvents] is true.
  final double adverseEventsMaxDistanceKm;

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'desired_departure_at': desiredDepartureAt.toIso8601String(),
        if (countries != null)
          'countries': countries!.map((c) => c.code).toList(),
        if (hotelMaxDetourMinutes != null)
          'hotel_max_detour_minutes': hotelMaxDetourMinutes,
        if (hotelPriceBand != null) 'hotel_price_band': hotelPriceBand!.code,
        if (restaurantMaxDetourMinutes != null)
          'restaurant_max_detour_minutes': restaurantMaxDetourMinutes,
        if (restaurantPriceBand != null)
          'restaurant_price_band': restaurantPriceBand!.code,
        if (includeAdverseEvents) 'include_adverse_events': true,
        if (includeAdverseEvents)
          'adverse_events_max_distance_km': adverseEventsMaxDistanceKm,
      };
}

@immutable
class AdverseEvent {
  const AdverseEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.source,
    required this.description,
    required this.reportedAt,
    required this.expiresAt,
    required this.coordinate,
    this.country,
  });

  final String id;
  final AdverseEventType type;
  final AdverseEventSeverity severity;
  final String source; // "user", "mock", "weather", "official"
  final String description;
  final DateTime reportedAt;
  final DateTime expiresAt;
  final LatLon coordinate;
  final Country? country;

  factory AdverseEvent.fromJson(Map<String, dynamic> json) => AdverseEvent(
        id: json['id'] as String,
        type: AdverseEventType.fromCode(json['type'] as String),
        severity: AdverseEventSeverity.fromCode(json['severity'] as String),
        source: json['source'] as String,
        description: json['description'] as String,
        reportedAt: DateTime.parse(json['reported_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        coordinate: LatLon(
          lat: (json['lat'] as num).toDouble(),
          lon: (json['lon'] as num).toDouble(),
        ),
        country: json['country'] == null
            ? null
            : Country.fromCode(json['country'] as String),
      );
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
class Hotel {
  const Hotel({
    required this.name,
    required this.country,
    required this.priceEurPerNight,
    required this.priceBand,
    required this.detourMinutes,
    required this.distanceFromRouteKm,
    required this.coordinate,
  });

  final String name;
  final Country country;
  final double priceEurPerNight;
  final PriceBand priceBand;
  final double detourMinutes;
  final double distanceFromRouteKm;
  final LatLon coordinate;

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
        name: json['name'] as String,
        country: Country.fromCode(json['country'] as String),
        priceEurPerNight: (json['price_eur_per_night'] as num).toDouble(),
        priceBand: PriceBand.fromCode(json['price_band'] as String),
        detourMinutes: (json['detour_minutes'] as num).toDouble(),
        distanceFromRouteKm:
            (json['distance_from_route_km'] as num).toDouble(),
        coordinate: LatLon(
          lat: (json['lat'] as num).toDouble(),
          lon: (json['lon'] as num).toDouble(),
        ),
      );
}

@immutable
class Restaurant {
  const Restaurant({
    required this.name,
    required this.country,
    required this.priceEurPerMeal,
    required this.priceBand,
    required this.detourMinutes,
    required this.distanceFromRouteKm,
    required this.coordinate,
  });

  final String name;
  final Country country;
  final double priceEurPerMeal;
  final PriceBand priceBand;
  final double detourMinutes;
  final double distanceFromRouteKm;
  final LatLon coordinate;

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        name: json['name'] as String,
        country: Country.fromCode(json['country'] as String),
        priceEurPerMeal: (json['price_eur_per_meal'] as num).toDouble(),
        priceBand: PriceBand.fromCode(json['price_band'] as String),
        detourMinutes: (json['detour_minutes'] as num).toDouble(),
        distanceFromRouteKm:
            (json['distance_from_route_km'] as num).toDouble(),
        coordinate: LatLon(
          lat: (json['lat'] as num).toDouble(),
          lon: (json['lon'] as num).toDouble(),
        ),
      );
}

@immutable
class RestStop {
  const RestStop({
    required this.distanceFromOriginKm,
    required this.cumulativeDrivingHours,
    required this.recommendedBreakMinutes,
    required this.coordinate,
  });

  final double distanceFromOriginKm;
  final double cumulativeDrivingHours;
  final int recommendedBreakMinutes;
  final LatLon coordinate;

  factory RestStop.fromJson(Map<String, dynamic> json) => RestStop(
        distanceFromOriginKm:
            (json['distance_from_origin_km'] as num).toDouble(),
        cumulativeDrivingHours:
            (json['cumulative_driving_hours'] as num).toDouble(),
        recommendedBreakMinutes: (json['recommended_break_minutes'] as num).toInt(),
        coordinate: LatLon(
          lat: (json['lat'] as num).toDouble(),
          lon: (json['lon'] as num).toDouble(),
        ),
      );
}

@immutable
class TripPlanResponse {
  const TripPlanResponse({
    required this.route,
    required this.timeWindows,
    required this.fuelPrices,
    required this.hotels,
    required this.restaurants,
    required this.restStops,
    required this.adverseEvents,
  });

  final RouteInfo route;
  final List<TimeWindow> timeWindows;
  final List<FuelPrice> fuelPrices;
  final List<Hotel> hotels;
  final List<Restaurant> restaurants;
  final List<RestStop> restStops;
  final List<AdverseEvent> adverseEvents;

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      TripPlanResponse(
        route: RouteInfo.fromJson(json['route'] as Map<String, dynamic>),
        timeWindows: (json['time_windows'] as List<dynamic>)
            .map((w) => TimeWindow.fromJson(w as Map<String, dynamic>))
            .toList(growable: false),
        fuelPrices: (json['fuel_prices'] as List<dynamic>)
            .map((f) => FuelPrice.fromJson(f as Map<String, dynamic>))
            .toList(growable: false),
        hotels: (json['hotels'] as List<dynamic>? ?? const <dynamic>[])
            .map((h) => Hotel.fromJson(h as Map<String, dynamic>))
            .toList(growable: false),
        restaurants:
            (json['restaurants'] as List<dynamic>? ?? const <dynamic>[])
                .map((r) => Restaurant.fromJson(r as Map<String, dynamic>))
                .toList(growable: false),
        restStops: (json['rest_stops'] as List<dynamic>? ?? const <dynamic>[])
            .map((s) => RestStop.fromJson(s as Map<String, dynamic>))
            .toList(growable: false),
        adverseEvents:
            (json['adverse_events'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => AdverseEvent.fromJson(e as Map<String, dynamic>))
                .toList(growable: false),
      );
}

@immutable
class NarrativeResponse {
  const NarrativeResponse({
    required this.narrative,
    required this.originName,
    required this.destinationName,
    required this.generatedAt,
  });

  final String narrative;
  final String originName;
  final String destinationName;
  final DateTime generatedAt;

  factory NarrativeResponse.fromJson(Map<String, dynamic> json) =>
      NarrativeResponse(
        narrative: json['narrative'] as String,
        originName: json['origin_name'] as String,
        destinationName: json['destination_name'] as String,
        generatedAt: DateTime.parse(json['generated_at'] as String),
      );
}

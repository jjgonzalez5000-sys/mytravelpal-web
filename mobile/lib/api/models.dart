import 'package:flutter/material.dart';

import '../domain/trip_profile.dart';

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
    this.includeTollAlternative = false,
    this.includeHourlyTollAnalysis = false,
    this.avoidMotorways = false,
    this.preferScenic = false,
    this.tripProfile,
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

  /// If true, ask the backend to also compute a toll-free alternative
  /// and return a side-by-side comparison.
  final bool includeTollAlternative;

  /// Premium. If true, backend returns a 24-hour verdict table on
  /// whether skipping tolls beats keeping them at each hour of the day.
  final bool includeHourlyTollAnalysis;

  /// Routing options: skip motorways / bias to scenic routes.
  final bool avoidMotorways;
  final bool preferScenic;

  /// Trip profile (vehicle + travellers + meals). When present the
  /// backend applies profile-aware ranking to POIs and computes trip
  /// optimizations (meal stops, sleep stop, fuel cost).
  final TripProfile? tripProfile;

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
        if (includeTollAlternative) 'include_toll_alternative': true,
        if (includeHourlyTollAnalysis) 'include_hourly_toll_analysis': true,
        if (avoidMotorways) 'avoid_motorways': true,
        if (preferScenic) 'prefer_scenic': true,
        if (tripProfile != null) 'trip_profile': tripProfile!.toJson(),
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
    this.geometry = const [],
  });

  final double distanceKm;
  final double freeFlowMinutes;
  final String polyline;
  final double tollCostEur;
  final List<Country> countriesCrossed;

  /// Ordered points that follow real roads. Empty when the backend fell
  /// back to the mock — clients should draw a straight A→B line then.
  final List<LatLon> geometry;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        distanceKm: (json['distance_km'] as num).toDouble(),
        freeFlowMinutes: (json['free_flow_minutes'] as num).toDouble(),
        polyline: json['polyline'] as String,
        tollCostEur: (json['toll_cost_eur'] as num).toDouble(),
        countriesCrossed: (json['countries_crossed'] as List<dynamic>)
            .map((c) => Country.fromCode(c as String))
            .toList(growable: false),
        geometry: (json['geometry'] as List<dynamic>? ?? const <dynamic>[])
            .map((p) {
          final pair = p as List<dynamic>;
          return LatLon(
            lat: (pair[1] as num).toDouble(),
            lon: (pair[0] as num).toDouble(),
          );
        }).toList(growable: false),
      );
}

@immutable
class TollAlternative {
  const TollAlternative({
    required this.distanceKm,
    required this.durationMinutes,
    required this.tollCostEur,
    required this.savingsEur,
    required this.timePenaltyMinutes,
    required this.extraDistanceKm,
    required this.worthIt,
    this.geometry = const [],
  });

  final double distanceKm;
  final double durationMinutes;
  final double tollCostEur;
  final double savingsEur;
  final double timePenaltyMinutes;
  final double extraDistanceKm;
  final bool worthIt;
  final List<LatLon> geometry;

  factory TollAlternative.fromJson(Map<String, dynamic> json) => TollAlternative(
        distanceKm: (json['distance_km'] as num).toDouble(),
        durationMinutes: (json['duration_minutes'] as num).toDouble(),
        tollCostEur: (json['toll_cost_eur'] as num).toDouble(),
        savingsEur: (json['savings_eur'] as num).toDouble(),
        timePenaltyMinutes: (json['time_penalty_minutes'] as num).toDouble(),
        extraDistanceKm: (json['extra_distance_km'] as num).toDouble(),
        worthIt: json['worth_it'] as bool,
        geometry: (json['geometry'] as List<dynamic>? ?? const <dynamic>[])
            .map((p) {
          final pair = p as List<dynamic>;
          return LatLon(
            lat: (pair[1] as num).toDouble(),
            lon: (pair[0] as num).toDouble(),
          );
        }).toList(growable: false),
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
class FuelCost {
  const FuelCost({
    required this.totalCostEur,
    required this.averageUnitPriceEur,
    required this.fuelType,
    required this.fuelUnits,
    required this.unitLabel,
    required this.rangeOk,
    required this.notes,
  });

  final double totalCostEur;
  final double averageUnitPriceEur;
  final FuelType fuelType;
  final double fuelUnits;
  final String unitLabel;
  final bool rangeOk;
  final List<String> notes;

  factory FuelCost.fromJson(Map<String, dynamic> j) => FuelCost(
        totalCostEur: (j['total_cost_eur'] as num).toDouble(),
        averageUnitPriceEur: (j['average_unit_price_eur'] as num).toDouble(),
        fuelType: FuelType.fromCode(j['fuel_type'] as String),
        fuelUnits: (j['fuel_units'] as num).toDouble(),
        unitLabel: j['unit_label'] as String,
        rangeOk: j['range_ok'] as bool,
        notes: (j['notes'] as List<dynamic>? ?? const [])
            .map((n) => n as String)
            .toList(growable: false),
      );
}

@immutable
class MealStopOpt {
  const MealStopOpt({
    required this.slot,
    required this.at,
    required this.distanceFromOriginKm,
    this.restaurantName,
    this.restaurantPriceEurPerMeal,
    this.restaurantCoordinate,
  });

  final String slot; // "breakfast" | "lunch" | "dinner"
  final DateTime at;
  final double distanceFromOriginKm;
  final String? restaurantName;
  final double? restaurantPriceEurPerMeal;
  final LatLon? restaurantCoordinate;

  factory MealStopOpt.fromJson(Map<String, dynamic> j) => MealStopOpt(
        slot: j['slot'] as String,
        at: DateTime.parse(j['at'] as String),
        distanceFromOriginKm:
            (j['distance_from_origin_km'] as num).toDouble(),
        restaurantName: j['restaurant_name'] as String?,
        restaurantPriceEurPerMeal:
            (j['restaurant_price_eur_per_meal'] as num?)?.toDouble(),
        restaurantCoordinate: j['restaurant_lat'] == null
            ? null
            : LatLon(
                lat: (j['restaurant_lat'] as num).toDouble(),
                lon: (j['restaurant_lon'] as num).toDouble(),
              ),
      );
}

@immutable
class SleepStopOpt {
  const SleepStopOpt({
    required this.at,
    required this.distanceFromOriginKm,
    this.hotelName,
    this.hotelPriceEurPerNight,
    this.hotelCoordinate,
  });

  final DateTime at;
  final double distanceFromOriginKm;
  final String? hotelName;
  final double? hotelPriceEurPerNight;
  final LatLon? hotelCoordinate;

  factory SleepStopOpt.fromJson(Map<String, dynamic> j) => SleepStopOpt(
        at: DateTime.parse(j['at'] as String),
        distanceFromOriginKm:
            (j['distance_from_origin_km'] as num).toDouble(),
        hotelName: j['hotel_name'] as String?,
        hotelPriceEurPerNight:
            (j['hotel_price_eur_per_night'] as num?)?.toDouble(),
        hotelCoordinate: j['hotel_lat'] == null
            ? null
            : LatLon(
                lat: (j['hotel_lat'] as num).toDouble(),
                lon: (j['hotel_lon'] as num).toDouble(),
              ),
      );
}

@immutable
class Optimizations {
  const Optimizations({
    required this.mealStops,
    this.sleepStop,
    required this.fuelCost,
  });

  final List<MealStopOpt> mealStops;
  final SleepStopOpt? sleepStop;
  final FuelCost fuelCost;

  factory Optimizations.fromJson(Map<String, dynamic> j) => Optimizations(
        mealStops: (j['meal_stops'] as List<dynamic>)
            .map((m) => MealStopOpt.fromJson(m as Map<String, dynamic>))
            .toList(growable: false),
        sleepStop: j['sleep_stop'] == null
            ? null
            : SleepStopOpt.fromJson(j['sleep_stop'] as Map<String, dynamic>),
        fuelCost: FuelCost.fromJson(j['fuel_cost'] as Map<String, dynamic>),
      );
}

@immutable
class HourlyTollVerdict {
  const HourlyTollVerdict({
    required this.hour,
    required this.tollRouteMinutes,
    required this.tollFreeRouteMinutes,
    required this.savingsEur,
    required this.recommendation,
  });

  final int hour;
  final double tollRouteMinutes;
  final double tollFreeRouteMinutes;
  final double savingsEur;
  final String recommendation;

  factory HourlyTollVerdict.fromJson(Map<String, dynamic> j) => HourlyTollVerdict(
        hour: (j['hour'] as num).toInt(),
        tollRouteMinutes: (j['toll_route_minutes'] as num).toDouble(),
        tollFreeRouteMinutes: (j['toll_free_route_minutes'] as num).toDouble(),
        savingsEur: (j['savings_eur'] as num).toDouble(),
        recommendation: j['recommendation'] as String,
      );
}

@immutable
class HourlyTollReport {
  const HourlyTollReport({
    required this.verdicts,
    required this.bestHoursToSkip,
    required this.worstHoursToSkip,
  });

  final List<HourlyTollVerdict> verdicts;
  final List<int> bestHoursToSkip;
  final List<int> worstHoursToSkip;

  factory HourlyTollReport.fromJson(Map<String, dynamic> j) => HourlyTollReport(
        verdicts: (j['verdicts'] as List<dynamic>)
            .map((v) => HourlyTollVerdict.fromJson(v as Map<String, dynamic>))
            .toList(growable: false),
        bestHoursToSkip: (j['best_hours_to_skip'] as List<dynamic>)
            .map((h) => (h as num).toInt())
            .toList(growable: false),
        worstHoursToSkip: (j['worst_hours_to_skip'] as List<dynamic>)
            .map((h) => (h as num).toInt())
            .toList(growable: false),
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
    this.tollAlternative,
    this.optimizations,
    this.hourlyTollReport,
  });

  final RouteInfo route;
  final List<TimeWindow> timeWindows;
  final List<FuelPrice> fuelPrices;
  final List<Hotel> hotels;
  final List<Restaurant> restaurants;
  final List<RestStop> restStops;
  final List<AdverseEvent> adverseEvents;
  final TollAlternative? tollAlternative;
  final Optimizations? optimizations;
  final HourlyTollReport? hourlyTollReport;

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
        tollAlternative: json['toll_alternative'] == null
            ? null
            : TollAlternative.fromJson(
                json['toll_alternative'] as Map<String, dynamic>,
              ),
        optimizations: json['optimizations'] == null
            ? null
            : Optimizations.fromJson(
                json['optimizations'] as Map<String, dynamic>,
              ),
        hourlyTollReport: json['hourly_toll_report'] == null
            ? null
            : HourlyTollReport.fromJson(
                json['hourly_toll_report'] as Map<String, dynamic>,
              ),
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

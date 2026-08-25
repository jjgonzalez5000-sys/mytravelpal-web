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

/// Every country the backend understands. Keep in sync with
/// `backend/app/data/countries.py`.
enum Country {
  ch('CH', 'Switzerland'),
  fr('FR', 'France'),
  it('IT', 'Italy'),
  es('ES', 'Spain'),
  no('NO', 'Norway'),
  se('SE', 'Sweden'),
  dk('DK', 'Denmark'),
  fi('FI', 'Finland'),
  is_('IS', 'Iceland'),
  de('DE', 'Germany'),
  at('AT', 'Austria'),
  be('BE', 'Belgium'),
  nl('NL', 'Netherlands'),
  lu('LU', 'Luxembourg'),
  ie('IE', 'Ireland'),
  gb('GB', 'United Kingdom'),
  pt('PT', 'Portugal'),
  gr('GR', 'Greece'),
  mt('MT', 'Malta'),
  cy('CY', 'Cyprus'),
  pl('PL', 'Poland'),
  cz('CZ', 'Czechia'),
  sk('SK', 'Slovakia'),
  hu('HU', 'Hungary'),
  si('SI', 'Slovenia'),
  hr('HR', 'Croatia'),
  ro('RO', 'Romania'),
  bg('BG', 'Bulgaria'),
  ee('EE', 'Estonia'),
  lv('LV', 'Latvia'),
  lt('LT', 'Lithuania');

  const Country(this.code, this.displayName);

  final String code;
  final String displayName;

  static Country fromCode(String code) {
    final upper = code.toUpperCase();
    for (final c in values) {
      if (c.code == upper) return c;
    }
    throw ArgumentError('Unknown country: $code');
  }
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
    this.includeRouteComparison = false,
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

  /// If true, the backend also returns two extra route variants
  /// (toll-free + scenic) alongside the fastest for a full comparison.
  final bool includeRouteComparison;

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
        if (includeRouteComparison) 'include_route_comparison': true,
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
    this.poiClass,
    this.poiType,
  });

  final String displayName;
  final LatLon coordinate;
  final Country country;

  /// OSM top-level class from Nominatim: `tourism`, `amenity`, `shop`,
  /// `natural`, `historic`, `place`, `leisure`, `railway`, `aeroway`,
  /// `office`, `building`, `highway`, `waterway`, `man_made`,
  /// `emergency`, `sport`, `craft`, `military`, `power`. Null for
  /// mock catalogue entries (they're just cities).
  final String? poiClass;

  /// OSM subtype. Pair with [poiClass] to look up an icon via
  /// `iconForPoi(poiClass, poiType, displayName)`.
  final String? poiType;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    final coord = json['coordinate'] as Map<String, dynamic>;
    return GeocodeResult(
      displayName: json['display_name'] as String,
      coordinate: LatLon(
        lat: (coord['lat'] as num).toDouble(),
        lon: (coord['lon'] as num).toDouble(),
      ),
      country: Country.fromCode(json['country'] as String),
      poiClass: json['poi_class'] as String?,
      poiType: json['poi_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'coordinate': {'lat': coordinate.lat, 'lon': coordinate.lon},
        'country': country.code,
        if (poiClass != null) 'poi_class': poiClass,
        if (poiType != null) 'poi_type': poiType,
      };

  @override
  bool operator ==(Object other) =>
      other is GeocodeResult &&
      other.displayName == displayName &&
      other.coordinate == coordinate &&
      other.country == country &&
      other.poiClass == poiClass &&
      other.poiType == poiType;

  @override
  int get hashCode =>
      Object.hash(displayName, coordinate, country, poiClass, poiType);
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
class PartialTollSkip {
  const PartialTollSkip({
    required this.label,
    required this.distanceFromOriginKm,
    required this.savingsEur,
    required this.timePenaltyMinutes,
    required this.extraDistanceKm,
    required this.worthIt,
    required this.coordinate,
  });

  final String label;
  final double distanceFromOriginKm;
  final double savingsEur;
  final double timePenaltyMinutes;
  final double extraDistanceKm;
  final bool worthIt;
  final LatLon coordinate;

  factory PartialTollSkip.fromJson(Map<String, dynamic> j) => PartialTollSkip(
        label: j['label'] as String,
        distanceFromOriginKm:
            (j['distance_from_origin_km'] as num).toDouble(),
        savingsEur: (j['savings_eur'] as num).toDouble(),
        timePenaltyMinutes:
            (j['time_penalty_minutes'] as num).toDouble(),
        extraDistanceKm: (j['extra_distance_km'] as num).toDouble(),
        worthIt: j['worth_it'] as bool,
        coordinate: LatLon(
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
        ),
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

/// Read a `Map<String, String>` from a possibly-null JSON dict. Backend
/// always sends an empty object for entries with no OSM tags; older
/// clients that pre-date the field see null and fall back to empty.
Map<String, String> _readAttrs(Object? raw) {
  if (raw is! Map) return const {};
  return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
}

@immutable
class FuelPrice {
  const FuelPrice({
    required this.stationName,
    required this.country,
    required this.priceEurPerL,
    required this.distanceFromOriginKm,
    this.coordinate,
    this.attributes = const {},
  });

  final String stationName;
  final Country country;
  final double priceEurPerL;
  final double distanceFromOriginKm;

  /// Present only when the backend was able to attach one. Mock fuel
  /// prices along a route don't carry coordinates yet; Overpass ones do.
  final LatLon? coordinate;

  /// Curated OSM tags from the backend (brand, opening_hours,
  /// payment options, fuel types available, car_wash, shop). Empty
  /// for mock stations.
  final Map<String, String> attributes;

  factory FuelPrice.fromJson(Map<String, dynamic> json) => FuelPrice(
        stationName: json['station_name'] as String,
        country: Country.fromCode(json['country'] as String),
        priceEurPerL: (json['price_eur_per_l'] as num).toDouble(),
        distanceFromOriginKm:
            (json['distance_from_origin_km'] as num).toDouble(),
        coordinate: (json['lat'] == null || json['lon'] == null)
            ? null
            : LatLon(
                lat: (json['lat'] as num).toDouble(),
                lon: (json['lon'] as num).toDouble(),
              ),
        attributes: _readAttrs(json['attributes']),
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
    this.attributes = const {},
  });

  final String name;
  final Country country;
  final double priceEurPerNight;
  final PriceBand priceBand;
  final double detourMinutes;
  final double distanceFromRouteKm;
  final LatLon coordinate;

  /// Curated OSM tags from the backend — stars, phone, website,
  /// opening_hours, wheelchair, wifi, air_conditioning, breakfast,
  /// brand. Empty for mock hotels.
  final Map<String, String> attributes;

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
        attributes: _readAttrs(json['attributes']),
      );

  /// Stable identifier used to dedupe favorites across sessions.
  /// Name + country + rounded coordinate is stable enough for our use.
  String get favoriteId => 'hotel:${country.code}:'
      '${coordinate.lat.toStringAsFixed(3)}:'
      '${coordinate.lon.toStringAsFixed(3)}:$name';

  /// Minimal payload stored in `AppPrefs` — enough to render the tile
  /// in the Favorites screen without re-planning to fetch it back.
  Map<String, dynamic> toFavoriteJson() => {
        'id': favoriteId,
        'kind': 'hotel',
        'name': name,
        'country': country.code,
        'price_eur_per_night': priceEurPerNight,
        'price_band': priceBand.code,
        'lat': coordinate.lat,
        'lon': coordinate.lon,
      };
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
    this.attributes = const {},
  });

  final String name;
  final Country country;
  final double priceEurPerMeal;
  final PriceBand priceBand;
  final double detourMinutes;
  final double distanceFromRouteKm;
  final LatLon coordinate;

  /// Curated OSM tags — cuisine, phone, website, opening_hours,
  /// outdoor_seating, takeaway, delivery, wheelchair, dog, brand.
  /// Empty for mock restaurants.
  final Map<String, String> attributes;

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
        attributes: _readAttrs(json['attributes']),
      );

  String get favoriteId => 'restaurant:${country.code}:'
      '${coordinate.lat.toStringAsFixed(3)}:'
      '${coordinate.lon.toStringAsFixed(3)}:$name';

  Map<String, dynamic> toFavoriteJson() => {
        'id': favoriteId,
        'kind': 'restaurant',
        'name': name,
        'country': country.code,
        'price_eur_per_meal': priceEurPerMeal,
        'price_band': priceBand.code,
        'lat': coordinate.lat,
        'lon': coordinate.lon,
      };
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
class RouteVariant {
  const RouteVariant({
    required this.key,
    required this.label,
    required this.distanceKm,
    required this.freeFlowMinutes,
    required this.tollCostEur,
  });

  /// "fastest" | "toll_free" | "scenic"
  final String key;
  final String label;
  final double distanceKm;
  final double freeFlowMinutes;
  final double tollCostEur;

  factory RouteVariant.fromJson(Map<String, dynamic> j) => RouteVariant(
        key: j['key'] as String,
        label: j['label'] as String,
        distanceKm: (j['distance_km'] as num).toDouble(),
        freeFlowMinutes: (j['free_flow_minutes'] as num).toDouble(),
        tollCostEur: (j['toll_cost_eur'] as num).toDouble(),
      );
}

@immutable
class TripSavings {
  const TripSavings({
    required this.timeSavedMinutesVsDesired,
    required this.moneySavedEurVsTolls,
  });

  /// Minutes the recommendation saves vs the sample closest to the
  /// user's desired departure. Positive when the recommendation is
  /// faster. Zero when there's no better option.
  final double timeSavedMinutesVsDesired;

  /// EUR the driver would save if they took the toll-free alternative
  /// (only populated when the heuristic flags it as worth it).
  final double moneySavedEurVsTolls;

  factory TripSavings.fromJson(Map<String, dynamic> j) => TripSavings(
        timeSavedMinutesVsDesired:
            (j['time_saved_minutes_vs_desired'] as num).toDouble(),
        moneySavedEurVsTolls:
            (j['money_saved_eur_vs_tolls'] as num).toDouble(),
      );

  static const zero = TripSavings(
    timeSavedMinutesVsDesired: 0,
    moneySavedEurVsTolls: 0,
  );
}

/// Server-derived rendering hints for a trip.
///
/// Null when the request had no [TripProfile] — the client then
/// renders every section unconditionally (legacy behaviour). When
/// present, the client should hide sections whose corresponding flag
/// is false so long trips don't drown the user in noise.
@immutable
class RecommendationScope {
  const RecommendationScope({
    required this.showRestStops,
    required this.showHotels,
    required this.showRestaurants,
    required this.requiresOvernight,
    required this.restStopsCountTarget,
    required this.arrivalAfterBedtime,
    required this.arrivalLocalHour,
    required this.reason,
  });

  final bool showRestStops;
  final bool showHotels;
  final bool showRestaurants;
  final bool requiresOvernight;
  final int restStopsCountTarget;
  final bool arrivalAfterBedtime;
  final int arrivalLocalHour;
  final String reason;

  factory RecommendationScope.fromJson(Map<String, dynamic> j) =>
      RecommendationScope(
        showRestStops: j['show_rest_stops'] as bool? ?? true,
        showHotels: j['show_hotels'] as bool? ?? true,
        showRestaurants: j['show_restaurants'] as bool? ?? true,
        requiresOvernight: j['requires_overnight'] as bool? ?? false,
        restStopsCountTarget: (j['rest_stops_count_target'] as num?)?.toInt() ?? 0,
        arrivalAfterBedtime: j['arrival_after_bedtime'] as bool? ?? false,
        arrivalLocalHour: (j['arrival_local_hour'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String? ?? '',
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
    this.partialTollSkips = const [],
    this.optimizations,
    this.hourlyTollReport,
    this.savings = TripSavings.zero,
    this.routeVariants = const [],
    this.recommendationScope,
  });

  final RouteInfo route;
  final List<TimeWindow> timeWindows;
  final List<FuelPrice> fuelPrices;
  final List<Hotel> hotels;
  final List<Restaurant> restaurants;
  final List<RestStop> restStops;
  final List<AdverseEvent> adverseEvents;
  final TollAlternative? tollAlternative;
  final List<PartialTollSkip> partialTollSkips;
  final Optimizations? optimizations;
  final HourlyTollReport? hourlyTollReport;
  final TripSavings savings;
  final List<RouteVariant> routeVariants;
  final RecommendationScope? recommendationScope;

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
        partialTollSkips:
            (json['partial_toll_skips'] as List<dynamic>? ?? const [])
                .map((s) => PartialTollSkip.fromJson(s as Map<String, dynamic>))
                .toList(growable: false),
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
        savings: json['savings'] == null
            ? TripSavings.zero
            : TripSavings.fromJson(json['savings'] as Map<String, dynamic>),
        routeVariants:
            (json['route_variants'] as List<dynamic>? ?? const [])
                .map((v) => RouteVariant.fromJson(v as Map<String, dynamic>))
                .toList(growable: false),
        recommendationScope: json['recommendation_scope'] == null
            ? null
            : RecommendationScope.fromJson(
                json['recommendation_scope'] as Map<String, dynamic>,
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

import 'package:flutter/material.dart';

import '../domain/trip_profile.dart';
import '../l10n/app_localizations.dart';

enum AdverseEventType {
  fire,
  strike,
  weather,
  accident,
  roadwork,
  flood,
  snow,
  protest,
  earthquake,
  landslide,
  avalanche,
  closure,
  heatwave,
  other;

  String get code => name;

  /// English fallback — prefer `localized(l)` in UI code so the label
  /// follows the app locale.
  String get displayName => switch (this) {
        AdverseEventType.fire => 'Fire',
        AdverseEventType.strike => 'Strike',
        AdverseEventType.weather => 'Adverse weather',
        AdverseEventType.accident => 'Accident',
        AdverseEventType.roadwork => 'Roadwork',
        AdverseEventType.flood => 'Flood',
        AdverseEventType.snow => 'Snow',
        AdverseEventType.protest => 'Protest',
        AdverseEventType.earthquake => 'Earthquake',
        AdverseEventType.landslide => 'Landslide',
        AdverseEventType.avalanche => 'Avalanche',
        AdverseEventType.closure => 'Road closure',
        AdverseEventType.heatwave => 'Heatwave',
        AdverseEventType.other => 'Other',
      };

  String localized(AppLocalizations l) => switch (this) {
        AdverseEventType.fire => l.eventTypeFire,
        AdverseEventType.strike => l.eventTypeStrike,
        AdverseEventType.weather => l.eventTypeWeather,
        AdverseEventType.accident => l.eventTypeAccident,
        AdverseEventType.roadwork => l.eventTypeRoadwork,
        AdverseEventType.flood => l.eventTypeFlood,
        AdverseEventType.snow => l.eventTypeSnow,
        AdverseEventType.protest => l.eventTypeProtest,
        AdverseEventType.earthquake => l.eventTypeEarthquake,
        AdverseEventType.landslide => l.eventTypeLandslide,
        AdverseEventType.avalanche => l.eventTypeAvalanche,
        AdverseEventType.closure => l.eventTypeClosure,
        AdverseEventType.heatwave => l.eventTypeHeatwave,
        AdverseEventType.other => l.eventTypeOther,
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
        AdverseEventType.earthquake => Icons.vibration,
        AdverseEventType.landslide => Icons.landscape,
        AdverseEventType.avalanche => Icons.ac_unit,
        AdverseEventType.closure => Icons.block,
        AdverseEventType.heatwave => Icons.wb_sunny,
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

  String localized(AppLocalizations l) => switch (this) {
        AdverseEventSeverity.info => l.eventSeverityInfo,
        AdverseEventSeverity.warning => l.eventSeverityWarning,
        AdverseEventSeverity.critical => l.eventSeverityCritical,
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

  factory LatLon.fromJson(Map<String, dynamic> j) => LatLon(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is LatLon && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

/// Parking option returned by `POST /v1/pois/parking`. Used both
/// from the plan flow (per-waypoint "necesito parking") and from
/// the standalone "search parking near event" home entry.
@immutable
class Parking {
  const Parking({
    required this.name,
    required this.coordinate,
    required this.country,
    required this.distanceFromQueryKm,
    this.priceEurPerHour,
    this.maxStayHours,
    this.covered,
    this.capacity,
    this.kind = 'surface',
    this.kidFriendly,
    this.dogsAllowed,
    this.toilets,
    this.showers,
    this.foodNearby,
    this.evCharging,
    this.fuelStation,
    this.wheelchairAccess,
    this.supervised,
    this.rvFriendly,
    this.truckFriendly,
    this.parkAndRide,
    this.attributes = const {},
  });

  final String name;
  final LatLon coordinate;
  final Country country;
  final double distanceFromQueryKm;
  final double? priceEurPerHour;
  final double? maxStayHours;
  final bool? covered;
  final int? capacity;
  final String kind;
  final bool? kidFriendly;
  final bool? dogsAllowed;
  final bool? toilets;
  final bool? showers;
  final bool? foodNearby;
  final bool? evCharging;
  final bool? fuelStation;
  final bool? wheelchairAccess;
  final bool? supervised;
  final bool? rvFriendly;
  final bool? truckFriendly;
  final bool? parkAndRide;
  final Map<String, String> attributes;

  factory Parking.fromJson(Map<String, dynamic> j) => Parking(
        name: j['name'] as String? ?? 'Parking',
        coordinate: LatLon(
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
        ),
        country: Country.fromCode(j['country'] as String),
        distanceFromQueryKm:
            (j['distance_from_query_km'] as num).toDouble(),
        priceEurPerHour:
            (j['price_eur_per_hour'] as num?)?.toDouble(),
        maxStayHours: (j['max_stay_hours'] as num?)?.toDouble(),
        covered: j['covered'] as bool?,
        capacity: (j['capacity'] as num?)?.toInt(),
        kind: (j['kind'] as String?) ?? 'surface',
        kidFriendly: j['kid_friendly'] as bool?,
        dogsAllowed: j['dogs_allowed'] as bool?,
        toilets: j['toilets'] as bool?,
        showers: j['showers'] as bool?,
        foodNearby: j['food_nearby'] as bool?,
        evCharging: j['ev_charging'] as bool?,
        fuelStation: j['fuel_station'] as bool?,
        wheelchairAccess: j['wheelchair_access'] as bool?,
        supervised: j['supervised'] as bool?,
        rvFriendly: j['rv_friendly'] as bool?,
        truckFriendly: j['truck_friendly'] as bool?,
        parkAndRide: j['park_and_ride'] as bool?,
        attributes: (j['attributes'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

/// Set of parking amenity filters. Sent to the backend as
/// separate query params. `true` = the driver requires that
/// amenity; `false` (default) = no requirement.
class ParkingFilters {
  const ParkingFilters({
    this.kidFriendly = false,
    this.dogs = false,
    this.toilets = false,
    this.showers = false,
    this.food = false,
    this.ev = false,
    this.fuel = false,
    this.wheelchair = false,
    this.rv = false,
    this.truck = false,
  });
  final bool kidFriendly;
  final bool dogs;
  final bool toilets;
  final bool showers;
  final bool food;
  final bool ev;
  final bool fuel;
  final bool wheelchair;
  final bool rv;
  final bool truck;

  ParkingFilters copyWith({
    bool? kidFriendly, bool? dogs, bool? toilets, bool? showers,
    bool? food, bool? ev, bool? fuel, bool? wheelchair, bool? rv,
    bool? truck,
  }) => ParkingFilters(
        kidFriendly: kidFriendly ?? this.kidFriendly,
        dogs: dogs ?? this.dogs,
        toilets: toilets ?? this.toilets,
        showers: showers ?? this.showers,
        food: food ?? this.food,
        ev: ev ?? this.ev,
        fuel: fuel ?? this.fuel,
        wheelchair: wheelchair ?? this.wheelchair,
        rv: rv ?? this.rv,
        truck: truck ?? this.truck,
      );

  Map<String, String> toQueryParams() => {
        if (kidFriendly) 'require_kid_friendly': 'true',
        if (dogs) 'require_dogs': 'true',
        if (toilets) 'require_toilets': 'true',
        if (showers) 'require_showers': 'true',
        if (food) 'require_food': 'true',
        if (ev) 'require_ev': 'true',
        if (fuel) 'require_fuel': 'true',
        if (wheelchair) 'require_wheelchair': 'true',
        if (rv) 'require_rv': 'true',
        if (truck) 'require_truck': 'true',
      };
}

@immutable
/// Intermediate stop with an optional dwell time. `dwellNights = 0`
/// (default) is a pass-through — router visits the coord but the
/// plan doesn't stay. `dwellNights >= 1` forces the day plan to
/// stay N nights at the coord and densifies hotels around it.
@immutable
class TripWaypoint {
  const TripWaypoint({
    required this.coordinate,
    this.dwellNights = 0,
    this.label,
  });

  final LatLon coordinate;
  final int dwellNights;
  final String? label;

  Map<String, dynamic> toJson() => {
        'lat': coordinate.lat,
        'lon': coordinate.lon,
        'dwell_nights': dwellNights,
        if (label != null && label!.isNotEmpty) 'label': label,
      };

  TripWaypoint copyWith({int? dwellNights, String? label}) => TripWaypoint(
        coordinate: coordinate,
        dwellNights: dwellNights ?? this.dwellNights,
        label: label ?? this.label,
      );
}

class TripPlanRequest {
  const TripPlanRequest({
    required this.origin,
    required this.destination,
    required this.desiredDepartureAt,
    this.waypoints = const [],
    this.countries,
    this.hotelMaxDetourMinutes,
    this.hotelPriceBand,
    this.hotelPriceBands,
    this.hotelMinStars,
    this.restaurantMaxDetourMinutes,
    this.restaurantPriceBand,
    this.restaurantPriceBands,
    this.restaurantCuisines,
    this.hotelIncludeOther = false,
    this.hotelDestinationRadiusKm,
    this.hotelConditions,
    this.restaurantConditions,
    this.includeAdverseEvents = false,
    this.adverseEventsMaxDistanceKm = 25.0,
    this.includeTollAlternative = false,
    this.includeRouteComparison = false,
    this.includeHourlyTollAnalysis = false,
    this.avoidMotorways = false,
    this.preferScenic = false,
    this.timeWindowSpanHours = 3,
    this.timeWindowTopN = 5,
    this.tripProfile,
    this.includeParking = false,
  });

  final LatLon origin;
  final LatLon destination;
  final DateTime desiredDepartureAt;

  /// Intermediate stops the router visits in order between origin
  /// and destination. Empty = point-to-point. Backend caps at 8.
  final List<TripWaypoint> waypoints;

  /// Optional. When null the backend infers countries from the coordinates.
  final List<Country>? countries;

  /// When > 0, the backend searches for hotels within this round-trip
  /// detour off the route. Null or 0 disables the hotel search.
  final int? hotelMaxDetourMinutes;

  /// Legacy single-band. Prefer `hotelPriceBands` when the user has
  /// multi-select preferences.
  final PriceBand? hotelPriceBand;

  /// Multi-band filter. Wins over `hotelPriceBand` when set. An empty
  /// list or one containing `PriceBand.any` disables filtering.
  final List<PriceBand>? hotelPriceBands;

  /// Minimum OSM `stars` self-declared rating (1-5). Hotels lacking
  /// the tag are dropped when this is set — the OSM community
  /// doesn't tag every property so the pool shrinks fast.
  final int? hotelMinStars;

  /// When > 0, the backend searches for restaurants within this
  /// round-trip detour off the route. Null or 0 disables.
  final int? restaurantMaxDetourMinutes;

  /// Legacy single-band. Prefer `restaurantPriceBands`.
  final PriceBand? restaurantPriceBand;

  /// Multi-band filter for restaurants.
  final List<PriceBand>? restaurantPriceBands;

  /// OSM `cuisine` whitelist. Empty / null = no cuisine filter.
  final List<String>? restaurantCuisines;

  final bool hotelIncludeOther;
  /// Extra hotel-search radius around the destination (5–100 km).
  /// Null means "use backend default (40 km)".
  final int? hotelDestinationRadiusKm;
  final String? hotelConditions;
  final String? restaurantConditions;

  /// If true, include known adverse events (fires, strikes, weather,
  /// accidents, roadworks, floods, snow, protests) along the route.
  /// When true, the response ships a `parkings[]` list of options
  /// near the trip destination (5-10 sorted by distance). Off by
  /// default so the plan endpoint stays fast for drivers who
  /// don't care about parking.
  final bool includeParking;
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

  /// Half-width of the departure-time window in hours (±). Default 3.
  /// The result screen slider lets the user push it up to 12.
  final int timeWindowSpanHours;

  /// Number of candidate departure times to show. Default 5, up to
  /// 24 when the user expands the window.
  final int timeWindowTopN;

  /// Trip profile (vehicle + travellers + meals). When present the
  /// backend applies profile-aware ranking to POIs and computes trip
  /// optimizations (meal stops, sleep stop, fuel cost).
  final TripProfile? tripProfile;

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'desired_departure_at': desiredDepartureAt.toIso8601String(),
        if (waypoints.isNotEmpty)
          'waypoints': waypoints.map((w) => w.toJson()).toList(),
        if (countries != null)
          'countries': countries!.map((c) => c.code).toList(),
        if (hotelMaxDetourMinutes != null)
          'hotel_max_detour_minutes': hotelMaxDetourMinutes,
        if (hotelPriceBand != null) 'hotel_price_band': hotelPriceBand!.code,
        if (hotelPriceBands != null && hotelPriceBands!.isNotEmpty)
          'hotel_price_bands':
              hotelPriceBands!.map((b) => b.code).toList(),
        if (hotelMinStars != null && hotelMinStars! > 0)
          'hotel_min_stars': hotelMinStars,
        if (restaurantMaxDetourMinutes != null)
          'restaurant_max_detour_minutes': restaurantMaxDetourMinutes,
        if (restaurantPriceBand != null)
          'restaurant_price_band': restaurantPriceBand!.code,
        if (restaurantPriceBands != null &&
            restaurantPriceBands!.isNotEmpty)
          'restaurant_price_bands':
              restaurantPriceBands!.map((b) => b.code).toList(),
        if (restaurantCuisines != null && restaurantCuisines!.isNotEmpty)
          'restaurant_cuisines': restaurantCuisines,
        if (hotelIncludeOther) 'hotel_include_other': true,
        if (hotelDestinationRadiusKm != null)
          'hotel_destination_radius_km': hotelDestinationRadiusKm,
        if (hotelConditions != null && hotelConditions!.isNotEmpty)
          'hotel_conditions': hotelConditions,
        if (restaurantConditions != null && restaurantConditions!.isNotEmpty)
          'restaurant_conditions': restaurantConditions,
        if (includeParking) 'include_parking': true,
        if (includeAdverseEvents) 'include_adverse_events': true,
        if (includeAdverseEvents)
          'adverse_events_max_distance_km': adverseEventsMaxDistanceKm,
        if (includeTollAlternative) 'include_toll_alternative': true,
        if (includeRouteComparison) 'include_route_comparison': true,
        if (includeHourlyTollAnalysis) 'include_hourly_toll_analysis': true,
        if (avoidMotorways) 'avoid_motorways': true,
        if (preferScenic) 'prefer_scenic': true,
        if (timeWindowSpanHours != 3)
          'time_window_span_hours': timeWindowSpanHours,
        if (timeWindowTopN != 5) 'time_window_top_n': timeWindowTopN,
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

  /// Text to render as the event's primary caption. For events
  /// generated automatically (weather, EFFIS, mock) the raw
  /// `description` field is untranslated English ("Thunderstorm",
  /// "Wildfire near motorway — heavy smoke.") — we replace it
  /// with the localised type label so ES/FR/DE/IT/PT/CA drivers
  /// don't see English strings. User-marked events keep their
  /// original description because the reporter wrote it in their
  /// own language.
  String displayText(AppLocalizations l) {
    if (source == 'user') return description;
    return type.localized(l);
  }

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
    this.kind = 'named',
    this.index = 1,
    this.total,
    required this.distanceFromOriginKm,
    required this.savingsEur,
    required this.timePenaltyMinutes,
    required this.extraDistanceKm,
    required this.worthIt,
    required this.coordinate,
  });

  final String label;

  /// Machine-readable label class the client localises against:
  /// - `stretch` — heuristic segment split (uses [index] / [total]).
  /// - `booth`   — real toll booth without a proper name (uses [index]).
  /// - `named`   — real toll booth whose [label] is a proper place name;
  ///               render [label] unchanged.
  final String kind;
  final int index;
  final int? total;
  final double distanceFromOriginKm;
  final double savingsEur;
  final double timePenaltyMinutes;
  final double extraDistanceKm;
  final bool worthIt;
  final LatLon coordinate;

  String localizedLabel(AppLocalizations l) {
    if (kind == 'stretch' && total != null) {
      return l.tollStretchLabel(index, total!);
    }
    if (kind == 'booth') {
      return l.tollBoothLabel(index);
    }
    return label;
  }

  factory PartialTollSkip.fromJson(Map<String, dynamic> j) => PartialTollSkip(
        label: j['label'] as String? ?? '',
        kind: j['kind'] as String? ?? 'named',
        index: (j['index'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt(),
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
class IntraSectionSkip {
  const IntraSectionSkip({
    required this.sectionName,
    required this.exitGateName,
    required this.exitLat,
    required this.exitLon,
    required this.reentryGateName,
    required this.reentryLat,
    required this.reentryLon,
    required this.fullSectionEur,
    required this.bypassEur,
    required this.savingsEur,
    required this.freeRoadKm,
    required this.timePenaltyMinutes,
    required this.worthIt,
  });

  final String sectionName;
  final String exitGateName;
  final double exitLat;
  final double exitLon;
  final String reentryGateName;
  final double reentryLat;
  final double reentryLon;
  final double fullSectionEur;
  final double bypassEur;
  final double savingsEur;
  final double freeRoadKm;
  final double timePenaltyMinutes;
  final bool worthIt;

  factory IntraSectionSkip.fromJson(Map<String, dynamic> j) =>
      IntraSectionSkip(
        sectionName: j['section_name'] as String? ?? '',
        exitGateName: j['exit_gate_name'] as String? ?? '',
        exitLat: (j['exit_lat'] as num).toDouble(),
        exitLon: (j['exit_lon'] as num).toDouble(),
        reentryGateName: j['reentry_gate_name'] as String? ?? '',
        reentryLat: (j['reentry_lat'] as num).toDouble(),
        reentryLon: (j['reentry_lon'] as num).toDouble(),
        fullSectionEur: (j['full_section_eur'] as num).toDouble(),
        bypassEur: (j['bypass_eur'] as num).toDouble(),
        savingsEur: (j['savings_eur'] as num).toDouble(),
        freeRoadKm: (j['free_road_km'] as num).toDouble(),
        timePenaltyMinutes: (j['time_penalty_minutes'] as num).toDouble(),
        worthIt: j['worth_it'] as bool? ?? false,
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
    this.priceAvailable = true,
    this.savingsVsCountryMedianEurPerL,
    required this.distanceFromOriginKm,
    this.coordinate,
    this.attributes = const {},
    this.unitLabel = '€/L',
    this.isChargingStation = false,
  });

  final String stationName;
  final Country country;
  final double priceEurPerL;

  /// False when the backend knows the station exists (via OSM /
  /// Nominatim) but has no price feed for that country. In that case
  /// [priceEurPerL] is a placeholder — render "no price" instead.
  final bool priceAvailable;

  /// €/L below the country median. Positive = cheaper than median
  /// (a deal); negative = pricier. Null when the backend can't
  /// compute one (single-country trip with too few stations, or
  /// unavailable price). Rendered as a small chip on the tile.
  final double? savingsVsCountryMedianEurPerL;

  final double distanceFromOriginKm;

  /// Present only when the backend was able to attach one. Mock fuel
  /// prices along a route don't carry coordinates yet; Overpass ones do.
  final LatLon? coordinate;

  /// Curated OSM tags from the backend (brand, opening_hours,
  /// payment options, fuel types available, car_wash, shop). Empty
  /// for mock stations.
  final Map<String, String> attributes;

  /// Display unit — `€/L` for liquid fuels, `€/kWh` for EV
  /// chargers. Backend sets it based on the requested vehicle
  /// fuel type; the UI reads it instead of hard-coding `€/L`.
  final String unitLabel;

  /// True when the entry is an EV charging point rather than a
  /// liquid-fuel station. Drives icon + list eyebrow copy.
  final bool isChargingStation;

  factory FuelPrice.fromJson(Map<String, dynamic> json) => FuelPrice(
        stationName: json['station_name'] as String,
        country: Country.fromCode(json['country'] as String),
        priceEurPerL: (json['price_eur_per_l'] as num).toDouble(),
        priceAvailable: (json['price_available'] as bool?) ?? true,
        savingsVsCountryMedianEurPerL:
            (json['savings_vs_country_median_eur_per_l'] as num?)?.toDouble(),
        distanceFromOriginKm:
            (json['distance_from_origin_km'] as num).toDouble(),
        coordinate: (json['lat'] == null || json['lon'] == null)
            ? null
            : LatLon(
                lat: (json['lat'] as num).toDouble(),
                lon: (json['lon'] as num).toDouble(),
              ),
        attributes: _readAttrs(json['attributes']),
        unitLabel: (json['unit_label'] as String?) ?? '€/L',
        isChargingStation:
            (json['is_charging_station'] as bool?) ?? false,
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

/// Which meal slot(s) a restaurant is typically open for. Mirrors the
/// backend `MealSlot` enum. Kept as strings so an unknown value from a
/// future backend degrades to `other` instead of crashing.
enum MealSlot { breakfast, lunch, dinner }

MealSlot? _mealSlotFromCode(String code) {
  return switch (code.toLowerCase()) {
    'breakfast' => MealSlot.breakfast,
    'lunch' => MealSlot.lunch,
    'dinner' => MealSlot.dinner,
    _ => null,
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
    this.openMealSlots = const [],
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

  /// Meal slots this place typically covers (from OSM `cuisine` /
  /// `opening_hours` heuristics). Used by result screen to group
  /// restaurants under "Suggested for lunch/dinner" sections.
  final List<MealSlot> openMealSlots;

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
        openMealSlots: (json['open_meal_slots'] as List<dynamic>? ?? const [])
            .map((s) => _mealSlotFromCode(s as String))
            .whereType<MealSlot>()
            .toList(growable: false),
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
    this.cityHint,
    this.coordinate,
  });

  final String slot;
  final DateTime at;
  final double distanceFromOriginKm;
  final String? restaurantName;
  final double? restaurantPriceEurPerMeal;
  final LatLon? restaurantCoordinate;
  /// Reverse-geocoded city name near the stop coord ("Toledo").
  /// Rendered in the row as "Cerca de X".
  final String? cityHint;
  /// Coord for the mini-map thumbnail (restaurant if picked,
  /// otherwise the rest-stop coord that anchors the meal slot).
  final LatLon? coordinate;

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
        cityHint: j['city_hint'] as String?,
        coordinate: j['lat'] == null
            ? null
            : LatLon(
                lat: (j['lat'] as num).toDouble(),
                lon: (j['lon'] as num).toDouble(),
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
    this.cityHint,
    this.coordinate,
  });

  final DateTime at;
  final double distanceFromOriginKm;
  final String? hotelName;
  final double? hotelPriceEurPerNight;
  final LatLon? hotelCoordinate;
  final String? cityHint;
  final LatLon? coordinate;

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
        cityHint: j['city_hint'] as String?,
        coordinate: j['lat'] == null
            ? null
            : LatLon(
                lat: (j['lat'] as num).toDouble(),
                lon: (j['lon'] as num).toDouble(),
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
/// Slim parking payload returned inside `TripPlanResponse.parkings`.
/// Contains just the fields the "Parkings cerca del destino" list
/// on the result screen renders, keyed to distance from the trip
/// destination rather than a query point.
@immutable
class PlanParking {
  const PlanParking({
    required this.name,
    required this.coordinate,
    required this.country,
    required this.distanceFromDestinationKm,
    this.priceEurPerHour,
    this.covered,
    this.capacity,
    this.kind = 'surface',
    this.kidFriendly,
    this.dogsAllowed,
    this.toilets,
    this.foodNearby,
    this.evCharging,
    this.rvFriendly,
  });

  final String name;
  final LatLon coordinate;
  final Country country;
  final double distanceFromDestinationKm;
  final double? priceEurPerHour;
  final bool? covered;
  final int? capacity;
  final String kind;
  final bool? kidFriendly;
  final bool? dogsAllowed;
  final bool? toilets;
  final bool? foodNearby;
  final bool? evCharging;
  final bool? rvFriendly;

  factory PlanParking.fromJson(Map<String, dynamic> j) => PlanParking(
        name: j['name'] as String? ?? 'Parking',
        coordinate: LatLon(
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
        ),
        country: Country.fromCode(j['country'] as String),
        distanceFromDestinationKm:
            (j['distance_from_destination_km'] as num).toDouble(),
        priceEurPerHour:
            (j['price_eur_per_hour'] as num?)?.toDouble(),
        covered: j['covered'] as bool?,
        capacity: (j['capacity'] as num?)?.toInt(),
        kind: (j['kind'] as String?) ?? 'surface',
        kidFriendly: j['kid_friendly'] as bool?,
        dogsAllowed: j['dogs_allowed'] as bool?,
        toilets: j['toilets'] as bool?,
        foodNearby: j['food_nearby'] as bool?,
        evCharging: j['ev_charging'] as bool?,
        rvFriendly: j['rv_friendly'] as bool?,
      );
}

class TripPlanResponse {
  const TripPlanResponse({
    required this.route,
    required this.timeWindows,
    required this.fuelPrices,
    required this.hotels,
    required this.restaurants,
    this.parkings = const [],
    required this.restStops,
    required this.adverseEvents,
    this.tollAlternative,
    this.partialTollSkips = const [],
    this.intraSectionSkips = const [],
    this.optimizations,
    this.hourlyTollReport,
    this.savings = TripSavings.zero,
    this.routeVariants = const [],
    this.recommendationScope,
    this.consistencyIssues = const [],
    this.fuelArbitrage,
    this.days = const [],
    this.weatherSegments = const [],
    this.rawJson,
  });

  /// Untouched decoded JSON from the API. Retained by
  /// `TripPlanResponse.fromJson` so `TripSessionPersistence` can
  /// re-serialise the exact response bytes without needing every
  /// nested type to gain its own `toJson`. Null when constructed
  /// synthetically (tests, session restore fallback).
  final Map<String, dynamic>? rawJson;

  final RouteInfo route;
  final List<TimeWindow> timeWindows;
  final List<FuelPrice> fuelPrices;
  final List<Hotel> hotels;
  final List<Restaurant> restaurants;
  /// Parkings near the trip destination. Populated only when the
  /// plan form's "Parking" toggle was on; empty otherwise. Sorted
  /// by distance from destination ascending.
  final List<PlanParking> parkings;
  final List<RestStop> restStops;
  final List<AdverseEvent> adverseEvents;
  final TollAlternative? tollAlternative;
  final List<PartialTollSkip> partialTollSkips;
  final List<IntraSectionSkip> intraSectionSkips;
  final Optimizations? optimizations;
  final HourlyTollReport? hourlyTollReport;
  final TripSavings savings;
  final List<RouteVariant> routeVariants;
  final RecommendationScope? recommendationScope;
  final List<ConsistencyIssue> consistencyIssues;
  final FuelArbitrage? fuelArbitrage;
  final List<DayPlan> days;
  final List<WeatherSegment> weatherSegments;

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
        parkings:
            (json['parkings'] as List<dynamic>? ?? const <dynamic>[])
                .map((p) => PlanParking.fromJson(p as Map<String, dynamic>))
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
        intraSectionSkips:
            (json['intra_section_skips'] as List<dynamic>? ?? const [])
                .map((s) =>
                    IntraSectionSkip.fromJson(s as Map<String, dynamic>))
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
        consistencyIssues:
            (json['consistency_issues'] as List<dynamic>? ?? const [])
                .map((i) =>
                    ConsistencyIssue.fromJson(i as Map<String, dynamic>))
                .toList(growable: false),
        fuelArbitrage: json['fuel_arbitrage'] == null
            ? null
            : FuelArbitrage.fromJson(
                json['fuel_arbitrage'] as Map<String, dynamic>,
              ),
        days: (json['days'] as List<dynamic>? ?? const [])
            .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
            .toList(growable: false),
        weatherSegments:
            (json['weather_segments'] as List<dynamic>? ?? const [])
                .map((w) =>
                    WeatherSegment.fromJson(w as Map<String, dynamic>))
                .toList(growable: false),
        // Retain the whole envelope so the session-persistence layer
        // can re-serialise the exact plan without a per-field
        // `toJson` on every nested type.
        rawJson: json,
      );
}

/// Advisory issue emitted by the backend consistency service. The
/// server ranks these most-severe first, so callers can pop
/// `consistencyIssues.first` into a banner and trust the priority.
@immutable
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.code,
    required this.severity,
    required this.message,
  });

  /// Machine-readable code (e.g. `meal.impossible_speed`,
  /// `fuel.range_exceeded`). Namespaced by subject.
  final String code;

  /// One of `error`, `warning`, `info` — kept as string to survive new
  /// severities added on the backend without breaking parsing.
  final String severity;
  final String message;

  bool get isError => severity == 'error';
  bool get isWarning => severity == 'warning';

  factory ConsistencyIssue.fromJson(Map<String, dynamic> json) =>
      ConsistencyIssue(
        code: json['code'] as String,
        severity: json['severity'] as String,
        message: json['message'] as String,
      );
}

/// Backend hint that fuel is materially cheaper in one country the
/// trip crosses vs another — user can save real money by refuelling
/// in the cheaper country before crossing.
@immutable
class FuelArbitrage {
  const FuelArbitrage({
    required this.cheaperCountry,
    required this.cheaperMedianEurPerL,
    required this.pricierCountry,
    required this.pricierMedianEurPerL,
    required this.deltaEurPerL,
    required this.estimatedTankSavingEur,
  });

  final Country cheaperCountry;
  final double cheaperMedianEurPerL;
  final Country pricierCountry;
  final double pricierMedianEurPerL;
  final double deltaEurPerL;
  final double estimatedTankSavingEur;

  factory FuelArbitrage.fromJson(Map<String, dynamic> j) => FuelArbitrage(
        cheaperCountry: Country.fromCode(j['cheaper_country'] as String),
        cheaperMedianEurPerL:
            (j['cheaper_median_eur_per_l'] as num).toDouble(),
        pricierCountry: Country.fromCode(j['pricier_country'] as String),
        pricierMedianEurPerL:
            (j['pricier_median_eur_per_l'] as num).toDouble(),
        deltaEurPerL: (j['delta_eur_per_l'] as num).toDouble(),
        estimatedTankSavingEur:
            (j['estimated_tank_saving_eur'] as num).toDouble(),
      );
}

/// One day of a multi-day trip. Emitted by the backend when the total
/// duration exceeds the driver's daily driving cap or the arrival
/// crosses their bedtime.
@immutable
@immutable
class WeatherSegment {
  const WeatherSegment({
    required this.fromKm,
    required this.toKm,
    required this.label,
    required this.icon,
    this.temperatureC,
    required this.coordinate,
  });

  final double fromKm;
  final double toKm;
  final String label;
  final String icon;
  final double? temperatureC;
  final LatLon coordinate;

  factory WeatherSegment.fromJson(Map<String, dynamic> j) => WeatherSegment(
        fromKm: (j['from_km'] as num).toDouble(),
        toKm: (j['to_km'] as num).toDouble(),
        label: j['label'] as String,
        icon: j['icon'] as String,
        temperatureC: (j['temperature_c'] as num?)?.toDouble(),
        coordinate: LatLon(
          lat: (j['lat'] as num).toDouble(),
          lon: (j['lon'] as num).toDouble(),
        ),
      );

  IconData get iconData => switch (icon) {
        'sunny' => Icons.wb_sunny_outlined,
        'partly_cloudy' => Icons.wb_cloudy,
        'cloudy' => Icons.cloud_outlined,
        'fog' => Icons.foggy,
        'drizzle' => Icons.grain,
        'rain' => Icons.water_drop_outlined,
        'heavy_rain' => Icons.thunderstorm,
        'snow' => Icons.ac_unit,
        'heavy_snow' => Icons.severe_cold,
        'thunderstorm' => Icons.flash_on,
        _ => Icons.wb_sunny_outlined,
      };

  /// Localise the weather family via `icon` (backend sends English
  /// `label` for backwards compat, but the `icon` string is a
  /// stable code — sunny / cloudy / rain / thunderstorm / … — that
  /// we map to the current app locale.
  String localizedLabel(AppLocalizations l) => switch (icon) {
        'sunny' => l.weatherSunny,
        'partly_cloudy' => l.weatherPartlyCloudy,
        'cloudy' => l.weatherCloudy,
        'fog' => l.weatherFog,
        'drizzle' => l.weatherDrizzle,
        'rain' => l.weatherRain,
        'heavy_rain' => l.weatherHeavyRain,
        'snow' => l.weatherSnow,
        'heavy_snow' => l.weatherHeavySnow,
        'thunderstorm' => l.weatherThunderstorm,
        _ => label,
      };
}

class DayPlan {
  const DayPlan({
    required this.dayIndex,
    required this.startAt,
    required this.endAt,
    required this.fromKm,
    required this.toKm,
    required this.mealStops,
    required this.restStops,
    this.sleepAt,
    this.sleepCoord,
    this.dwellLabel,
    this.fromName,
    this.toName,
    this.waypointAnchors = const [],
  });

  final int dayIndex;
  final DateTime startAt;
  final DateTime endAt;
  final double fromKm;
  final double toKm;
  final List<MealStopOpt> mealStops;
  final List<RestStop> restStops;
  final DateTime? sleepAt;

  /// Approximate coord where the driver would spend the night. Used
  /// to rank hotels for the day's "sleep nearby" card. `null` for
  /// the trip's final day.
  final LatLon? sleepCoord;

  /// When this day is anchored at a user-picked dwell waypoint,
  /// backend sends the label (city / hotel name / whatever the
  /// user typed when adding the stop). Mobile shows it in the day
  /// header instead of the raw "km A → B" range which reads as
  /// nonsense for stay-put days.
  final String? dwellLabel;

  /// Reverse-geocoded city name at the start/end of this day.
  final String? fromName;
  final String? toName;

  final List<WaypointAnchor> waypointAnchors;

  List<String> get waypointLabels =>
      waypointAnchors.map((a) => a.label).toList();

  /// True when this day is a stay-put day (no driving) at a dwell
  /// waypoint — same fromKm/toKm and a dwellLabel present.
  bool get isDwellDay =>
      dwellLabel != null && (toKm - fromKm).abs() < 1.0;

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        dayIndex: (j['day_index'] as num).toInt(),
        startAt: DateTime.parse(j['start_at'] as String),
        endAt: DateTime.parse(j['end_at'] as String),
        fromKm: (j['from_km'] as num).toDouble(),
        toKm: (j['to_km'] as num).toDouble(),
        mealStops: (j['meal_stops'] as List<dynamic>? ?? const [])
            .map((m) => MealStopOpt.fromJson(m as Map<String, dynamic>))
            .toList(growable: false),
        restStops: (j['rest_stops'] as List<dynamic>? ?? const [])
            .map((s) => RestStop.fromJson(s as Map<String, dynamic>))
            .toList(growable: false),
        sleepAt: j['sleep_at'] == null
            ? null
            : DateTime.parse(j['sleep_at'] as String),
        sleepCoord: (j['sleep_lat'] == null || j['sleep_lon'] == null)
            ? null
            : LatLon(
                lat: (j['sleep_lat'] as num).toDouble(),
                lon: (j['sleep_lon'] as num).toDouble(),
              ),
        dwellLabel: j['dwell_label'] as String?,
        fromName: j['from_name'] as String?,
        toName: j['to_name'] as String?,
        waypointAnchors: (j['waypoint_anchors'] as List<dynamic>?)
                ?.map((a) =>
                    WaypointAnchor.fromJson(a as Map<String, dynamic>))
                .toList(growable: false) ??
            (j['waypoint_labels'] as List<dynamic>? ?? const [])
                .cast<String>()
                .map((l) => WaypointAnchor(label: l, km: 0, lat: 0, lon: 0))
                .toList(growable: false),
      );
}

@immutable
class WaypointAnchor {
  const WaypointAnchor({
    required this.label,
    required this.km,
    required this.lat,
    required this.lon,
  });

  final String label;
  final double km;
  final double lat;
  final double lon;

  LatLon get coordinate => LatLon(lat: lat, lon: lon);

  factory WaypointAnchor.fromJson(Map<String, dynamic> j) => WaypointAnchor(
        label: j['label'] as String,
        km: (j['km'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
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

/// Snapshot the client posts to `/v1/companion/tick` every ~60s
/// while the Companion drive mode is active. The server-side
/// engine consumes this to decide which recommendation cards to
/// surface — see `backend/app/api/v1/companion.py`.
@immutable
class CompanionTickRequest {
  const CompanionTickRequest({
    required this.lat,
    required this.lon,
    this.speedKmh,
    this.headingDeg,
    this.drivingTimeHours = 0.0,
    this.breakIntervalHours = 2.0,
    this.alertWeather = true,
    this.alertFuel = true,
    this.alertBorder = true,
    this.alertToll = true,
    this.alertHotel = true,
    this.alertCriticalAdverse = true,
    this.suggestBreak = false,
    this.fatigueStopSuggestion = false,
    this.hasKids = false,
    this.hasPets = false,
    this.bedtimeHour = 22,
    this.dismissedKinds = const [],
  });

  final double lat;
  final double lon;
  final double? speedKmh;
  final double? headingDeg;
  final double drivingTimeHours;
  final double breakIntervalHours;
  final bool alertWeather;
  final bool alertFuel;
  final bool alertBorder;
  final bool alertToll;
  final bool alertHotel;
  /// Critical adverse events (fires/floods/quakes) alerts. Default
  /// ON — safety-first — but a first-class user preference so
  /// drivers who consciously want silence can flip it OFF.
  final bool alertCriticalAdverse;
  /// Whether the user opted into break-timer suggestions at all.
  /// When false, the client suppresses `break_interval_hours`
  /// entirely and the backend rule is bypassed by sending an
  /// interval so large it never fires.
  final bool suggestBreak;
  /// EXPERIMENTAL: pair every fatigue-timer fire with a "pull
  /// over now" recommendation. Only meaningful when [suggestBreak]
  /// is true. Off by default; the timer signal alone is noisy.
  final bool fatigueStopSuggestion;
  final bool hasKids;
  final bool hasPets;
  final int bedtimeHour;
  final List<String> dismissedKinds;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        if (speedKmh != null) 'speed_kmh': speedKmh,
        if (headingDeg != null) 'heading_deg': headingDeg,
        'driving_time_hours': drivingTimeHours,
        // When the driver opted out of break suggestions we send a
        // huge interval so the backend rule never fires. Cheaper
        // than adding a new field on both sides.
        'break_interval_hours': suggestBreak ? breakIntervalHours : 999.0,
        'alert_weather': alertWeather,
        'alert_fuel': alertFuel,
        'alert_border': alertBorder,
        'alert_toll': alertToll,
        'alert_hotel': alertHotel,
        'alert_critical_adverse': alertCriticalAdverse,
        'fatigue_stop_suggestion':
            suggestBreak && fatigueStopSuggestion,
        'has_kids': hasKids,
        'has_pets': hasPets,
        'bedtime_hour': bedtimeHour,
        'dismissed_kinds': dismissedKinds,
      };
}

/// One recommendation card the server returned. `priority` drives
/// the render style — `critical` blocks the UI until the driver
/// dismisses; others are stackable.
@immutable
class CompanionRecommendation {
  const CompanionRecommendation({
    required this.kind,
    required this.priority,
    required this.title,
    required this.body,
    this.speech,
    this.lat,
    this.lon,
    this.distanceKm,
    this.actions = const [],
  });

  final String kind;
  final String priority;
  final String title;
  final String body;
  final String? speech;
  final double? lat;
  final double? lon;
  final double? distanceKm;
  final List<CompanionAction> actions;

  bool get isCritical => priority == 'critical';

  factory CompanionRecommendation.fromJson(Map<String, dynamic> j) =>
      CompanionRecommendation(
        kind: j['kind'] as String,
        priority: j['priority'] as String? ?? 'normal',
        title: j['title'] as String,
        body: j['body'] as String,
        speech: j['speech'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        actions: (j['actions'] as List<dynamic>? ?? const [])
            .map((a) =>
                CompanionAction.fromJson(a as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Trip Inspiration LLM response models. See
/// `backend/app/api/v1/inspire.py`.
@immutable
class InspirePoi {
  const InspirePoi({
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
    required this.note,
  });

  final String name;
  final double lat;
  final double lon;
  final String kind;
  final String note;

  LatLon get coordinate => LatLon(lat: lat, lon: lon);

  factory InspirePoi.fromJson(Map<String, dynamic> j) => InspirePoi(
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        kind: j['kind'] as String? ?? 'other',
        note: j['note'] as String? ?? '',
      );
}

@immutable
class InspireDay {
  const InspireDay({
    required this.day,
    required this.fromName,
    required this.toName,
    this.distanceKmEstimate,
    this.drivingHoursEstimate,
    this.waypoints = const [],
    this.hotelArea,
    this.highlights = '',
  });

  final int day;
  final String fromName;
  final String toName;
  final double? distanceKmEstimate;
  final double? drivingHoursEstimate;
  final List<InspirePoi> waypoints;
  final String? hotelArea;
  final String highlights;

  factory InspireDay.fromJson(Map<String, dynamic> j) => InspireDay(
        day: (j['day'] as num).toInt(),
        fromName: j['from_name'] as String,
        toName: j['to_name'] as String,
        distanceKmEstimate: (j['distance_km_estimate'] as num?)?.toDouble(),
        drivingHoursEstimate:
            (j['driving_hours_estimate'] as num?)?.toDouble(),
        waypoints: (j['waypoints'] as List<dynamic>? ?? const [])
            .map((w) => InspirePoi.fromJson(w as Map<String, dynamic>))
            .toList(growable: false),
        hotelArea: j['hotel_area'] as String?,
        highlights: j['highlights'] as String? ?? '',
      );
}

@immutable
class InspireItinerary {
  const InspireItinerary({
    required this.summary,
    required this.days,
    this.totalDistanceKmEstimate,
    this.estimatedBudgetEur,
    this.suggestedDepartureIso,
    this.suggestedDepartureDaysFromNow,
    this.suggestedDepartureHour,
    this.assistantNote,
  });

  final String summary;
  final List<InspireDay> days;
  final double? totalDistanceKmEstimate;
  final double? estimatedBudgetEur;
  final String? suggestedDepartureIso;
  final int? suggestedDepartureDaysFromNow;
  final int? suggestedDepartureHour;
  /// Short assistant reply set by `/inspire/refine` explaining
  /// what changed in this turn. Rendered as a chat bubble below
  /// the itinerary. Null on fresh generations (the whole payload
  /// IS the introduction).
  final String? assistantNote;

  factory InspireItinerary.fromJson(Map<String, dynamic> j) =>
      InspireItinerary(
        summary: j['summary'] as String? ?? '',
        days: (j['days'] as List<dynamic>? ?? const [])
            .map((d) => InspireDay.fromJson(d as Map<String, dynamic>))
            .toList(growable: false),
        totalDistanceKmEstimate:
            (j['total_distance_km_estimate'] as num?)?.toDouble(),
        estimatedBudgetEur:
            (j['estimated_budget_eur'] as num?)?.toDouble(),
        suggestedDepartureIso: j['suggested_departure_iso'] as String?,
        suggestedDepartureDaysFromNow:
            (j['suggested_departure_days_from_now'] as num?)?.toInt(),
        suggestedDepartureHour:
            (j['suggested_departure_hour'] as num?)?.toInt(),
        assistantNote: j['assistant_note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'days': days
            .map((d) => {
                  'day': d.day,
                  'from_name': d.fromName,
                  'to_name': d.toName,
                  if (d.distanceKmEstimate != null)
                    'distance_km_estimate': d.distanceKmEstimate,
                  if (d.drivingHoursEstimate != null)
                    'driving_hours_estimate': d.drivingHoursEstimate,
                  'waypoints': d.waypoints
                      .map((w) => {
                            'name': w.name,
                            'lat': w.lat,
                            'lon': w.lon,
                            'kind': w.kind,
                            'note': w.note,
                          })
                      .toList(),
                  if (d.hotelArea != null) 'hotel_area': d.hotelArea,
                  'highlights': d.highlights,
                })
            .toList(),
        if (totalDistanceKmEstimate != null)
          'total_distance_km_estimate': totalDistanceKmEstimate,
        if (estimatedBudgetEur != null)
          'estimated_budget_eur': estimatedBudgetEur,
        if (suggestedDepartureIso != null)
          'suggested_departure_iso': suggestedDepartureIso,
        if (suggestedDepartureDaysFromNow != null)
          'suggested_departure_days_from_now':
              suggestedDepartureDaysFromNow,
        if (suggestedDepartureHour != null)
          'suggested_departure_hour': suggestedDepartureHour,
      };
}

/// One turn in the refinement chat. Persisted alongside the
/// itinerary so opening a saved inspiration keeps the context.
@immutable
class InspireChatTurn {
  const InspireChatTurn({required this.role, required this.content});
  final String role; // "user" | "assistant"
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory InspireChatTurn.fromJson(Map<String, dynamic> j) =>
      InspireChatTurn(
        role: j['role'] as String,
        content: j['content'] as String,
      );
}

@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.icon,
    this.tempMaxC,
    this.tempMinC,
    this.precipitationMm,
  });

  final DateTime date;
  final String icon;
  final double? tempMaxC;
  final double? tempMinC;
  final double? precipitationMm;

  factory DailyForecast.fromJson(Map<String, dynamic> j) => DailyForecast(
        date: DateTime.parse(j['date'] as String),
        icon: j['icon'] as String? ?? 'sunny',
        tempMaxC: (j['temp_max_c'] as num?)?.toDouble(),
        tempMinC: (j['temp_min_c'] as num?)?.toDouble(),
        precipitationMm: (j['precipitation_mm'] as num?)?.toDouble(),
      );
}

@immutable
class WeatherPoint {
  const WeatherPoint({
    required this.lat,
    required this.lon,
    this.currentTempC,
    this.currentIcon,
    this.daily = const [],
  });

  final double lat;
  final double lon;
  final double? currentTempC;
  final String? currentIcon;
  final List<DailyForecast> daily;

  factory WeatherPoint.fromJson(Map<String, dynamic> j) => WeatherPoint(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        currentTempC: (j['current_temp_c'] as num?)?.toDouble(),
        currentIcon: j['current_icon'] as String?,
        daily: (j['daily'] as List<dynamic>? ?? const [])
            .map((d) => DailyForecast.fromJson(d as Map<String, dynamic>))
            .toList(growable: false),
      );
}

@immutable
class CompanionAction {
  const CompanionAction({
    required this.kind,
    required this.label,
    this.payload = const {},
  });

  final String kind;
  final String label;
  final Map<String, dynamic> payload;

  factory CompanionAction.fromJson(Map<String, dynamic> j) =>
      CompanionAction(
        kind: j['kind'] as String,
        label: j['label'] as String,
        payload:
            (j['payload'] as Map<String, dynamic>?) ?? const {},
      );
}

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

@immutable
class TripPlanRequest {
  const TripPlanRequest({
    required this.origin,
    required this.destination,
    required this.desiredDepartureAt,
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
  });

  final LatLon origin;
  final LatLon destination;
  final DateTime desiredDepartureAt;

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
  final String? hotelConditions;
  final String? restaurantConditions;

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
        if (hotelConditions != null && hotelConditions!.isNotEmpty)
          'hotel_conditions': hotelConditions,
        if (restaurantConditions != null && restaurantConditions!.isNotEmpty)
          'restaurant_conditions': restaurantConditions,
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
        label: j['label'] as String,
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
  final List<RestStop> restStops;
  final List<AdverseEvent> adverseEvents;
  final TollAlternative? tollAlternative;
  final List<PartialTollSkip> partialTollSkips;
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

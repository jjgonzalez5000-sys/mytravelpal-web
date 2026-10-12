import '../api/models.dart' show LatLon;
import 'my_place.dart';

/// One AI-picked stop near the route. The place is always a real one from
/// the places provider; the model only chose it and wrote [why].
class StopSuggestion {
  const StopSuggestion({
    required this.id,
    required this.name,
    required this.coordinate,
    required this.category,
    required this.why,
    required this.visitMinutes,
    required this.detourMinutes,
    required this.distanceFromRouteKm,
    required this.alongKm,
    required this.fitsWindow,
    this.kind,
    this.picked = true,
    this.website,
    this.attributes = const {},
  });

  final String id;
  final String name;
  final LatLon coordinate;

  /// Provider category slug, e.g. `tourism.attraction.viewpoint`.
  final String category;

  /// Empty when the model did not take part.
  final String why;
  final int visitMinutes;
  final int detourMinutes;
  final double distanceFromRouteKm;
  final double alongKm;
  final bool fitsWindow;

  /// Normalised type from the server; null for answers that predate it.
  final MyPlaceCategory? kind;

  /// False for the extra nearby places the model did not choose.
  final bool picked;
  final String? website;

  /// What the place itself lists: address, phone, website, opening hours,
  /// Wikipedia link. Only keys it actually has.
  final Map<String, String> attributes;

  int get totalMinutes => visitMinutes + detourMinutes;

  /// Type of the place: the server's normalised kind, or a guess from the
  /// raw category for answers that predate it.
  MyPlaceCategory get placeCategory => kind ?? _guessCategory();

  MyPlaceCategory _guessCategory() {
    final c = category.toLowerCase();
    if (c.contains('beach')) return MyPlaceCategory.beach;
    if (c.contains('commercial')) return MyPlaceCategory.shopping;
    if (c.contains('castle') ||
        c.contains('ruines') ||
        c.contains('heritage') ||
        c.contains('archaeological') ||
        c.contains('place_of_worship')) {
      return MyPlaceCategory.history;
    }
    if (c.contains('catering')) return MyPlaceCategory.food;
    if (c.contains('zoo') ||
        c.contains('aquarium') ||
        c.contains('theme_park') ||
        c.contains('playground')) {
      return MyPlaceCategory.kids;
    }
    if (c.contains('museum') ||
        c.contains('culture') ||
        c.contains('building')) {
      return MyPlaceCategory.culture;
    }
    if (c.contains('viewpoint') || c.contains('sights')) {
      return MyPlaceCategory.viewpoint;
    }
    if (c.contains('natural') || c.contains('park') || c.contains('forest')) {
      return MyPlaceCategory.nature;
    }
    return MyPlaceCategory.other;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': coordinate.lat,
        'lon': coordinate.lon,
        'category': category,
        if (kind != null) 'kind': kind!.name,
        'why': why,
        'visit_minutes': visitMinutes,
        'detour_minutes': detourMinutes,
        'distance_from_route_km': distanceFromRouteKm,
        'along_km': alongKm,
        'fits_window': fitsWindow,
        'picked': picked,
        if (website != null) 'website': website,
        'attributes': attributes,
      };

  /// Throws [FormatException] when the entry cannot describe a place.
  factory StopSuggestion.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final lat = json['lat'];
    final lon = json['lon'];
    if (id is! String || name is! String || name.isEmpty) {
      throw const FormatException('StopSuggestion: missing id or name');
    }
    if (lat is! num || lon is! num) {
      throw const FormatException('StopSuggestion: missing position');
    }
    final website = json['website'];
    final kindName = json['kind'];
    return StopSuggestion(
      id: id,
      name: name,
      coordinate: LatLon(lat: lat.toDouble(), lon: lon.toDouble()),
      category: json['category'] is String ? json['category'] as String : '',
      why: json['why'] is String ? json['why'] as String : '',
      visitMinutes: (json['visit_minutes'] as num?)?.round() ?? 30,
      detourMinutes: (json['detour_minutes'] as num?)?.round() ?? 0,
      distanceFromRouteKm:
          (json['distance_from_route_km'] as num?)?.toDouble() ?? 0,
      alongKm: (json['along_km'] as num?)?.toDouble() ?? 0,
      fitsWindow: json['fits_window'] as bool? ?? true,
      kind: kindName is String ? _kindByName(kindName) : null,
      picked: json['picked'] as bool? ?? true,
      website: website is String && website.isNotEmpty ? website : null,
      attributes: {
        if (json['attributes'] is Map<String, dynamic>)
          for (final e in (json['attributes'] as Map<String, dynamic>).entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              e.key: e.value as String,
        // The top-level website is the same fact; keep one place to read it.
        if (website is String && website.isNotEmpty) 'website': website,
      },
    );
  }
}

MyPlaceCategory? _kindByName(String name) {
  for (final c in MyPlaceCategory.values) {
    if (c.name == name) return c;
  }
  return null;
}

class StopSuggestionsResult {
  const StopSuggestionsResult({
    required this.suggestions,
    required this.ai,
    required this.windowMinutes,
    required this.usedMinutes,
    this.reason,
  });

  final List<StopSuggestion> suggestions;

  /// False when the places are real but the model gave no explanation.
  final bool ai;

  /// `no_places`, `places_unavailable`, `llm_unavailable` or null.
  final String? reason;
  final int windowMinutes;
  final int usedMinutes;

  Map<String, dynamic> toJson() => {
        'suggestions': [for (final s in suggestions) s.toJson()],
        'ai': ai,
        if (reason != null) 'reason': reason,
        'window_minutes': windowMinutes,
        'used_minutes': usedMinutes,
      };

  factory StopSuggestionsResult.fromJson(Map<String, dynamic> json) {
    final rows = <StopSuggestion>[];
    for (final item in (json['suggestions'] as List<dynamic>? ?? const [])) {
      if (item is! Map<String, dynamic>) continue;
      try {
        rows.add(StopSuggestion.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    return StopSuggestionsResult(
      suggestions: rows,
      ai: json['ai'] as bool? ?? false,
      reason: json['reason'] as String?,
      windowMinutes: (json['window_minutes'] as num?)?.round() ?? 0,
      usedMinutes: (json['used_minutes'] as num?)?.round() ?? 0,
    );
  }
}

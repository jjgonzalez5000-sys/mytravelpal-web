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
    this.website,
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
  final String? website;

  int get totalMinutes => visitMinutes + detourMinutes;

  /// Closest of our own categories, so a suggestion saved as a place gets
  /// a sensible icon.
  MyPlaceCategory get placeCategory {
    final c = category.toLowerCase();
    if (c.contains('catering')) return MyPlaceCategory.food;
    if (c.contains('zoo') ||
        c.contains('aquarium') ||
        c.contains('theme_park') ||
        c.contains('playground')) {
      return MyPlaceCategory.kids;
    }
    if (c.contains('museum') ||
        c.contains('culture') ||
        c.contains('heritage') ||
        c.contains('building')) {
      return MyPlaceCategory.culture;
    }
    if (c.contains('viewpoint') || c.contains('sights')) {
      return MyPlaceCategory.viewpoint;
    }
    if (c.contains('natural') ||
        c.contains('park') ||
        c.contains('beach') ||
        c.contains('forest')) {
      return MyPlaceCategory.nature;
    }
    return MyPlaceCategory.other;
  }

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
      website: website is String && website.isNotEmpty ? website : null,
    );
  }
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

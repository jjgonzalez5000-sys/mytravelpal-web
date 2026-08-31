import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';

/// Persists Trip Inspiration LLM proposals to local prefs so the
/// driver can revisit ideas they liked without re-generating them
/// (each regen costs an Anthropic API call and, more importantly,
/// gives a different itinerary because the model isn't
/// deterministic). Capped at 20 entries FIFO — the LRU by
/// `savedAt` — so a chatty user doesn't blow up SharedPreferences.
///
/// Storage shape: JSON array under a single key. Cheap for our
/// scale (≤ 20 × ~4 KB). If it ever grows we migrate to a real
/// key-value store; SharedPreferences is fine for the beta.
@immutable
class SavedInspiration {
  const SavedInspiration({
    required this.id,
    required this.prompt,
    required this.itinerary,
    required this.savedAt,
    this.locale,
  });

  final String id;
  final String prompt;
  final InspireItinerary itinerary;
  final DateTime savedAt;
  final String? locale;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'saved_at': savedAt.toIso8601String(),
        if (locale != null) 'locale': locale,
        'itinerary': _serialiseItinerary(itinerary),
      };

  factory SavedInspiration.fromJson(Map<String, dynamic> j) =>
      SavedInspiration(
        id: j['id'] as String,
        prompt: j['prompt'] as String,
        savedAt: DateTime.parse(j['saved_at'] as String),
        locale: j['locale'] as String?,
        itinerary: InspireItinerary.fromJson(
          j['itinerary'] as Map<String, dynamic>,
        ),
      );
}

class InspirationStorage {
  InspirationStorage(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'saved_inspirations.v1';
  static const _cap = 20;

  static Future<InspirationStorage> open() async =>
      InspirationStorage(await SharedPreferences.getInstance());

  List<SavedInspiration> list() {
    final raw = _prefs.getStringList(_key) ?? const <String>[];
    return raw
        .map((s) {
          try {
            return SavedInspiration.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedInspiration>()
        .toList(growable: false);
  }

  Future<void> save(SavedInspiration entry) async {
    final current = list();
    // Dedup by prompt so re-saving the same idea after a tweak
    // replaces the older copy rather than piling entries.
    final filtered = current.where((e) => e.prompt != entry.prompt).toList();
    final next = <SavedInspiration>[entry, ...filtered].take(_cap).toList();
    await _prefs.setStringList(
      _key,
      next.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> remove(String id) async {
    final current = list();
    final next = current.where((e) => e.id != id).toList();
    await _prefs.setStringList(
      _key,
      next.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

// -- helpers ------------------------------------------------------

Map<String, dynamic> _serialiseItinerary(InspireItinerary it) => {
      'summary': it.summary,
      'days': it.days.map(_serialiseDay).toList(),
      if (it.totalDistanceKmEstimate != null)
        'total_distance_km_estimate': it.totalDistanceKmEstimate,
      if (it.estimatedBudgetEur != null)
        'estimated_budget_eur': it.estimatedBudgetEur,
      if (it.suggestedDepartureDaysFromNow != null)
        'suggested_departure_days_from_now':
            it.suggestedDepartureDaysFromNow,
      if (it.suggestedDepartureHour != null)
        'suggested_departure_hour': it.suggestedDepartureHour,
    };

Map<String, dynamic> _serialiseDay(InspireDay d) => {
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
    };

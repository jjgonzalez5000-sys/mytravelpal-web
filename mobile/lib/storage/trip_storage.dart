import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_trip.dart';

/// Local storage for the user's saved trips. Newest first.
///
/// Backed by SharedPreferences under a single JSON-list key — good enough
/// for the ~50-trip volume expected in the MVP, and testable without a
/// real filesystem via `SharedPreferences.setMockInitialValues`.
class TripStorage {
  TripStorage(this._prefs);

  static const _key = 'saved_trips.v1';
  static const _maxEntries = 100;

  final SharedPreferences _prefs;

  static Future<TripStorage> open() async =>
      TripStorage(await SharedPreferences.getInstance());

  Future<List<SavedTrip>> list() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => SavedTrip.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> save(SavedTrip trip) async {
    final current = await list();
    final next = <SavedTrip>[
      trip,
      ...current.where((t) => t.id != trip.id),
    ];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _write(next);
  }

  Future<void> delete(String id) async {
    final current = await list();
    await _write(current.where((t) => t.id != id).toList(growable: false));
  }

  Future<void> clear() => _prefs.remove(_key);

  Future<void> _write(List<SavedTrip> trips) async {
    await _prefs.setString(
      _key,
      jsonEncode(trips.map((t) => t.toJson()).toList(growable: false)),
    );
  }
}

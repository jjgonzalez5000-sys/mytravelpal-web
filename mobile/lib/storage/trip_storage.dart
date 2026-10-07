import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../services/widget_bridge.dart';
import 'saved_trip.dart';

/// Local storage for the user's saved trips. Newest first.
///
/// Backed by SharedPreferences under a single JSON-list key — good enough
/// for the ~50-trip volume expected in the MVP, and testable without a
/// real filesystem via `SharedPreferences.setMockInitialValues`.
///
/// When [api] is set (post-login), every save/delete/write also pushes
/// the full list to the server via `PUT /v1/profile/trips`. The
/// setter is invoked by [TripProfileNotifier] after the auth flow
/// hands it the same [ApiClient] the profile sync uses.
class TripStorage {
  TripStorage(this._prefs);

  static const _key = 'saved_trips.v1';
  static const _maxEntries = 100;

  final SharedPreferences _prefs;

  /// Auth-wired API client. Null before login; set after.
  ApiClient? api;

  static Future<TripStorage> open() async =>
      TripStorage(await SharedPreferences.getInstance());

  Future<List<SavedTrip>> list() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    // Parse individually so a single malformed entry (e.g. an unknown
    // country code from a future schema change) does not wipe the whole list.
    final result = <SavedTrip>[];
    for (final e in decoded) {
      try {
        result.add(SavedTrip.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        // Skip this entry; log in debug mode to aid diagnosis.
        assert(() {
          // ignore: avoid_print
          print('[TripStorage] Skipping unparseable trip entry: $e');
          return true;
        }());
      }
    }
    return result;
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

  /// Pull trips from the server after login and merge into local
  /// storage. Merge is "server wins for same id" — local additions
  /// made offline keep their spot but a re-shared server copy
  /// takes precedence on content.
  Future<void> syncFromServer() async {
    if (api == null) return;
    final remote = await api!.fetchTrips();
    if (remote.isEmpty) {
      // Server has nothing — but we may have local trips from
      // pre-login use; push them up so a re-login on another
      // device picks them up.
      final local = await list();
      if (local.isNotEmpty) await _pushToServer(local);
      return;
    }
    final local = await list();
    final byId = <String, SavedTrip>{
      for (final t in local) t.id: t,
    };
    for (final r in remote) {
      try {
        final trip = SavedTrip.fromJson(r);
        byId[trip.id] = trip;
      } catch (_) {}
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (merged.length > _maxEntries) {
      merged.removeRange(_maxEntries, merged.length);
    }
    // Push back to server if local had trips the server didn't know about
    // (e.g. saves that failed to reach the server earlier). Skipping the
    // push only makes sense when server and local are already in sync.
    final needServerUpdate = merged.length > remote.length;
    await _write(merged, skipServerPush: !needServerUpdate);
  }

  Future<void> _write(
    List<SavedTrip> trips, {
    bool skipServerPush = false,
  }) async {
    await _prefs.setString(
      _key,
      jsonEncode(trips.map((t) => t.toJson()).toList(growable: false)),
    );
    // Refresh the home-screen widget with the new "next upcoming".
    // Fire-and-forget so a widget-less device (widget not pinned)
    // doesn't slow the save call — the bridge's SharedPreferences
    // write is cheap and idempotent.
    // ignore: unawaited_futures
    WidgetBridge.instance.refresh(trips);
    // Server push: fire-and-forget so an offline user still sees
    // the save land locally. `skipServerPush` is set only when
    // `syncFromServer` just merged from the server itself (would
    // be pointless to bounce the same data back).
    if (!skipServerPush) {
      // ignore: unawaited_futures
      _pushToServer(trips);
    }
  }

  Future<void> _pushToServer(List<SavedTrip> trips) async {
    if (api == null) return;
    await api!.saveTrips(
      trips.map((t) => t.toJson()).toList(growable: false),
    );
  }
}

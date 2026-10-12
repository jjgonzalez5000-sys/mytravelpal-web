import 'dart:collection';
import 'dart:convert';

import '../api/models.dart';

/// Canonical form of a plan request: two requests the server would answer
/// the same way give the same string. Waypoint order, sub-minute departure
/// and day-override order do not matter.
String requestSignature(TripPlanRequest r) {
  String at4(double v) => v.toStringAsFixed(4);
  final waypoints = [...r.waypoints]..sort((a, b) {
      final byLat = at4(a.coordinate.lat).compareTo(at4(b.coordinate.lat));
      if (byLat != 0) return byLat;
      final byLon = at4(a.coordinate.lon).compareTo(at4(b.coordinate.lon));
      if (byLon != 0) return byLon;
      return (a.viaOnly ? 1 : 0).compareTo(b.viaOnly ? 1 : 0);
    });
  final overrides = [...r.dayOverrides]
    ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
  final d = r.desiredDepartureAt;
  final minute = d.isUtc
      ? DateTime.utc(d.year, d.month, d.day, d.hour, d.minute)
      : DateTime(d.year, d.month, d.day, d.hour, d.minute);
  return jsonEncode(
    r
        .copyWith(
          waypoints: waypoints,
          dayOverrides: overrides,
          desiredDepartureAt: minute,
        )
        .toJson(),
  );
}

/// What the LRU remembers for one request signature.
class PlanLruEntry {
  PlanLruEntry(this.core, this.coreAt);

  final TripPlanResponse core;
  final DateTime coreAt;
  TripPlanResponse? enrich;
  DateTime? enrichAt;
}

/// Small in-memory cache of plan responses by [requestSignature], so
/// undoing a change shows the earlier plan without a network call. Entries
/// expire like the server's own plan cache (core 10 min, enrich 5 min).
class PlanLru {
  PlanLru({
    this.capacity = 8,
    this.coreTtl = const Duration(minutes: 10),
    this.enrichTtl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int capacity;
  final Duration coreTtl;
  final Duration enrichTtl;
  final DateTime Function() _now;
  final LinkedHashMap<String, PlanLruEntry> _entries = LinkedHashMap();

  int get length => _entries.length;

  /// The entry for [sig] (marked most recently used), or null when absent or
  /// expired. Its [PlanLruEntry.enrich] is null once the enrich part expired.
  PlanLruEntry? get(String sig) {
    final e = _entries.remove(sig);
    if (e == null) return null;
    final now = _now();
    if (now.difference(e.coreAt) > coreTtl) return null;
    final enrichAt = e.enrichAt;
    if (enrichAt != null && now.difference(enrichAt) > enrichTtl) {
      e.enrich = null;
      e.enrichAt = null;
    }
    _entries[sig] = e;
    return e;
  }

  void putCore(String sig, TripPlanResponse core) {
    _entries.remove(sig);
    _entries[sig] = PlanLruEntry(core, _now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void putEnrich(String sig, TripPlanResponse enrich) {
    final e = _entries.remove(sig);
    if (e == null) return;
    e.enrich = enrich;
    e.enrichAt = _now();
    _entries[sig] = e;
  }

  void clear() => _entries.clear();
}

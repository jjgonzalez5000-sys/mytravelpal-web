import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';

/// Lightweight snapshot of an in-flight trip written to
/// SharedPreferences so the user can resume where they left off
/// after Android reclaims the app mid-drive.
///
/// Scope of persistence — minimal on purpose:
/// - The full API response JSON (for TripPlanResponse rehydration).
/// - Origin + destination + desiredDepartureAt (for the request shell).
/// - A handful of request scalars that ResultScreen branches on
///   (hotel / restaurant detour minutes, includeAdverseEvents,
///   avoidMotorways, preferScenic). Anything else falls back to
///   defaults on restore — good enough to render the same result
///   screen the driver was looking at.
///
/// Deliberately NOT persisted: GPS trail, added-stops set, scroll
/// position. Those recompute or reset on resume.
class TripSessionPersistence {
  TripSessionPersistence._();
  static final instance = TripSessionPersistence._();

  // Bumped to v3 (2026-08-25) after the multi-day optimizations
  // refactor: cached v2 sessions carried single-day meal_stops
  // and a stale day_plan structure, so "Retomar tu viaje" showed
  // the OLD plan verbatim while the fresh backend was returning
  // multi-day data. Version bump invalidates every prior cache
  // in one go — users get a real request next time.
  static const _kKey = 'tripSession.v3';
  // Snapshots older than this are treated as stale — the user
  // probably ended the trip and we forgot to clear.
  static const _staleAfter = Duration(hours: 8);

  Future<void> save({
    required TripPlanRequest request,
    required TripPlanResponse response,
    required GeocodeResult origin,
    required GeocodeResult destination,
    required DateTime desiredDepartureAt,
  }) async {
    if (response.rawJson == null) return; // synthetic response — skip.
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'savedAtIso': DateTime.now().toIso8601String(),
      'desiredDepartureIso': desiredDepartureAt.toIso8601String(),
      'origin': _geocodeToJson(origin),
      'destination': _geocodeToJson(destination),
      'requestScalars': {
        'hotelMaxDetourMinutes': request.hotelMaxDetourMinutes,
        'restaurantMaxDetourMinutes': request.restaurantMaxDetourMinutes,
        'includeAdverseEvents': request.includeAdverseEvents,
        'avoidMotorways': request.avoidMotorways,
        'preferScenic': request.preferScenic,
      },
      'response': response.rawJson,
    });
    await prefs.setString(_kKey, payload);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  /// Read back the last persisted session, or null when empty /
  /// stale / corrupted. Corrupt payloads are auto-cleared so a bad
  /// entry doesn't keep tripping the resume prompt.
  Future<PersistedTripSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.parse(map['savedAtIso'] as String);
      if (DateTime.now().difference(savedAt) > _staleAfter) {
        await clear();
        return null;
      }
      final origin = _geocodeFromJson(
        (map['origin'] as Map).cast<String, dynamic>(),
      );
      final destination = _geocodeFromJson(
        (map['destination'] as Map).cast<String, dynamic>(),
      );
      final departure = DateTime.parse(map['desiredDepartureIso'] as String);
      final scalars =
          (map['requestScalars'] as Map).cast<String, dynamic>();
      final response = TripPlanResponse.fromJson(
        (map['response'] as Map).cast<String, dynamic>(),
      );
      return PersistedTripSession(
        savedAt: savedAt,
        desiredDepartureAt: departure,
        origin: origin,
        destination: destination,
        request: TripPlanRequest(
          origin: origin.coordinate,
          destination: destination.coordinate,
          desiredDepartureAt: departure,
          hotelMaxDetourMinutes: scalars['hotelMaxDetourMinutes'] as int?,
          restaurantMaxDetourMinutes:
              scalars['restaurantMaxDetourMinutes'] as int?,
          includeAdverseEvents:
              (scalars['includeAdverseEvents'] as bool?) ?? false,
          avoidMotorways: (scalars['avoidMotorways'] as bool?) ?? false,
          preferScenic: (scalars['preferScenic'] as bool?) ?? false,
        ),
        response: response,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Map<String, dynamic> _geocodeToJson(GeocodeResult g) => {
        'displayName': g.displayName,
        'coordinate': g.coordinate.toJson(),
        'country': g.country.code,
      };

  GeocodeResult _geocodeFromJson(Map<String, dynamic> m) => GeocodeResult(
        displayName: m['displayName'] as String,
        coordinate: LatLon.fromJson(
          (m['coordinate'] as Map).cast<String, dynamic>(),
        ),
        country: Country.fromCode(m['country'] as String),
      );
}

class PersistedTripSession {
  const PersistedTripSession({
    required this.savedAt,
    required this.desiredDepartureAt,
    required this.origin,
    required this.destination,
    required this.request,
    required this.response,
  });

  final DateTime savedAt;
  final DateTime desiredDepartureAt;
  final GeocodeResult origin;
  final GeocodeResult destination;
  final TripPlanRequest request;
  final TripPlanResponse response;
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import 'trip_progress.dart';

/// Writes the current trip state into SharedPreferences so the
/// native Android Auto `TripCompanionScreen` (Kotlin, separate
/// process context when AA is projecting) can read it and render
/// the head unit templates.
///
/// This is a one-way write channel. AA templates re-invalidate on
/// their own timer; the Kotlin side reads on every `onGetTemplate`
/// tick without any push from us.
///
/// KEEP THE KEY NAMES IN SYNC with `TripCompanionScreen.kt` —
/// there is no shared compile-time contract between Dart and Kotlin
/// for these strings.
class CarBridge {
  CarBridge._();
  static final instance = CarBridge._();

  // The Kotlin side hardcodes the exact file name Flutter's
  // `shared_preferences` plugin writes to (`FlutterSharedPreferences`)
  // — see `TripCompanionScreen.kt#BRIDGE_PREFS`. Both processes hit
  // the same bytes because Android SharedPreferences is per-package.

  // From Dart we use unprefixed keys — the plugin adds the "flutter."
  // prefix automatically when writing to the native SharedPreferences
  // file. The Kotlin reader in `TripCompanionScreen.kt` reads the
  // prefixed form (`flutter.activeTrip`) directly.
  static const _kActiveTrip = 'activeTrip';
  static const _kNextStopName = 'nextStopName';
  static const _kNextStopEtaMs = 'nextStopEtaMs';
  static const _kNextStopLat = 'nextStopLat';
  static const _kNextStopLon = 'nextStopLon';
  static const _kCheaperFuelBrand = 'cheaperFuelBrand';
  static const _kCheaperFuelKm = 'cheaperFuelKm';
  static const _kCheaperFuelCents = 'cheaperFuelCents';
  static const _kCheaperFuelLat = 'cheaperFuelLat';
  static const _kCheaperFuelLon = 'cheaperFuelLon';
  static const _kDestEtaMs = 'destinationEtaMs';
  static const _kRemainingKm = 'remainingKm';
  static const _kProgressKm = 'progressKm';
  static const _kTotalKm = 'totalKm';
  static const _kSpeedKmh = 'speedKmh';
  static const _kMeLat = 'meLat';
  static const _kMeLon = 'meLon';
  static const _kDestLat = 'destLat';
  static const _kDestLon = 'destLon';
  // JSON-encoded arrays for the AA sub-list screens. We keep them
  // capped to top-10 so the head-unit ItemList doesn't hit AA's
  // ~6 row rendering limit for driving safety.
  static const _kFuelListJson = 'fuelListJson';
  static const _kRestaurantsListJson = 'restaurantsListJson';
  static const _kAlertsQueueJson = 'alertsQueueJson';

  /// Broadcast the "live overview" state to the Android Auto bridge.
  ///
  /// Everything the head unit renders comes from these keys —
  /// `updateTrip` is a full snapshot, not a diff, so a missing field
  /// clears the corresponding row on the car screen instead of
  /// showing stale data.
  Future<void> updateTrip({
    required TripProgress progress,
    LatLon? me,
    LatLon? destination,
    MealStopOpt? nextStop,
    List<FuelPrice> fuelStations = const [],
    List<Restaurant> restaurants = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActiveTrip, true);
    await prefs.setInt(
      _kDestEtaMs, progress.etaToDestination.millisecondsSinceEpoch,
    );
    await prefs.setInt(_kRemainingKm, progress.remainingKm.round());
    await prefs.setInt(_kProgressKm, progress.progressKm.round());
    await prefs.setInt(_kTotalKm, progress.totalKm.round());
    await prefs.setInt(_kSpeedKmh, progress.currentSpeedKmh.round());

    // "Me" and destination anchor points for the AA PlaceListMap.
    if (me != null) {
      await prefs.setDouble(_kMeLat, me.lat);
      await prefs.setDouble(_kMeLon, me.lon);
    }
    if (destination != null) {
      await prefs.setDouble(_kDestLat, destination.lat);
      await prefs.setDouble(_kDestLon, destination.lon);
    }

    if (nextStop != null &&
        nextStop.restaurantName != null &&
        progress.etaToNextStop != null) {
      await prefs.setString(_kNextStopName, nextStop.restaurantName!);
      await prefs.setInt(
        _kNextStopEtaMs, progress.etaToNextStop!.millisecondsSinceEpoch,
      );
      if (nextStop.restaurantCoordinate != null) {
        await prefs.setDouble(
          _kNextStopLat, nextStop.restaurantCoordinate!.lat,
        );
        await prefs.setDouble(
          _kNextStopLon, nextStop.restaurantCoordinate!.lon,
        );
      }
    } else {
      await prefs.remove(_kNextStopName);
      await prefs.remove(_kNextStopEtaMs);
      await prefs.remove(_kNextStopLat);
      await prefs.remove(_kNextStopLon);
    }

    final hint = progress.cheaperFuelAhead;
    if (hint != null) {
      await prefs.setString(
        _kCheaperFuelBrand, hint.station.stationName,
      );
      await prefs.setInt(_kCheaperFuelKm, hint.aheadKm.round());
      await prefs.setInt(
        _kCheaperFuelCents, (hint.savingsEurPerL * 100).round(),
      );
      if (hint.station.coordinate != null) {
        await prefs.setDouble(_kCheaperFuelLat, hint.station.coordinate!.lat);
        await prefs.setDouble(_kCheaperFuelLon, hint.station.coordinate!.lon);
      }
    } else {
      await prefs.remove(_kCheaperFuelBrand);
      await prefs.remove(_kCheaperFuelKm);
      await prefs.remove(_kCheaperFuelCents);
      await prefs.remove(_kCheaperFuelLat);
      await prefs.remove(_kCheaperFuelLon);
    }

    // Top-10 fuel / restaurant lists for the AA sub-screens. We
    // JSON-encode to a single string field — SharedPreferences on
    // Android doesn't have a native list type that survives the
    // Flutter plugin ↔ Kotlin boundary cleanly, so a JSON payload is
    // the simplest contract.
    await prefs.setString(
      _kFuelListJson,
      jsonEncode(
        fuelStations.take(10).map(_fuelToBridge).toList(),
      ),
    );
    await prefs.setString(
      _kRestaurantsListJson,
      jsonEncode(
        restaurants.take(10).map(_restaurantToBridge).toList(),
      ),
    );
  }

  Map<String, Object?> _fuelToBridge(FuelPrice f) => {
        'name': f.stationName,
        'priceEurPerL': f.priceAvailable ? f.priceEurPerL : null,
        'kmFromOrigin': f.distanceFromOriginKm.round(),
        'lat': f.coordinate?.lat,
        'lon': f.coordinate?.lon,
        'country': f.country.code,
      };

  Map<String, Object?> _restaurantToBridge(Restaurant r) => {
        'name': r.name,
        'priceEurPerMeal': r.priceEurPerMeal,
        'priceBand': r.priceBand.symbol,
        'detourMinutes': r.detourMinutes.round(),
        'lat': r.coordinate.lat,
        'lon': r.coordinate.lon,
      };

  /// Refresh the Android Auto alerts tray with the current list of
  /// active adverse events. Called by Companion's periodic refresh
  /// so the head unit's "Alerts" screen reflects fires / storms
  /// that landed on the corridor mid-drive.
  ///
  /// Full-snapshot semantics (same as `updateTrip`): the passed list
  /// replaces whatever was there. Cap at 10 rows to fit AA's list
  /// rendering limit.
  Future<void> updateAlertsQueue(List<AdverseEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAlertsQueueJson,
      jsonEncode(
        events.take(10).map(_alertToBridge).toList(),
      ),
    );
  }

  Map<String, Object?> _alertToBridge(AdverseEvent e) => {
        'id': e.id,
        'type': e.type.name,
        'severity': e.severity.name,
        'description': e.description,
        'lat': e.coordinate.lat,
        'lon': e.coordinate.lon,
        'reportedAtMs': e.reportedAt.millisecondsSinceEpoch,
        'expiresAtMs': e.expiresAt.millisecondsSinceEpoch,
      };

  /// Called when the driver leaves the dashboard so AA falls back
  /// to the idle "plan a trip" screen instead of showing stale data.
  Future<void> clearTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActiveTrip, false);
    for (final k in [
      _kNextStopName, _kNextStopEtaMs, _kNextStopLat, _kNextStopLon,
      _kCheaperFuelBrand, _kCheaperFuelKm, _kCheaperFuelCents,
      _kCheaperFuelLat, _kCheaperFuelLon,
      _kDestEtaMs, _kRemainingKm, _kProgressKm, _kTotalKm, _kSpeedKmh,
      _kMeLat, _kMeLon, _kDestLat, _kDestLon,
      _kFuelListJson, _kRestaurantsListJson, _kAlertsQueueJson,
    ]) {
      await prefs.remove(k);
    }
  }
}

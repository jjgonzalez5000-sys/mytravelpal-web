import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// Result of the "Use my location" flow.
///
/// * `place` is null when reverse-geocoding didn't find a supported
///   place at the position — the caller should still show *something*
///   (raw lat/lon or a friendly placeholder) instead of blocking.
/// * `denied` distinguishes permission problems (user has to fix them
///   in settings) from transient positioning errors.
class CurrentLocationResult {
  const CurrentLocationResult({
    this.place,
    this.rawLat,
    this.rawLon,
    this.denied = false,
    this.disabled = false,
    this.timedOut = false,
  });

  final GeocodeResult? place;
  final double? rawLat;
  final double? rawLon;
  final bool denied;
  final bool disabled;
  final bool timedOut;

  bool get success => place != null;
}

/// Thin service around `geolocator` + [ApiClient.reverseGeocode].
///
/// Deliberately not a Riverpod provider — the current-location button
/// fires once and doesn't need reactive state. Kept as a plain class
/// so tests can inject a fake `positionResolver`.
class CurrentLocationService {
  CurrentLocationService(this._api, {PositionResolver? positionResolver})
      : _positionResolver = positionResolver ?? _defaultPositionResolver;

  final ApiClient _api;
  final PositionResolver _positionResolver;

  Future<CurrentLocationResult> resolve({
    Duration timeout = const Duration(seconds: 8),
    String? locale,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const CurrentLocationResult(disabled: true);
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const CurrentLocationResult(denied: true);
      }
      final position = await _positionResolver().timeout(timeout);
      final place = await _api.reverseGeocode(
        lat: position.latitude,
        lon: position.longitude,
        locale: locale,
      );
      return CurrentLocationResult(
        place: place,
        rawLat: position.latitude,
        rawLon: position.longitude,
      );
    } on TimeoutException {
      return const CurrentLocationResult(timedOut: true);
    }
  }
}

typedef PositionResolver = Future<Position> Function();

Future<Position> _defaultPositionResolver() =>
    Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );

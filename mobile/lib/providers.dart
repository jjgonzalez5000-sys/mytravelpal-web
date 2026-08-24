import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'domain/trip_profile.dart';
import 'storage/app_prefs.dart';
import 'storage/trip_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Provides the [TripStorage] singleton. Must be overridden at app boot
/// (see `main.dart`) with the actual instance so the async open completes
/// before the tree is built.
final tripStorageProvider = Provider<TripStorage>(
  (ref) => throw UnimplementedError(
    'tripStorageProvider must be overridden at ProviderScope',
  ),
);

/// Provides the [AppPrefs] singleton. Must be overridden at app boot.
final appPrefsProvider = Provider<AppPrefs>(
  (ref) => throw UnimplementedError(
    'appPrefsProvider must be overridden at ProviderScope',
  ),
);

/// Current [ThemeMode]. Reads initial value from prefs, persists on change.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_prefs.themeMode);
  final AppPrefs _prefs;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appPrefsProvider));
});

/// Current [TripProfile], or null if the user hasn't set one yet.
class TripProfileNotifier extends StateNotifier<TripProfile?> {
  TripProfileNotifier(this._prefs) : super(_prefs.tripProfile);
  final AppPrefs _prefs;

  Future<void> set(TripProfile? profile) async {
    state = profile;
    await _prefs.setTripProfile(profile);
  }

  Future<void> clear() => set(null);
}

final tripProfileProvider =
    StateNotifierProvider<TripProfileNotifier, TripProfile?>((ref) {
  return TripProfileNotifier(ref.watch(appPrefsProvider));
});

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/trip_profile.dart';

/// One-liner preferences that don't fit the trip-storage abstraction.
///
/// The onboarding flag lives here so `SplashScreen` can synchronously
/// route new users to the intro and returning users straight to planning.
class AppPrefs {
  AppPrefs(this._prefs);

  static const _onboardingKey = 'onboarding_shown.v1';
  static const _themeModeKey = 'theme_mode.v1';
  static const _tripProfileKey = 'trip_profile.v1';

  final SharedPreferences _prefs;

  static Future<AppPrefs> open() async =>
      AppPrefs(await SharedPreferences.getInstance());

  bool get onboardingShown => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> markOnboardingShown() =>
      _prefs.setBool(_onboardingKey, true);

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case _:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(
        _themeModeKey,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );

  TripProfile? get tripProfile {
    final raw = _prefs.getString(_tripProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return TripProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setTripProfile(TripProfile? profile) async {
    if (profile == null) {
      await _prefs.remove(_tripProfileKey);
    } else {
      await _prefs.setString(_tripProfileKey, jsonEncode(profile.toJson()));
    }
  }

  Future<void> reset() async {
    await _prefs.remove(_onboardingKey);
    await _prefs.remove(_themeModeKey);
    await _prefs.remove(_tripProfileKey);
  }
}

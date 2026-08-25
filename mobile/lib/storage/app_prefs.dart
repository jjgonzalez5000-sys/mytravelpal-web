import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../domain/auth_user.dart';
import '../domain/favorite_place.dart';
import '../domain/trip_profile.dart';
import '../domain/units.dart';

/// One-liner preferences that don't fit the trip-storage abstraction.
///
/// The onboarding flag lives here so `SplashScreen` can synchronously
/// route new users to the intro and returning users straight to planning.
class AppPrefs {
  AppPrefs(this._prefs);

  static const _onboardingKey = 'onboarding_shown.v1';
  static const _themeModeKey = 'theme_mode.v1';
  static const _localeKey = 'locale.v1';
  static const _unitSystemKey = 'unit_system.v1';
  static const _tripProfileKey = 'trip_profile.v1';
  static const _premiumKey = 'premium.v1';
  static const _authTokenKey = 'auth_token.v1';
  static const _authUserKey = 'auth_user.v1';
  static const _recentSearchesKey = 'recent_searches.v1';
  static const _favoriteHotelsKey = 'favorite_hotels.v1';
  static const _favoriteRestaurantsKey = 'favorite_restaurants.v1';
  static const _favoritePlacesKey = 'favorite_places.v1';
  static const _recentSearchesLimit = 8;

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

  /// User-picked locale override, or null meaning "follow system".
  /// Stored as a plain BCP-47 language tag (`en`, `es`, `fr`, `it`, `de`).
  Locale? get localeOverride {
    final code = _prefs.getString(_localeKey);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  Future<void> setLocaleOverride(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, locale.languageCode);
    }
  }

  UnitSystem get unitSystem =>
      UnitSystem.fromCode(_prefs.getString(_unitSystemKey));
  Future<void> setUnitSystem(UnitSystem system) =>
      _prefs.setString(_unitSystemKey, system.code);

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

  bool get isPremium => _prefs.getBool(_premiumKey) ?? false;
  Future<void> setPremium(bool value) => _prefs.setBool(_premiumKey, value);

  String? get authToken => _prefs.getString(_authTokenKey);
  AuthUser? get authUser {
    final raw = _prefs.getString(_authUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setAuthSession(String? token, AuthUser? user) async {
    if (token == null || user == null) {
      await _prefs.remove(_authTokenKey);
      await _prefs.remove(_authUserKey);
    } else {
      await _prefs.setString(_authTokenKey, token);
      await _prefs.setString(_authUserKey, jsonEncode(user.toJson()));
    }
  }

  // -- Recent searches --------------------------------------------------

  List<GeocodeResult> get recentSearches {
    final raw = _prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    return raw
        .map((s) {
          try {
            return GeocodeResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<GeocodeResult>()
        .toList(growable: false);
  }

  /// Push `result` to the front of the recent list. De-dupes on
  /// `displayName` so re-picking the same city bumps it instead of
  /// filling the list. Caps at [_recentSearchesLimit].
  Future<void> pushRecentSearch(GeocodeResult result) async {
    final current = recentSearches;
    final without = current.where((r) => r.displayName != result.displayName);
    final next = [result, ...without].take(_recentSearchesLimit).toList();
    await _prefs.setStringList(
      _recentSearchesKey,
      next.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> clearRecentSearches() =>
      _prefs.remove(_recentSearchesKey);

  // -- Favorites --------------------------------------------------------

  /// A minimal favorite POI record — enough to render the tile in the
  /// Favorites screen without re-planning a trip to fetch it back.
  /// Kept independent from [Hotel] / [Restaurant] so schema drift in
  /// those models doesn't require re-reading old prefs.
  ///
  /// `kind` is either `hotel` or `restaurant`.
  List<Map<String, dynamic>> _decodeFavorites(String key) {
    final raw = _prefs.getStringList(key) ?? const <String>[];
    return raw
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get favoriteHotels =>
      _decodeFavorites(_favoriteHotelsKey);
  List<Map<String, dynamic>> get favoriteRestaurants =>
      _decodeFavorites(_favoriteRestaurantsKey);

  bool isFavoriteHotel(String id) =>
      favoriteHotels.any((m) => m['id'] == id);
  bool isFavoriteRestaurant(String id) =>
      favoriteRestaurants.any((m) => m['id'] == id);

  Future<void> _writeFavorites(
    String key, List<Map<String, dynamic>> favs,
  ) async {
    await _prefs.setStringList(
      key, favs.map((m) => jsonEncode(m)).toList(),
    );
  }

  Future<void> toggleFavoriteHotel(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    final current = favoriteHotels;
    if (current.any((m) => m['id'] == id)) {
      await _writeFavorites(
        _favoriteHotelsKey, current.where((m) => m['id'] != id).toList(),
      );
    } else {
      await _writeFavorites(_favoriteHotelsKey, [entry, ...current]);
    }
  }

  Future<void> toggleFavoriteRestaurant(Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    final current = favoriteRestaurants;
    if (current.any((m) => m['id'] == id)) {
      await _writeFavorites(
        _favoriteRestaurantsKey,
        current.where((m) => m['id'] != id).toList(),
      );
    } else {
      await _writeFavorites(_favoriteRestaurantsKey, [entry, ...current]);
    }
  }

  // -- Labeled favorite places (Home / Work / …) -----------------------

  /// User-labeled saved locations. Order is preserved (most recently
  /// upserted first). Labels are unique — re-saving a label replaces
  /// the previous entry rather than duplicating.
  List<FavoritePlace> get favoritePlaces {
    final raw = _prefs.getStringList(_favoritePlacesKey) ?? const <String>[];
    return raw
        .map((s) {
          try {
            return FavoritePlace.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoritePlace>()
        .toList(growable: false);
  }

  Future<void> upsertFavoritePlace(FavoritePlace place) async {
    final current = favoritePlaces
        .where((p) => p.label.toLowerCase() != place.label.toLowerCase())
        .toList();
    final next = [place, ...current];
    await _prefs.setStringList(
      _favoritePlacesKey,
      next.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> removeFavoritePlace(String label) async {
    final key = label.toLowerCase();
    final next = favoritePlaces
        .where((p) => p.label.toLowerCase() != key)
        .toList();
    await _prefs.setStringList(
      _favoritePlacesKey,
      next.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> reset() async {
    await _prefs.remove(_onboardingKey);
    await _prefs.remove(_themeModeKey);
    await _prefs.remove(_localeKey);
    await _prefs.remove(_unitSystemKey);
    await _prefs.remove(_tripProfileKey);
    await _prefs.remove(_premiumKey);
    await _prefs.remove(_authTokenKey);
    await _prefs.remove(_authUserKey);
    await _prefs.remove(_recentSearchesKey);
    await _prefs.remove(_favoriteHotelsKey);
    await _prefs.remove(_favoriteRestaurantsKey);
    await _prefs.remove(_favoritePlacesKey);
  }
}

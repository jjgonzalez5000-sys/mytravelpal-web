import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';
import '../config/beta_access.dart';
import '../domain/auth_user.dart';
import '../domain/emergency_contact.dart';
import '../domain/favorite_place.dart';
import '../domain/my_place.dart';
import '../domain/trip_profile.dart';
import '../domain/units.dart';
import '../widgets/hotel_preferences.dart';
import '../widgets/restaurant_preferences.dart';

/// UI spacing tier — controls global `visualDensity`, card margins,
/// chip padding and body-font scaling so power users can pack more
/// information on-screen without switching to a smaller device font.
enum UiDensity {
  comfortable,
  compact,
  ;

  String get slug => name;

  static UiDensity fromSlug(String? s) => switch (s) {
        'compact' => UiDensity.compact,
        _ => UiDensity.comfortable,
      };
}

/// One-liner preferences that don't fit the trip-storage abstraction.
///
/// The onboarding flag lives here so `SplashScreen` can synchronously
/// route new users to the intro and returning users straight to planning.
class AppPrefs {
  AppPrefs(this._prefs);

  // Bumped to v2 (2026-08-25) when we expanded the tour with slides
  // about real fuel prices, Android Auto integration and the live
  // trip dashboard. Users who saw v1 will see v2 once so they're
  // aware of the killer features shipped since their install.
  static const _onboardingKey = 'onboarding_shown.v2';
  static const _profileWizardKey = 'profile_wizard_shown.v1';
  static const _themeModeKey = 'theme_mode.v1';
  static const _themePresetKey = 'theme_preset.v1';
  static const _themeDynamicKey = 'theme_dynamic.v1';
  static const _themeOledKey = 'theme_oled.v1';
  static const _uiDensityKey = 'ui_density.v1';
  static const _localeKey = 'locale.v1';
  // Key must match Kotlin TripCompanionScreen.KEY_NOTIF_SOUND prefix
  // (flutter. is added automatically by the shared_preferences plugin).
  static const _notifSoundKey = 'notificationSound';
  static const _tollAlternativeDefaultKey = 'toll_alternative_default.v1';
  static const _unitSystemKey = 'unit_system.v1';
  static const _tripProfileKey = 'trip_profile.v1';
  static const _premiumKey = 'premium.v1';
  static const _authTokenKey = 'auth_token.v1';
  static const _authUserKey = 'auth_user.v1';
  static const _recentSearchesKey = 'recent_searches.v1';
  static const _favoriteHotelsKey = 'favorite_hotels.v1';
  static const _favoriteRestaurantsKey = 'favorite_restaurants.v1';
  static const _favoritePlacesKey = 'favorite_places.v1';
  static const _myPlacesKey = 'my_places.v1';
  static const _myPlacesTouchedKey = 'my_places_touched.v1';
  static const _emergencyContactsKey = 'emergency_contacts.v1';
  static const _currencyCodeKey = 'currency_code.v1';
  // Trip planning prefs — persisted so hotel/restaurant search
  // preferences survive across app launches and re-installs (via
  // the profile push, which piggybacks on `appSettingsSnapshot`).
  static const _hotelPrefsKey = 'hotel_prefs.v1';
  static const _restaurantPrefsKey = 'restaurant_prefs.v1';
  // Version-bump detection: the last versionCode this user saw the
  // What's-new sheet for. Bumped whenever the sheet is dismissed
  // so the same release notes never show twice.
  static const _lastSeenBuildKey = 'whats_new.last_seen_build.v1';
  // Free-tier AI Inspire weekly usage: JSON {"week":"YYYY-WW","count":N}.
  // Bumped on every generate call; resets automatically when the ISO week
  // changes so the user gets a fresh credit each Monday.
  static const _inspireWeeklyCountKey = 'inspire_weekly_count.v1';
  static const _recentSearchesLimit = 8;
  static const _emergencyContactsLimit = 3;
  // Hall of Fame leaderboard identity. Stored locally and pushed
  // to /v1/profile so the backend can rank the user's trips.
  static const _hallNickKey = 'hall_nick.v1';
  static const _hallCountryKey = 'hall_country.v1';

  final SharedPreferences _prefs;

  static Future<AppPrefs> open() async =>
      AppPrefs(await SharedPreferences.getInstance());

  bool get onboardingShown => _prefs.getBool(_onboardingKey) ?? false;
  bool get profileWizardShown => _prefs.getBool(_profileWizardKey) ?? false;
  Future<void> setOnboardingShown() => _prefs.setBool(_profileWizardKey, true);
  Future<void> markOnboardingShown() =>
      _prefs.setBool(_onboardingKey, true);

  // -- AI Inspire weekly gate (Free tier) ----------------------------------

  /// ISO week tag for the current calendar week, e.g. "2026-W40".
  static String _currentIsoWeek() {
    final now = DateTime.now();
    // ISO week number per ISO 8601: week 1 = week containing first Thursday.
    final dayOfYear = now.difference(DateTime(now.year)).inDays + 1;
    final dow = now.weekday; // 1=Mon … 7=Sun
    final isoWeek = ((dayOfYear - dow + 10) ~/ 7);
    return '${now.year}-W${isoWeek.toString().padLeft(2, '0')}';
  }

  /// How many AI Inspire generations the user has triggered this calendar week.
  int get inspireWeekUsage {
    final raw = _prefs.getString(_inspireWeeklyCountKey);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['week'] != _currentIsoWeek()) return 0;
      return (map['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Increment the weekly Inspire generation counter.
  Future<void> incrementInspireWeekUsage() async {
    final week = _currentIsoWeek();
    final current = inspireWeekUsage;
    await _prefs.setString(
      _inspireWeeklyCountKey,
      jsonEncode({'week': week, 'count': current + 1}),
    );
  }

  /// versionCode the user last acknowledged the What's-new sheet for.
  /// null = fresh install (What's-new suppressed — first-run onboarding
  /// carries the pitch instead). Positive int = install has seen at
  /// least one release; a higher current build triggers the sheet.
  int? get lastSeenBuild => _prefs.getInt(_lastSeenBuildKey);
  Future<void> setLastSeenBuild(int build) =>
      _prefs.setInt(_lastSeenBuildKey, build);

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

  /// Curated colour-scheme preset (Sunset / Ocean / Forest).
  /// Ignored when [themeDynamicEnabled] is true and dynamic colour
  /// is available on the device (Android 12+). Stored as the enum
  /// value's short slug.
  String get themePreset => _prefs.getString(_themePresetKey) ?? 'forest';
  Future<void> setThemePreset(String preset) =>
      _prefs.setString(_themePresetKey, preset);

  /// Material You dynamic colour. When true and the device
  /// exposes system colours (Android 12+), we seed the ColorScheme
  /// from the user's wallpaper instead of the preset. Falls back
  /// silently to the preset on unsupported devices / iOS.
  bool get themeDynamicEnabled => _prefs.getBool(_themeDynamicKey) ?? false;
  Future<void> setThemeDynamicEnabled(bool value) =>
      _prefs.setBool(_themeDynamicKey, value);

  /// Pure-black background in dark mode (OLED battery win). No
  /// effect in light mode. Off by default so the palette stays
  /// consistent for beta testers.
  bool get themeOledEnabled => _prefs.getBool(_themeOledKey) ?? false;
  Future<void> setThemeOledEnabled(bool value) =>
      _prefs.setBool(_themeOledKey, value);

  /// Global UI density. `comfortable` matches Material defaults;
  /// `compact` tightens vertical padding on cards + chips and scales
  /// body/title fonts down slightly so more content fits per screen
  /// without switching to a smaller system font.
  UiDensity get uiDensity => UiDensity.fromSlug(_prefs.getString(_uiDensityKey));
  Future<void> setUiDensity(UiDensity value) =>
      _prefs.setString(_uiDensityKey, value.slug);

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

  /// Snapshot of every UX-shaping setting stored in prefs, serialisable
  /// for backend sync. The names are wire keys — do NOT rename them
  /// once shipped or existing profiles stop restoring their theme /
  /// locale on reinstall.
  Map<String, dynamic> appSettingsSnapshot() => {
        'theme_mode': switch (themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
        'theme_preset': themePreset,
        'theme_dynamic_enabled': themeDynamicEnabled,
        'theme_oled_enabled': themeOledEnabled,
        'ui_density': uiDensity.slug,
        'locale_override': localeOverride?.languageCode,
        'unit_system': unitSystem.code,
        'currency_code': currencyCode,
        if (hallNick != null) 'hall_nick': hallNick,
        if (hallCountry != null) 'hall_country': hallCountry,
      };

  /// Apply a snapshot (as returned by the backend). Silently ignores
  /// unknown keys so future additions are backward-compatible with
  /// older clients that saved earlier snapshots.
  Future<void> applyAppSettings(Map<String, dynamic> s) async {
    Future<void> _apply(String key, Future<void> Function() body) async {
      if (s.containsKey(key)) await body();
    }

    await _apply('theme_mode', () async {
      switch (s['theme_mode']) {
        case 'light':
          await setThemeMode(ThemeMode.light);
        case 'dark':
          await setThemeMode(ThemeMode.dark);
        default:
          await setThemeMode(ThemeMode.system);
      }
    });
    await _apply('theme_preset', () =>
        setThemePreset(s['theme_preset'] as String? ?? 'forest'));
    await _apply('theme_dynamic_enabled', () =>
        setThemeDynamicEnabled(s['theme_dynamic_enabled'] as bool? ?? false));
    await _apply('theme_oled_enabled', () =>
        setThemeOledEnabled(s['theme_oled_enabled'] as bool? ?? false));
    await _apply('ui_density', () =>
        setUiDensity(UiDensity.fromSlug(s['ui_density'] as String?)));
    await _apply('locale_override', () {
      final code = s['locale_override'] as String?;
      return setLocaleOverride(
          code == null || code.isEmpty ? null : Locale(code));
    });
    await _apply('unit_system', () =>
        setUnitSystem(UnitSystem.fromCode(s['unit_system'] as String?)));
    await _apply('currency_code',
        () => setCurrencyCode(s['currency_code'] as String? ?? 'EUR'));
    await _apply('hall_nick', () async {
      final nick = s['hall_nick'] as String?;
      if (nick != null && nick.isNotEmpty) await setHallNick(nick);
    });
    await _apply('hall_country', () async {
      final country = s['hall_country'] as String?;
      if (country != null && country.isNotEmpty) await setHallCountry(country);
    });
  }

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

  /// Persisted hotel-search preferences (max detour, price bands,
  /// stars, wifi/parking flags, etc). Falls back to
  /// `HotelPreferences.enabledDefault` when the user hasn't opened
  /// the plan form yet so the first plan already has sensible
  /// choices instead of empty defaults.
  HotelPreferences get hotelPrefs {
    final raw = _prefs.getString(_hotelPrefsKey);
    if (raw == null || raw.isEmpty) return HotelPreferences.enabledDefault;
    try {
      return HotelPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return HotelPreferences.enabledDefault;
    }
  }

  Future<void> setHotelPrefs(HotelPreferences prefs) =>
      _prefs.setString(_hotelPrefsKey, jsonEncode(prefs.toJson()));

  /// Persisted restaurant-search preferences (max detour, price
  /// bands, cuisines, diet toggles). Defaults to
  /// `RestaurantPreferences.enabledDefault` (search ON) for the
  /// first plan after a fresh install — tester ask 2026-09-28:
  /// most drivers want meal suggestions along the corridor without
  /// having to toggle a switch first.
  RestaurantPreferences get restaurantPrefs {
    final raw = _prefs.getString(_restaurantPrefsKey);
    if (raw == null || raw.isEmpty) {
      return RestaurantPreferences.enabledDefault;
    }
    try {
      return RestaurantPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return RestaurantPreferences.enabledDefault;
    }
  }

  Future<void> setRestaurantPrefs(RestaurantPreferences prefs) =>
      _prefs.setString(_restaurantPrefsKey, jsonEncode(prefs.toJson()));

  // Premium defaults ON until we wire real receipt validation
  // (App Store / Play Billing). During the closed beta every feature
  // is unlocked so users can exercise the full planner. Flip the
  // default when the paywall lands.
  bool get isPremium =>
      _prefs.getBool(_premiumKey) ??
      premiumFlagForTier(defaultTierFor(betaAccess: kBetaAccess));
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

  // -- My places (stops worth making) -----------------------------------

  /// Places the driver saved to be offered when a route passes near them.
  /// Corrupt entries are skipped rather than failing the whole list.
  List<MyPlace> get myPlaces {
    final raw = _prefs.getStringList(_myPlacesKey) ?? const <String>[];
    final out = <MyPlace>[];
    for (final s in raw) {
      try {
        out.add(MyPlace.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> setMyPlaces(List<MyPlace> places) => _prefs.setStringList(
        _myPlacesKey,
        places.map((p) => jsonEncode(p.toJson())).toList(),
      );

  /// True once the driver has added or removed a place on this device.
  /// Only then is the list pushed to the server: a fresh install must not
  /// overwrite the account's places with an empty list before the first sync.
  bool get myPlacesTouched => _prefs.getBool(_myPlacesTouchedKey) ?? false;
  Future<void> markMyPlacesTouched() =>
      _prefs.setBool(_myPlacesTouchedKey, true);

  /// Emergency contacts for crash detection. Up to
  /// [_emergencyContactsLimit] persons receive an SMS with the
  /// impact location when the Companion detects a crash.
  List<EmergencyContact> get emergencyContacts {
    final raw = _prefs.getStringList(_emergencyContactsKey) ??
        const <String>[];
    final out = <EmergencyContact>[];
    for (final s in raw) {
      try {
        out.add(EmergencyContact.fromJson(
          jsonDecode(s) as Map<String, dynamic>,
        ));
      } catch (_) {
        // Skip corrupted entries silently.
      }
    }
    return out;
  }

  /// Currency code (ISO-4217) the user prefers to see costs in.
  /// Defaults to EUR — backend always emits EUR, conversion is
  /// client-side via `CurrencyService`.
  String get currencyCode => _prefs.getString(_currencyCodeKey) ?? 'EUR';

  Future<void> setCurrencyCode(String code) async {
    await _prefs.setString(_currencyCodeKey, code);
  }

  /// Notification sound for Companion alerts.
  /// Values: "default" | "silent"
  String get notificationSound => _prefs.getString(_notifSoundKey) ?? 'default';

  /// Whether to show toll-alternative routes by default in PlanScreen.
  bool get tollAlternativeDefault =>
      _prefs.getBool(_tollAlternativeDefaultKey) ?? true;
  Future<void> setTollAlternativeDefault(bool v) =>
      _prefs.setBool(_tollAlternativeDefaultKey, v);

  Future<void> setNotificationSound(String value) async {
    await _prefs.setString(_notifSoundKey, value);
  }

  Future<void> setEmergencyContacts(List<EmergencyContact> list) async {
    final capped = list.take(_emergencyContactsLimit).toList();
    await _prefs.setStringList(
      _emergencyContactsKey,
      capped.map((c) => jsonEncode(c.toJson())).toList(),
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

  /// Wipe everything the current account owns while KEEPING device
  /// preferences that survive a re-login (locale, theme, unit
  /// system, currency, density, onboarding flag).
  ///
  /// Called after a successful "delete my account" so the next
  /// launch lands on the login screen with a clean slate, but the
  /// user isn't asked to re-pick their language / theme / units
  /// again — those are device-level, not account-level.
  Future<void> clearUserScoped() async {
    await _prefs.remove(_authTokenKey);
    await _prefs.remove(_authUserKey);
    await _prefs.remove(_tripProfileKey);
    await _prefs.remove(_premiumKey);
    await _prefs.remove(_recentSearchesKey);
    await _prefs.remove(_favoriteHotelsKey);
    await _prefs.remove(_favoriteRestaurantsKey);
    await _prefs.remove(_favoritePlacesKey);
    await _prefs.remove(_emergencyContactsKey);
    await _prefs.remove(_myPlacesKey);
    await _prefs.remove(_myPlacesTouchedKey);
    await _prefs.remove(_hallNickKey);
    await _prefs.remove(_hallCountryKey);
  }

  String? get hallNick => _prefs.getString(_hallNickKey);
  Future<void> setHallNick(String nick) =>
      _prefs.setString(_hallNickKey, nick.trim());
  Future<void> clearHallNick() => _prefs.remove(_hallNickKey);

  String? get hallCountry => _prefs.getString(_hallCountryKey);
  Future<void> setHallCountry(String countryCode) =>
      _prefs.setString(_hallCountryKey, countryCode);
  Future<void> clearHallCountry() => _prefs.remove(_hallCountryKey);
}

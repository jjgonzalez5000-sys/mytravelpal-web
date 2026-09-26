import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'domain/auth_user.dart';
import 'domain/favorite_place.dart';
import 'domain/trip_profile.dart';
import 'domain/units.dart';
import 'domain/vehicle_model.dart';
import 'services/current_location.dart';
import 'storage/app_prefs.dart';
import 'storage/inspiration_storage.dart';
import 'storage/trip_storage.dart';
import 'theme.dart';

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

/// Local storage for Trip Inspiration proposals the user chose
/// to keep. Lightweight FIFO in SharedPreferences (cap 20).
final inspirationStorageProvider = Provider<InspirationStorage>(
  (ref) => throw UnimplementedError(
    'inspirationStorageProvider must be overridden at ProviderScope',
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

/// Curated colour preset (Forest / Sunset / Ocean). See
/// [ThemePreset] in `theme.dart`. Ignored when dynamic colour is
/// enabled AND the device is Android 12+ (the wallpaper wins).
class ThemePresetNotifier extends StateNotifier<ThemePreset> {
  ThemePresetNotifier(this._prefs)
      : super(ThemePreset.fromSlug(_prefs.themePreset));
  final AppPrefs _prefs;

  Future<void> set(ThemePreset preset) async {
    state = preset;
    await _prefs.setThemePreset(preset.slug);
  }
}

final themePresetProvider =
    StateNotifierProvider<ThemePresetNotifier, ThemePreset>((ref) {
  return ThemePresetNotifier(ref.watch(appPrefsProvider));
});

/// Material You dynamic-colour toggle. Persisted; effective only
/// when the device exposes wallpaper colours (Android 12+).
class ThemeDynamicNotifier extends StateNotifier<bool> {
  ThemeDynamicNotifier(this._prefs) : super(_prefs.themeDynamicEnabled);
  final AppPrefs _prefs;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setThemeDynamicEnabled(value);
  }
}

final themeDynamicProvider =
    StateNotifierProvider<ThemeDynamicNotifier, bool>((ref) {
  return ThemeDynamicNotifier(ref.watch(appPrefsProvider));
});

/// Pure-black dark-mode surface toggle (OLED battery + contrast).
class ThemeOledNotifier extends StateNotifier<bool> {
  ThemeOledNotifier(this._prefs) : super(_prefs.themeOledEnabled);
  final AppPrefs _prefs;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setThemeOledEnabled(value);
  }
}

final themeOledProvider =
    StateNotifierProvider<ThemeOledNotifier, bool>((ref) {
  return ThemeOledNotifier(ref.watch(appPrefsProvider));
});

/// Global UI density (comfortable / compact). Persisted so the
/// preference survives restarts and applies before the first frame
/// paints (Splash reads it via the theme builder).
class UiDensityNotifier extends StateNotifier<UiDensity> {
  UiDensityNotifier(this._prefs) : super(_prefs.uiDensity);
  final AppPrefs _prefs;

  Future<void> set(UiDensity value) async {
    state = value;
    await _prefs.setUiDensity(value);
  }
}

final uiDensityProvider =
    StateNotifierProvider<UiDensityNotifier, UiDensity>((ref) {
  return UiDensityNotifier(ref.watch(appPrefsProvider));
});

/// User-picked locale override — null means "follow system".
///
/// The MaterialApp reads this and passes it as `locale:`. When null,
/// Flutter falls back to the device locale intersected with our
/// `supportedLocales`.
class LocaleOverrideNotifier extends StateNotifier<Locale?> {
  LocaleOverrideNotifier(this._prefs) : super(_prefs.localeOverride);
  final AppPrefs _prefs;

  Future<void> set(Locale? locale) async {
    state = locale;
    await _prefs.setLocaleOverride(locale);
  }
}

final localeOverrideProvider =
    StateNotifierProvider<LocaleOverrideNotifier, Locale?>((ref) {
  return LocaleOverrideNotifier(ref.watch(appPrefsProvider));
});

/// Preferred measurement system (metric / imperial). Metric default —
/// most users in our launch markets expect it.
class UnitSystemNotifier extends StateNotifier<UnitSystem> {
  UnitSystemNotifier(this._prefs) : super(_prefs.unitSystem);
  final AppPrefs _prefs;

  Future<void> set(UnitSystem system) async {
    state = system;
    await _prefs.setUnitSystem(system);
  }
}

final unitSystemProvider =
    StateNotifierProvider<UnitSystemNotifier, UnitSystem>((ref) {
  return UnitSystemNotifier(ref.watch(appPrefsProvider));
});

/// Convenience: a ready-to-use [UnitFormatter] for the current system.
final unitFormatterProvider = Provider<UnitFormatter>((ref) {
  return UnitFormatter(ref.watch(unitSystemProvider));
});

/// User-selected display currency (ISO-4217). Backend always sends
/// EUR — this is only for how costs render on the client.
class CurrencyNotifier extends StateNotifier<String> {
  CurrencyNotifier(this._prefs) : super(_prefs.currencyCode);
  final AppPrefs _prefs;

  Future<void> set(String code) async {
    state = code;
    await _prefs.setCurrencyCode(code);
  }
}

final currencyCodeProvider =
    StateNotifierProvider<CurrencyNotifier, String>((ref) {
  return CurrencyNotifier(ref.watch(appPrefsProvider));
});

/// Current [TripProfile], or null if the user hasn't set one yet.
class TripProfileNotifier extends StateNotifier<TripProfile?> {
  TripProfileNotifier(this._prefs, {this.api}) : super(_prefs.tripProfile);
  final AppPrefs _prefs;
  ApiClient? api;

  Future<void> set(TripProfile? profile) async {
    state = profile;
    await _prefs.setTripProfile(profile);
    _pushToServer(profile);
  }

  /// Called by [RecentSearchesNotifier] when the user picks a new
  /// place — pushes the same profile blob (which embeds recents
  /// via `_recent_searches`) so the server gets an updated view.
  /// Cheap: single PUT, fire-and-forget.
  void pushRecentsChange() => _pushToServer(state);

  void _pushToServer(TripProfile? profile) {
    if (api == null || profile == null) return;
    // Embed recents inside the profile blob so a single JSONB
    // column round-trips everything. Previous code passed a
    // `{profile: ..., recent_searches: ...}` dict where the client
    // expected the top level and `saveProfile` re-wrapped it under
    // `profile`, so the server persisted a doubly-nested blob and
    // the round trip only worked by accident. Now the wire body
    // is a single wrap: `{profile: {...profile, _recent_searches:
    // [...]}}` — matches the server's `ProfilePayload` contract.
    final profileJson = profile.toJson();
    final recents = _prefs.recentSearches;
    if (recents.isNotEmpty) {
      profileJson['_recent_searches'] = recents
          .map((r) => {
                'displayName': r.displayName,
                'lat': r.coordinate.lat,
                'lon': r.coordinate.lon,
                'country': r.country.code,
              })
          .toList();
    }
    api!.saveProfile(profileJson);
  }

  Future<void> syncFromServer() async {
    if (api == null) return;
    final remote = await api!.fetchProfile();
    if (remote != null) {
      // Server returns the raw profile blob (post-fix) OR the
      // legacy doubly-nested `{profile: {...}, recent_searches:
      // [...]}` blob for accounts saved before the fix. Detect
      // both.
      final Map<String, dynamic> profileData;
      final Object? recents;
      final legacyProfile = remote['profile'];
      if (legacyProfile is Map<String, dynamic>) {
        // Legacy nested shape.
        profileData = legacyProfile;
        recents = remote['recent_searches'];
      } else {
        // New shape: `remote` IS the profile, with recents
        // embedded under `_recent_searches`.
        profileData = remote;
        recents = remote['_recent_searches'];
      }
      try {
        final profile = TripProfile.fromJson(profileData);
        state = profile;
        await _prefs.setTripProfile(profile);
      } catch (_) {}
      if (recents is List && recents.isNotEmpty) {
        for (final r in recents) {
          if (r is Map<String, dynamic>) {
            try {
              _prefs.pushRecentSearch(GeocodeResult(
                displayName: r['displayName'] as String,
                coordinate: LatLon(
                  lat: (r['lat'] as num).toDouble(),
                  lon: (r['lon'] as num).toDouble(),
                ),
                country: Country.fromCode(r['country'] as String),
              ));
            } catch (_) {}
          }
        }
      }
    } else if (state != null) {
      _pushToServer(state);
    }
  }

  Future<void> clear() => set(null);
}

final tripProfileProvider =
    StateNotifierProvider<TripProfileNotifier, TripProfile?>((ref) {
  final notifier = TripProfileNotifier(ref.watch(appPrefsProvider));
  final auth = ref.watch(authProvider);
  if (auth.token != null) {
    notifier.api = ref.read(apiClientWithPremiumProvider);
  }
  return notifier;
});

/// Whether the user is on the Premium tier. MVP: local toggle only —
/// no real IAP verification. When we wire RevenueCat / StoreKit /
/// Play Billing this notifier's value comes from a verified receipt.
class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier(this._prefs) : super(_prefs.isPremium);
  final AppPrefs _prefs;

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setPremium(value);
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier(ref.watch(appPrefsProvider));
});

@immutable
class AuthState {
  const AuthState({this.user, this.token});
  final AuthUser? user;
  final String? token;

  bool get isAuthenticated => user != null && token != null;
}

/// Authentication state: the current user + JWT, or none. Persisted in
/// `AppPrefs` so the user stays signed in across launches.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._prefs)
      : super(AuthState(user: _prefs.authUser, token: _prefs.authToken));

  final AppPrefs _prefs;

  Future<void> set(AuthUser user, String token) async {
    state = AuthState(user: user, token: token);
    await _prefs.setAuthSession(token, user);
  }

  Future<void> signOut() async {
    state = const AuthState();
    await _prefs.setAuthSession(null, null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(appPrefsProvider));
});

/// `ApiClient` bound to the current premium + auth state so requests
/// carry the `X-MyTravelPal-Premium` and `Authorization: Bearer …`
/// headers when applicable.
final apiClientWithPremiumProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(apiClientProvider);
  final premium = ref.watch(premiumProvider);
  final auth = ref.watch(authProvider);
  base.setPremium(premium);
  base.setAuthToken(auth.token);
  return base;
});

/// Recent geocode picks, most recent first, capped at 8. Rebuilt from
/// prefs on every mutation so widgets watching this rebuild too.
///
/// Every mutation triggers `TripProfileNotifier._pushToServer` too so
/// the recents ride into Postgres alongside the profile blob and
/// survive a "clear app data + re-login" cycle. Without this hook,
/// only the profile fields synced back on login and the user got
/// their preferences but an empty search history.
class RecentSearchesNotifier extends StateNotifier<List<GeocodeResult>> {
  RecentSearchesNotifier(this._prefs, this._onChanged)
      : super(_prefs.recentSearches);
  final AppPrefs _prefs;
  final VoidCallback _onChanged;

  Future<void> push(GeocodeResult r) async {
    await _prefs.pushRecentSearch(r);
    state = _prefs.recentSearches;
    _onChanged();
  }

  Future<void> clear() async {
    await _prefs.clearRecentSearches();
    state = const [];
    _onChanged();
  }
}

final recentSearchesProvider = StateNotifierProvider<
    RecentSearchesNotifier, List<GeocodeResult>>((ref) {
  return RecentSearchesNotifier(
    ref.watch(appPrefsProvider),
    () {
      // Re-push the current profile+recents blob to the server.
      // Cheap (single PUT) and fire-and-forget so mutations feel
      // instant. Skipped internally if the user isn't logged in.
      final notifier = ref.read(tripProfileProvider.notifier);
      final current = ref.read(tripProfileProvider);
      if (current != null) notifier.pushRecentsChange();
    },
  );
});

/// One-shot service to resolve device location → nearest known place.
final currentLocationServiceProvider = Provider<CurrentLocationService>((ref) {
  return CurrentLocationService(ref.watch(apiClientWithPremiumProvider));
});

/// Reactive favorites list. Stored as untyped maps so schema drift in
/// [Hotel]/[Restaurant] doesn't invalidate old prefs.
class FavoritesNotifier extends StateNotifier<_FavoritesState> {
  FavoritesNotifier(this._prefs)
      : super(_FavoritesState(
          hotels: _prefs.favoriteHotels,
          restaurants: _prefs.favoriteRestaurants,
        ));
  final AppPrefs _prefs;

  Future<void> toggleHotel(Map<String, dynamic> entry) async {
    await _prefs.toggleFavoriteHotel(entry);
    state = _FavoritesState(
      hotels: _prefs.favoriteHotels,
      restaurants: state.restaurants,
    );
  }

  Future<void> toggleRestaurant(Map<String, dynamic> entry) async {
    await _prefs.toggleFavoriteRestaurant(entry);
    state = _FavoritesState(
      hotels: state.hotels,
      restaurants: _prefs.favoriteRestaurants,
    );
  }
}

@immutable
class _FavoritesState {
  const _FavoritesState({required this.hotels, required this.restaurants});
  final List<Map<String, dynamic>> hotels;
  final List<Map<String, dynamic>> restaurants;
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, _FavoritesState>((ref) {
  return FavoritesNotifier(ref.watch(appPrefsProvider));
});

bool isFavoriteHotel(WidgetRef ref, String id) =>
    ref.watch(favoritesProvider).hotels.any((m) => m['id'] == id);
bool isFavoriteRestaurant(WidgetRef ref, String id) =>
    ref.watch(favoritesProvider).restaurants.any((m) => m['id'] == id);

List<Map<String, dynamic>> favoriteHotels(WidgetRef ref) =>
    ref.watch(favoritesProvider).hotels;
List<Map<String, dynamic>> favoriteRestaurants(WidgetRef ref) =>
    ref.watch(favoritesProvider).restaurants;

/// User-labeled places (Home, Work, School, custom). Order preserved,
/// most-recent-first, labels unique (case-insensitive).
class FavoritePlacesNotifier extends StateNotifier<List<FavoritePlace>> {
  FavoritePlacesNotifier(this._prefs) : super(_prefs.favoritePlaces);
  final AppPrefs _prefs;

  Future<void> upsert({
    required String label, required GeocodeResult place,
  }) async {
    await _prefs.upsertFavoritePlace(
      FavoritePlace(label: label, place: place),
    );
    state = _prefs.favoritePlaces;
  }

  Future<void> remove(String label) async {
    await _prefs.removeFavoritePlace(label);
    state = _prefs.favoritePlaces;
  }
}

final favoritePlacesProvider = StateNotifierProvider<
    FavoritePlacesNotifier, List<FavoritePlace>>((ref) {
  return FavoritePlacesNotifier(ref.watch(appPrefsProvider));
});

/// Curated top-EU vehicle catalogue fetched from `/v1/vehicles`.
///
/// The endpoint's payload is small (~50 rows) and the CDN can cache it
/// for a day — but re-hitting it on every profile screen entry is
/// still wasteful, so wrap it in a `FutureProvider` that only fires
/// once per app run.
final vehicleCatalogueProvider =
    FutureProvider<List<VehicleModel>>((ref) async {
  final api = ref.watch(apiClientWithPremiumProvider);
  return api.listVehicles();
});

/// True while [CompanionDriveScreen] is mounted. Read in [AppShell] to
/// show a badge on the Companion tab when a session is running in the
/// background.
final companionActiveProvider = StateProvider<bool>((ref) => false);

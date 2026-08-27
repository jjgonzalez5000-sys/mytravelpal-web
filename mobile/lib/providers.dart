import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'domain/auth_user.dart';
import 'domain/favorite_place.dart';
import 'domain/trip_profile.dart';
import 'domain/units.dart';
import 'services/current_location.dart';
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

/// Current [TripProfile], or null if the user hasn't set one yet.
class TripProfileNotifier extends StateNotifier<TripProfile?> {
  TripProfileNotifier(this._prefs, {this.api}) : super(_prefs.tripProfile);
  final AppPrefs _prefs;
  ApiClient? api;

  Future<void> set(TripProfile? profile) async {
    state = profile;
    await _prefs.setTripProfile(profile);
    if (profile != null && api != null) {
      api!.saveProfile(profile.toJson());
    }
  }

  Future<void> syncFromServer() async {
    if (api == null) return;
    final remote = await api!.fetchProfile();
    if (remote != null) {
      try {
        final profile = TripProfile.fromJson(remote);
        state = profile;
        await _prefs.setTripProfile(profile);
      } catch (_) {}
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
class RecentSearchesNotifier extends StateNotifier<List<GeocodeResult>> {
  RecentSearchesNotifier(this._prefs) : super(_prefs.recentSearches);
  final AppPrefs _prefs;

  Future<void> push(GeocodeResult r) async {
    await _prefs.pushRecentSearch(r);
    state = _prefs.recentSearches;
  }

  Future<void> clear() async {
    await _prefs.clearRecentSearches();
    state = const [];
  }
}

final recentSearchesProvider = StateNotifierProvider<
    RecentSearchesNotifier, List<GeocodeResult>>((ref) {
  return RecentSearchesNotifier(ref.watch(appPrefsProvider));
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

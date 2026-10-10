import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'config/beta_access.dart';
import 'domain/auth_user.dart';
import 'domain/emergency_contact.dart';
import 'domain/favorite_place.dart';
import 'domain/garage_vehicle.dart';
import 'domain/my_place.dart';
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

class _NotifSoundNotifier extends StateNotifier<String> {
  _NotifSoundNotifier(this._prefs) : super(_prefs.notificationSound);
  final AppPrefs _prefs;
  Future<void> set(String v) async {
    state = v;
    await _prefs.setNotificationSound(v);
  }
}

final notifSoundProvider =
    StateNotifierProvider<_NotifSoundNotifier, String>((ref) {
  return _NotifSoundNotifier(ref.watch(appPrefsProvider));
});

/// Current [TripProfile], or null if the user hasn't set one yet.
class TripProfileNotifier extends StateNotifier<TripProfile?> {
  TripProfileNotifier(this._prefs, {this.api, this.onAppSettingsApplied})
      : super(_prefs.tripProfile);
  final AppPrefs _prefs;
  ApiClient? api;

  /// Fired after `syncFromServer` applies an `_app_settings` snapshot
  /// from the backend. The caller (the provider factory) wires this
  /// to `ref.invalidate(...)` for every settings provider so the UI
  /// picks up theme / locale / density / units / currency from the
  /// freshly-restored prefs. Without this, a clean install + Google
  /// login would restore the settings to disk but the running UI
  /// would keep painting with the boot-time defaults.
  void Function()? onAppSettingsApplied;

  /// Called after `syncFromServer` replaced the local "My places" list, so
  /// the provider that holds it can reload.
  void Function()? onMyPlacesRestored;

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

  /// Fired by any of the app-level settings notifiers (theme, locale,
  /// density, units, currency) when the user tweaks them. Pushes the
  /// current TripProfile (may be null) plus a fresh
  /// [AppPrefs.appSettingsSnapshot] to the backend so the setting
  /// survives a clean reinstall + Google re-login. Piggybacks on the
  /// existing PUT /v1/profile — no new endpoint.
  void pushSettingsChange() => _pushToServer(state);

  void _pushToServer(TripProfile? profile) {
    if (api == null) return;
    // Even without a TripProfile we still push the app-settings blob
    // — a fresh install that only changed the theme still deserves
    // to have that persisted server-side. Empty `{}` profile means
    // "no travel prefs yet, but here are my settings".
    final profileJson =
        profile != null ? profile.toJson() : <String, dynamic>{};
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
    profileJson['_app_settings'] = _prefs.appSettingsSnapshot();
    final contacts = _prefs.emergencyContacts;
    if (contacts.isNotEmpty) {
      profileJson['_emergency_contacts'] =
          contacts.map((c) => c.toJson()).toList();
    }
    final nick = _prefs.hallNick;
    if (nick != null && nick.isNotEmpty) {
      profileJson['_hall_nick'] = nick;
    }
    final country = _prefs.hallCountry;
    if (country != null && country.isNotEmpty) {
      profileJson['_hall_country'] = country;
    }
    if (_prefs.myPlacesTouched) {
      profileJson['_my_places'] =
          _prefs.myPlaces.map((p) => p.toJson()).toList();
    }
    api!.saveProfile(profileJson);
  }

  Future<void> syncFromServer() async {
    if (api == null) return;
    // Places the driver had when the request left; anything that shows up
    // locally after this was added while waiting for the server.
    final placeIdsAtStart = {for (final p in _prefs.myPlaces) p.id};
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
      // Apply the app-settings snapshot if the backend has one. Then
      // notify the caller (provider factory) so it can invalidate the
      // affected providers and the UI rebuilds with the restored
      // theme / locale / density / units / currency.
      final settings = profileData['_app_settings'];
      if (settings is Map<String, dynamic>) {
        try {
          await _prefs.applyAppSettings(settings);
          onAppSettingsApplied?.call();
        } catch (_) {}
      }
      // Restore emergency contacts if the server has them.
      final rawContacts = profileData['_emergency_contacts'];
      if (rawContacts is List && rawContacts.isNotEmpty) {
        try {
          final contacts = rawContacts
              .whereType<Map<String, dynamic>>()
              .map(EmergencyContact.fromJson)
              .toList();
          await _prefs.setEmergencyContacts(contacts);
        } catch (_) {}
      }
      // Restore Hall of Fame nick / country
      final nick = profileData['_hall_nick'];
      if (nick is String && nick.isNotEmpty) {
        try { await _prefs.setHallNick(nick); } catch (_) {}
      }
      final hallCountry = profileData['_hall_country'];
      if (hallCountry is String && hallCountry.isNotEmpty) {
        try { await _prefs.setHallCountry(hallCountry); } catch (_) {}
      }
      // "My places": every change is pushed as it happens, so the server
      // copy is the account's truth; adopt it (an empty list included, it
      // means the driver deleted them all).
      final rawPlaces = profileData['_my_places'];
      if (rawPlaces is List) {
        final restored = <MyPlace>[];
        for (final e in rawPlaces) {
          if (e is! Map<String, dynamic>) continue;
          try {
            restored.add(MyPlace.fromJson(e));
          } catch (_) {}
        }
        // A place added while the request was in flight is not in the
        // server's answer yet; adopting that answer verbatim would erase it.
        final restoredIds = {for (final p in restored) p.id};
        final addedMeanwhile = [
          for (final p in _prefs.myPlaces)
            if (!placeIdsAtStart.contains(p.id) &&
                !restoredIds.contains(p.id))
              p,
        ];
        restored.addAll(addedMeanwhile);
        try {
          await _prefs.setMyPlaces(restored);
          onMyPlacesRestored?.call();
          if (addedMeanwhile.isNotEmpty) _pushToServer(state);
        } catch (_) {}
      }
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

// Explicit type: this provider and `myPlacesProvider` refer to each other.
final StateNotifierProvider<TripProfileNotifier, TripProfile?>
    tripProfileProvider =
    StateNotifierProvider<TripProfileNotifier, TripProfile?>((ref) {
  final notifier = TripProfileNotifier(ref.watch(appPrefsProvider));
  final auth = ref.watch(authProvider);
  if (auth.token != null) {
    notifier.api = ref.read(apiClientWithPremiumProvider);
  }
  // Wire the app-settings-applied callback so `syncFromServer` can
  // trigger a UI rebuild across every settings provider after
  // restoring a snapshot. Kept as a callback (not a direct ref
  // access) so the notifier stays testable without a ProviderScope.
  notifier.onAppSettingsApplied = () {
    ref.invalidate(themeModeProvider);
    ref.invalidate(themePresetProvider);
    ref.invalidate(themeDynamicProvider);
    ref.invalidate(themeOledProvider);
    ref.invalidate(uiDensityProvider);
    ref.invalidate(localeOverrideProvider);
    ref.invalidate(unitSystemProvider);
    ref.invalidate(currencyCodeProvider);
  };
  notifier.onMyPlacesRestored = () => ref.invalidate(myPlacesProvider);
  return notifier;
});

/// The driver's saved stops ("My places"). Every change is written to prefs
/// and pushed to the account profile so the list survives a reinstall.
class MyPlacesNotifier extends StateNotifier<List<MyPlace>> {
  MyPlacesNotifier(this._prefs, this._onChanged) : super(_prefs.myPlaces);

  final AppPrefs _prefs;
  final void Function() _onChanged;

  /// Cap that keeps the account profile blob small.
  static const int maxPlaces = 100;

  /// Adds [place] at the top. False (and nothing added) when the list is full.
  Future<bool> add(MyPlace place) async {
    if (state.length >= maxPlaces) return false;
    state = [place, ...state.where((p) => p.id != place.id)];
    await _save();
    return true;
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList(growable: false);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setMyPlaces(state);
    await _prefs.markMyPlacesTouched();
    _onChanged();
  }
}

final StateNotifierProvider<MyPlacesNotifier, List<MyPlace>> myPlacesProvider =
    StateNotifierProvider<MyPlacesNotifier, List<MyPlace>>((ref) {
  return MyPlacesNotifier(
    ref.watch(appPrefsProvider),
    () => ref.read(tripProfileProvider.notifier).pushSettingsChange(),
  );
});

/// Subscription tier for the current session.
///
/// Values: "free" | "essential" | "premium"
///
/// Initialized to "free"; [BillingService.initialize] and
/// [BillingService.restorePurchases] update this after verifying a
/// receipt with the backend. The legacy [premiumProvider] below
/// is an alias kept for backwards compatibility with all existing
/// gate checks.
// Closed beta (kBetaAccess, the default) starts everyone on 'premium'. A
// production build passes --dart-define=BETA_ACCESS=false and starts on 'free'.
final subscriptionTierProvider = StateProvider<String>(
  (ref) => defaultTierFor(betaAccess: kBetaAccess),
);

/// Sets the tier AND the legacy premium flag together. The flag is what the
/// API client sends to the server (`X-MyTravelPal-Premium`), so changing only
/// the tier left server-side premium gates stuck on the old value.
Future<void> applySubscriptionTier(WidgetRef ref, String tier) async {
  ref.read(subscriptionTierProvider.notifier).state = tier;
  await ref.read(premiumProvider.notifier).set(premiumFlagForTier(tier));
}

/// True when the user has an Essential or Premium subscription.
final isEssentialOrAboveProvider = Provider<bool>((ref) {
  final tier = ref.watch(subscriptionTierProvider);
  return tier == 'essential' || tier == 'premium';
});

/// True when the user has a Premium subscription.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionTierProvider) == 'premium';
});

/// Whether the user is on the Premium tier.
///
/// Kept as a [StateNotifierProvider] alias so all existing
/// [premiumProvider] gate checks continue to work without a
/// mass-rename refactor. [BillingService] writes through
/// [subscriptionTierProvider] AND calls [PremiumNotifier.set] so
/// both stay in sync. The initial value still reads from
/// [AppPrefs.isPremium] so dogfood builds where [AppPrefs.isPremium]
/// was hard-coded to true remain unaffected until the value is
/// explicitly changed by the purchase flow.
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

/// The user's saved "garage" — every vehicle they've added plus the
/// legacy auto-migrated one. Mutations go through the notifier so we
/// can echo them to the server without the UI having to await.
class GarageNotifier extends StateNotifier<List<GarageVehicle>> {
  GarageNotifier(this._api) : super(const []);

  final ApiClient _api;
  bool _loaded = false;

  /// One-shot cold-start load. Cheap (single GET, small payload) so
  /// callers can fire this from any screen that needs the list.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    state = await _api.fetchGarage();
  }

  /// Force a re-fetch — used when the user logs in with a different
  /// account or the server sent us a 401 mid-session.
  Future<void> refresh() async {
    state = await _api.fetchGarage();
  }

  Future<GarageVehicle?> add({
    required String name,
    required String modelId,
    int defaultTankPercent = 100,
    String? notes,
  }) async {
    try {
      final v = await _api.addGarageVehicle(
        name: name,
        modelId: modelId,
        defaultTankPercent: defaultTankPercent,
        notes: notes,
      );
      state = [...state, v];
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<bool> update({
    required String id,
    String? name,
    int? defaultTankPercent,
    String? notes,
  }) async {
    try {
      final updated = await _api.updateGarageVehicle(
        id: id,
        name: name,
        defaultTankPercent: defaultTankPercent,
        notes: notes,
      );
      state = [
        for (final v in state)
          if (v.id == updated.id) updated else v,
      ];
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(String id) async {
    final ok = await _api.deleteGarageVehicle(id);
    if (ok) state = state.where((v) => v.id != id).toList(growable: false);
    return ok;
  }
}

final garageProvider =
    StateNotifierProvider<GarageNotifier, List<GarageVehicle>>((ref) {
  final api = ref.watch(apiClientWithPremiumProvider);
  final notifier = GarageNotifier(api);
  // Fire-and-forget cold-start load once the notifier exists. Errors
  // are swallowed inside `fetchGarage` so the UI just sees "empty".
  final auth = ref.watch(authProvider);
  if (auth.isAuthenticated) {
    // ignore: discarded_futures
    notifier.ensureLoaded();
  }
  return notifier;
});

/// Which garage vehicle the user has selected for the CURRENT plan
/// screen session. Ephemeral — doesn't persist across app restarts;
/// the plan screen resets it whenever a new trip flow starts.
///
/// null = "no selection yet" → the plan chip shows either the first
/// saved vehicle as a preview (auto-pick) or "Añadir coche" when
/// the garage is empty.
final selectedGarageVehicleIdProvider = StateProvider<String?>((ref) => null);

/// Whether speed camera proximity alerts are enabled in Companion
/// drive mode. Default on; user can disable in Settings > Trip.
final radarAlertsEnabledProvider = StateProvider<bool>((ref) => true);

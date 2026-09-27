import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

/// Shared navigator key so services outside the widget tree — mainly
/// the deep-link handler — can push new routes.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MyTravelPalApp extends ConsumerWidget {
  const MyTravelPalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final localeOverride = ref.watch(localeOverrideProvider);
    final preset = ref.watch(themePresetProvider);
    final wantsDynamic = ref.watch(themeDynamicProvider);
    final oled = ref.watch(themeOledProvider);
    final density = ref.watch(uiDensityProvider);

    // Push every app-level UX setting to the backend whenever the user
    // tweaks it. Persists the theme / locale / density / units /
    // currency across clean reinstalls + Google re-login, so the user
    // doesn't have to re-configure their dark mode + Spanish + EUR
    // every time they wipe the app.
    void _syncSettings(_, __) {
      ref.read(tripProfileProvider.notifier).pushSettingsChange();
    }

    ref.listen(themeModeProvider, _syncSettings);
    ref.listen(themePresetProvider, _syncSettings);
    ref.listen(themeDynamicProvider, _syncSettings);
    ref.listen(themeOledProvider, _syncSettings);
    ref.listen(uiDensityProvider, _syncSettings);
    ref.listen(localeOverrideProvider, _syncSettings);
    ref.listen(unitSystemProvider, _syncSettings);
    ref.listen(currencyCodeProvider, _syncSettings);
    // DynamicColorBuilder runs the wallpaper-colour probe once per
    // context; on iOS + Android <12 both schemes come back null so
    // we fall back to the picked preset transparently.
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final effectiveLight = wantsDynamic ? lightDynamic : null;
        final effectiveDark = wantsDynamic ? darkDynamic : null;
        return MaterialApp(
          title: 'MyTravelPal',
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.buildLight(
            preset: preset,
            dynamicScheme: effectiveLight,
            density: density,
          ),
          darkTheme: AppTheme.buildDark(
            preset: preset,
            dynamicScheme: effectiveDark,
            oled: oled,
            density: density,
          ),
          themeMode: mode,
          locale: localeOverride,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

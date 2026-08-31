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
          ),
          darkTheme: AppTheme.buildDark(
            preset: preset,
            dynamicScheme: effectiveDark,
            oled: oled,
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

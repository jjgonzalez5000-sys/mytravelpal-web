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
    return MaterialApp(
      title: 'MyTravelPal',
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

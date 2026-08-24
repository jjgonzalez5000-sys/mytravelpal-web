import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

class MyTravelPalApp extends ConsumerWidget {
  const MyTravelPalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'MyTravelPal',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications.dart';
import 'storage/app_prefs.dart';
import 'storage/trip_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await TripStorage.open();
  final prefs = await AppPrefs.open();

  // Notifications init before runApp so the schedule call from
  // ResultScreen's Save button doesn't race the init.
  await NotificationService.instance.init();

  // Wire deep links after the widget tree has a navigator to push into.
  final deepLinks = DeepLinkHandler(rootNavigatorKey);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    deepLinks.start();
  });

  runApp(
    ProviderScope(
      overrides: [
        tripStorageProvider.overrideWithValue(storage),
        appPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MyTravelPalApp(),
    ),
  );
}

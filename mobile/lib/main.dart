import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications.dart';
import 'services/review_prompter.dart';
import 'services/widget_bridge.dart';
import 'storage/app_prefs.dart';
import 'storage/trip_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await TripStorage.open();
  final prefs = await AppPrefs.open();

  // Notifications init before runApp so the schedule call from
  // ResultScreen's Save button doesn't race the init.
  await NotificationService.instance.init();

  // Stamp the first-launch marker as early as possible so the
  // in-app review prompter can compute a real "days since install"
  // even for users who fire the first plan on day zero.
  await ReviewPrompter.instance.markLaunched();

  // Push the "next upcoming trip" summary to the home-screen widget
  // as soon as we know the current storage state. Widget users see
  // fresh countdown numbers the moment they unpin/re-pin the app or
  // launch it.
  // ignore: unawaited_futures
  storage.list().then((trips) => WidgetBridge.instance.refresh(trips));

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

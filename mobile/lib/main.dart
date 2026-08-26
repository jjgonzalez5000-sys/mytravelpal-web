import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'providers.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications.dart';
import 'services/review_prompter.dart';
import 'services/trip_foreground.dart';
import 'services/widget_bridge.dart';
import 'storage/app_prefs.dart';
import 'storage/trip_storage.dart';

const _kSentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_kSentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _kSentryDsn;
        options.tracesSampleRate = 0.1;
        options.environment = 'production';
      },
      appRunner: _boot,
    );
  } else {
    await _boot();
  }
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await TripStorage.open();
  final prefs = await AppPrefs.open();

  await NotificationService.instance.init();
  await TripForegroundService.instance.init();
  await ReviewPrompter.instance.markLaunched();

  // ignore: unawaited_futures
  storage.list().then((trips) => WidgetBridge.instance.refresh(trips));

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

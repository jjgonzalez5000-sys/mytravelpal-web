import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'providers.dart';
import 'services/currency_service.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications.dart';
import 'services/review_prompter.dart';
import 'services/trip_foreground.dart';
import 'services/widget_bridge.dart';
import 'storage/app_prefs.dart';
import 'storage/inspiration_storage.dart';
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
  // Required by flutter_foreground_task so the main isolate can
  // receive messages from a background TaskHandler. Even if we don't
  // ship a TaskHandler yet, the plugin's own start/stop bookkeeping
  // uses this port — skipping it makes `startService` throw on hot
  // restart and can wedge the tray notification on some ROMs.
  FlutterForegroundTask.initCommunicationPort();
  // Load locale-specific date symbol data so DateFormat with a
  // non-'en_US' locale (weekday + month names) renders correctly
  // — otherwise the first render throws LocaleDataException on
  // fresh installs when the user boots straight into Spanish.
  await initializeDateFormatting();
  final storage = await TripStorage.open();
  final prefs = await AppPrefs.open();
  final inspirations = await InspirationStorage.open();

  await NotificationService.instance.init();
  await TripForegroundService.instance.init();
  await ReviewPrompter.instance.markLaunched();

  // ignore: unawaited_futures
  storage.list().then((trips) => WidgetBridge.instance.refresh(trips));

  // Warm up currency rates cache so MoneyText renders in the
  // user's currency from the first frame instead of blinking
  // from raw EUR. Fire-and-forget — the widget still handles
  // the "rates not ready yet" case gracefully.
  // ignore: unawaited_futures
  CurrencyService.instance.rates();

  // Build the Riverpod container explicitly so services outside the
  // widget tree (the deep-link handler needs the API's geocode for
  // parsing Google Maps shares) can `read` providers on demand.
  final container = ProviderContainer(
    overrides: [
      tripStorageProvider.overrideWithValue(storage),
      appPrefsProvider.overrideWithValue(prefs),
      inspirationStorageProvider.overrideWithValue(inspirations),
    ],
  );

  final deepLinks = DeepLinkHandler(
    rootNavigatorKey,
    geocodeResolver: () =>
        container.read(apiClientWithPremiumProvider).geocode,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    deepLinks.start();
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyTravelPalApp(),
    ),
  );
}

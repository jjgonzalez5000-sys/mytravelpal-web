import 'dart:async';

import 'package:flutter/material.dart';
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

  final deepLinks = DeepLinkHandler(rootNavigatorKey);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    deepLinks.start();
  });

  runApp(
    ProviderScope(
      overrides: [
        tripStorageProvider.overrideWithValue(storage),
        appPrefsProvider.overrideWithValue(prefs),
        inspirationStorageProvider.overrideWithValue(inspirations),
      ],
      child: const MyTravelPalApp(),
    ),
  );
}

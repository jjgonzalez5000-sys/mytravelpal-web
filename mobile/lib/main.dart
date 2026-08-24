import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'storage/app_prefs.dart';
import 'storage/trip_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await TripStorage.open();
  final prefs = await AppPrefs.open();

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

// Host-side receiver for screenshots taken by
// `integration_test/screenshots_test.dart`. Writes each PNG to
// `store_assets/play_console/screenshots/<locale>/<name>.png` so
// Play Console upload picks them up directly.
//
// Locale is read from the SCREENSHOTS_LOCALE env var (defaults to
// `es`) — set by the shell wrapper.

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final locale = Platform.environment['SCREENSHOTS_LOCALE'] ?? 'es';
  final outDir = 'store_assets/play_console/screenshots/$locale';
  await Directory(outDir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final path = '$outDir/$name.png';
      await File(path).writeAsBytes(bytes);
      // ignore: avoid_print
      print('  ✓ wrote $path (${bytes.length} bytes)');
      return true;
    },
  );
}

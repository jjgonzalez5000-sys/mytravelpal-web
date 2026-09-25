import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../l10n/app_localizations.dart';
import 'trip_foreground.dart';

/// Runs [work] with an Android foreground service pinned to the
/// process while it's in flight. Reuses [TripForegroundService]
/// (channel `trip_active_v1`) so the app only ever declares one
/// notification channel.
///
/// Purpose: keep `/plan` HTTP requests alive when the driver
/// backgrounds the app during the 5-15 s planning wait. Without
/// a foreground service, Doze / OEM app-standby (Xiaomi, Samsung)
/// aborts the socket, and the user comes back to "Conexión
/// fallida". With it, the process stays in the "foreground
/// service" tier the OS won't reclaim except under memory pressure,
/// AND the ongoing notification tells the user their plan is still
/// being built.
///
/// If a service is already running (e.g. the Companion drive is
/// active and the user replans mid-drive), we do NOT stop it in
/// the `finally` — we only own tear-down when we're the ones who
/// started it. The notification body is updated in either case so
/// the tray reflects the current phase.
///
/// On non-Android platforms the call passes straight through to
/// [work] — future-proof for an eventual iOS build.
Future<T> runInForeground<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return work();
  }
  // Grab the localized title synchronously before any await, so
  // we never touch a stale BuildContext across an async gap.
  final title = AppLocalizations.of(context).planLoadingTitle;
  bool wasRunning = false;
  try {
    wasRunning = await FlutterForegroundTask.isRunningService;
    if (!wasRunning) {
      await TripForegroundService.instance.start(title: title, body: label);
    } else {
      await TripForegroundService.instance
          .updateNotification(title: title, body: label);
    }
  } catch (e, st) {
    // Never let a foreground-service hiccup abort the actual plan
    // request — the /plan call must still fire even if the tray
    // notification can't be shown (e.g. user permanently denied
    // POST_NOTIFICATIONS, or the OEM ROM kill-listed the service).
    debugPrint('runInForeground: start/update failed: $e\n$st');
  }
  try {
    return await work();
  } finally {
    if (!wasRunning) {
      try {
        await TripForegroundService.instance.stop();
      } catch (e) {
        debugPrint('runInForeground: stop failed: $e');
      }
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Owns the Android foreground service that keeps the trip
/// dashboard alive when the user switches to Google Maps for
/// turn-by-turn (a driver's most common context).
///
/// Without the foreground service, MyTravelPal gets OOM-killed a few
/// seconds after backgrounding on most Xiaomi/Samsung ROMs, wiping
/// the trip session and cheaper-fuel alerts. With it, the process is
/// pinned to the "foreground service" tier the OS won't reclaim
/// unless memory is critically low.
///
/// This wrapper handles init (once, at app boot) and start/stop
/// tied to the dashboard's lifecycle. Actual GPS tracking + alerts
/// still live in the main isolate — this class doesn't move work
/// to a background isolate (that's Phase 4b in the roadmap). What
/// it DOES guarantee is that the main isolate isn't killed while
/// the trip is active.
///
/// On non-Android (web, iOS-before-we-integrate-CarPlay), every
/// method is a silent no-op.
class TripForegroundService {
  TripForegroundService._();
  static final instance = TripForegroundService._();

  bool _inited = false;

  /// Call once at cold start (from main.dart). Idempotent.
  Future<void> init() async {
    if (_inited || !_isAndroid) return;
    _inited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'trip_active_v1',
        channelName: 'Trip in progress',
        channelDescription:
            'Keeps MyTravelPal alive while you drive with Google Maps.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 30 s ping — the OS uses this to decide the service is
        // still "alive" and worth protecting from reclaim. Any
        // finer wastes battery for zero gain.
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> start({
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) return;
    // Android 13+ needs POST_NOTIFICATIONS granted at runtime, or the
    // ongoing FGS notification is created but never rendered — which
    // on Android 12L+ ALSO trips the "ForegroundServiceDidNotStart"
    // watchdog because the system considers the service invisible.
    // Ask through the plugin so it uses the same channel/prompt path
    // as the notification we're about to raise.
    try {
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      debugPrint('TripForegroundService: permission probe failed: $e');
    }
    final result = await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: body,
      notificationButtons: const [
        NotificationButton(id: 'stop_companion', text: 'Detener'),
      ],
    );
    if (result is ServiceRequestFailure) {
      // Common causes: missing <service> in AndroidManifest, missing
      // FOREGROUND_SERVICE_* typed permission for the declared
      // foregroundServiceType, or user permanently denied
      // POST_NOTIFICATIONS. Log so future breakage is visible in
      // `adb logcat` instead of silently no-oping.
      debugPrint(
        'TripForegroundService.start failed: ${result.error}',
      );
    }
  }

  Future<void> updateNotification({
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
    );
    if (result is ServiceRequestFailure) {
      debugPrint(
        'TripForegroundService.updateNotification failed: ${result.error}',
      );
    }
  }

  Future<void> stop() async {
    if (!_isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) {
      debugPrint('TripForegroundService.stop failed: ${result.error}');
    }
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
}

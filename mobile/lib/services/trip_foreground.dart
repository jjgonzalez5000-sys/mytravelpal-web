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
        // No visibility on lock screen — nothing driver-critical
        // shows here beyond "we're alive".
        visibility: NotificationVisibility.VISIBILITY_SECRET,
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
    await FlutterForegroundTask.startService(
      notificationTitle: title,
      notificationText: body,
    );
  }

  Future<void> updateNotification({
    required String title,
    required String body,
  }) async {
    if (!_isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
    );
  }

  Future<void> stop() async {
    if (!_isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications wrapper.
///
/// Only real on iOS/Android — on web/desktop the schedule/cancel calls
/// no-op. Kept as a thin service so the rest of the app doesn't need
/// to guard `kIsWeb` at every call site.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  bool _available = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    if (kIsWeb) return; // web has no local notifications
    try {
      tzdata.initializeTimeZones();
      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinInit = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        ),
      );
      // Android 13+ runtime permission
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // iOS permissions
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      _available = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// Schedule a reminder `minutesBefore` the given local departure.
  /// Returns the notification id (deterministic — bind to `SavedTrip.id`
  /// via `id.hashCode`) or null when nothing was scheduled.
  Future<int?> scheduleDepartureReminder({
    required String tripId,
    required DateTime departureLocal,
    required int minutesBefore,
    required String title,
    required String body,
  }) async {
    if (!_available || minutesBefore <= 0) return null;
    final when = departureLocal.subtract(Duration(minutes: minutesBefore));
    if (when.isBefore(DateTime.now())) return null; // window has passed
    final scheduled = tz.TZDateTime.from(when, tz.local);
    final id = _idFor(tripId);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'departure_reminders', 'Departure reminders',
            channelDescription:
                'Reminders to leave at the recommended time',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return id;
    } catch (e) {
      debugPrint('scheduleDepartureReminder failed: $e');
      return null;
    }
  }

  /// Fire an immediate (non-scheduled) heads-up notification. Used by
  /// the trip dashboard for proactive alerts — "approaching your
  /// lunch stop", "new road closure in 15 km", "you're 20 min late",
  /// "you may have left the route". Deduping is the caller's job (see
  /// `TripAlertsEvaluator._firedIds`); this method just shows.
  Future<void> showTripAlert({
    required String stableId,
    required String title,
    required String body,
  }) async {
    if (!_available) return;
    try {
      await _plugin.show(
        _idFor('trip_alert:$stableId'),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_alerts', 'Trip alerts',
            channelDescription:
                'Live alerts while you\'re on the road: approaching '
                'planned stops, new roadblocks ahead, drift from route.',
            importance: Importance.high,
            priority: Priority.high,
            // Foreground / heads-up but not a sound spam vector.
            playSound: false,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('showTripAlert failed: $e');
    }
  }

  Future<void> cancel(int? notificationId) async {
    if (!_available || notificationId == null) return;
    try {
      await _plugin.cancel(notificationId);
    } catch (e) {
      debugPrint('cancel failed: $e');
    }
  }

  static int _idFor(String tripId) => tripId.hashCode & 0x7fffffff;

  /// Public helper so callers with an already-scoped id (trip alerts,
  /// departure reminders) can produce the same integer the plugin
  /// stores under.
  static int notificationIdFor(String tripId) => _idFor(tripId);
}

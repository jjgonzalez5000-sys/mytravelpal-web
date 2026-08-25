import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart side of the MethodChannel that surfaces trip alerts on the
/// Android Auto head unit.
///
/// We can't use `flutter_local_notifications` for this because that
/// plugin doesn't expose `CarAppExtender`, which is the ONLY way to
/// get Android Auto to render a notification card. So we wrap a
/// native NotificationCompat.Builder + CarAppExtender in
/// [CarNotificationBridge.kt] and call it here.
///
/// On non-Android platforms every call is a silent no-op — the
/// `flutter_local_notifications` fallback in
/// [NotificationService.showTripAlert] still fires on the phone.
class CarNotificationBridge {
  CarNotificationBridge._();
  static final instance = CarNotificationBridge._();

  static const _channel = MethodChannel('mytravelpal/car_notifications');

  Future<void> postAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('postAlert', {
        'id': id, 'title': title, 'body': body,
      });
    } on PlatformException {
      // Missing plugin (running in tests, or old app version) — the
      // phone-side notification path is enough to keep the driver
      // informed even without AA.
    } on MissingPluginException {
      // Same treatment: the plugin isn't wired yet on this build
      // (e.g. running under `flutter test`). Silent no-op.
    }
  }

  Future<void> cancelAlert(int id) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('cancelAlert', {'id': id});
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}


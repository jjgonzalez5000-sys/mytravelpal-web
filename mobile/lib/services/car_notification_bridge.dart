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

  /// Post a notification visible on both the phone and the Android Auto
  /// head unit. When [waypointLat]/[waypointLon] are provided, the
  /// notification includes a "Desviar" (or [actionLabel]) button that
  /// opens Google Maps navigating via that waypoint. If [destLat]/[destLon]
  /// are also provided, Maps is opened with the waypoint as an intermediate
  /// stop and the original destination preserved.
  Future<void> postAlert({
    required int id,
    required String title,
    required String body,
    double? waypointLat,
    double? waypointLon,
    double? destLat,
    double? destLon,
    String? actionLabel,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('postAlert', {
        'id': id,
        'title': title,
        'body': body,
        if (waypointLat != null) 'waypointLat': waypointLat,
        if (waypointLon != null) 'waypointLon': waypointLon,
        if (destLat != null) 'destLat': destLat,
        if (destLon != null) 'destLon': destLon,
        if (actionLabel != null) 'actionLabel': actionLabel,
      });
    } on PlatformException {
      // Missing plugin — phone-side notification path is enough.
    } on MissingPluginException {
      // Running under flutter test — silent no-op.
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


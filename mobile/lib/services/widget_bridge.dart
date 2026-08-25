import 'package:shared_preferences/shared_preferences.dart';

import '../storage/saved_trip.dart';

/// Publishes the "next upcoming trip" summary to SharedPreferences so
/// the native Android home-screen widget can render a countdown
/// without opening the app.
///
/// Keys are read by
/// `android/.../widget/NextTripWidgetProvider.kt`. The plugin
/// `shared_preferences` prefixes every key with `flutter.` on the
/// native side, so the Kotlin reader uses that same prefix.
class WidgetBridge {
  WidgetBridge._();
  static final instance = WidgetBridge._();

  static const _kHasTrip = 'widgetHasTrip';
  static const _kOriginLabel = 'widgetOriginLabel';
  static const _kDestinationLabel = 'widgetDestinationLabel';
  static const _kDepartureMs = 'widgetDepartureMs';
  static const _kSavedTripsCount = 'widgetSavedTripsCount';

  /// Refresh from the current storage state. Passes the earliest
  /// trip whose desired departure is still in the future, or clears
  /// the widget when there's nothing upcoming.
  Future<void> refresh(Iterable<SavedTrip> trips) async {
    final now = DateTime.now();
    final upcoming = trips
        .where((t) => t.desiredDepartureAt.isAfter(now))
        .toList()
      ..sort(
        (a, b) => a.desiredDepartureAt.compareTo(b.desiredDepartureAt),
      );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSavedTripsCount, trips.length);
    if (upcoming.isEmpty) {
      await prefs.setBool(_kHasTrip, false);
      await prefs.remove(_kOriginLabel);
      await prefs.remove(_kDestinationLabel);
      await prefs.remove(_kDepartureMs);
      return;
    }
    final t = upcoming.first;
    await prefs.setBool(_kHasTrip, true);
    await prefs.setString(_kOriginLabel, _shortLabel(t.origin.displayName));
    await prefs.setString(
      _kDestinationLabel, _shortLabel(t.destination.displayName),
    );
    await prefs.setInt(
      _kDepartureMs, t.desiredDepartureAt.millisecondsSinceEpoch,
    );
  }

  /// Nominatim display names come back with the full postal address.
  /// The widget only has room for the first token (usually city).
  String _shortLabel(String full) {
    final parts = full.split(',');
    return parts.isEmpty ? full : parts.first.trim();
  }
}

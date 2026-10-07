import 'dart:math';

/// Sunrise / sunset calculator using the NOAA simplified solar formula.
/// Accurate to ±1-2 minutes for latitudes between 60°S and 60°N.
///
/// Returns times as **minutes from midnight in the device's local time**
/// (i.e. already offset for the timezone the device is set to — matches
/// what we display to the user everywhere else in the app).
class SunCalc {
  const SunCalc._();

  /// Compute [SunTimes] for a given [lat]/[lon] on [date].
  /// [utcOffsetHours] is the UTC offset at the trip location
  /// (e.g. +2 for CEST, +1 for CET). When null, the device's
  /// local offset at [date] is used.
  static SunTimes compute({
    required double lat,
    required double lon,
    required DateTime date,
    double? utcOffsetHours,
  }) {
    final utcOffset = utcOffsetHours ??
        date.timeZoneOffset.inMinutes / 60.0;

    // Day of year (1-based)
    final doy = date.difference(DateTime(date.year)).inDays + 1;

    // Fractional year (radians)
    final gamma = 2 * pi / 365.0 * (doy - 1 + (12.0 - 12) / 24.0);

    // Equation of time (minutes)
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * cos(gamma) -
            0.032077 * sin(gamma) -
            0.014615 * cos(2 * gamma) -
            0.04089 * sin(2 * gamma));

    // Solar declination (radians)
    final decl = 0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);

    final latRad = lat * pi / 180.0;

    // Hour angle at sunrise/sunset (zenith = 90.833° = 90°50')
    final cosHa = (cos(90.833 * pi / 180.0) -
            sin(latRad) * sin(decl)) /
        (cos(latRad) * cos(decl));

    // Check for polar day / polar night
    if (cosHa < -1.0) {
      // Polar day — sun never sets
      return SunTimes(
        sunriseMinutes: 0,
        sunsetMinutes: 1440,
        isPolarDay: true,
        isPolarNight: false,
      );
    }
    if (cosHa > 1.0) {
      // Polar night — sun never rises
      return SunTimes(
        sunriseMinutes: 720,
        sunsetMinutes: 720,
        isPolarDay: false,
        isPolarNight: true,
      );
    }

    final ha = acos(cosHa) * 180.0 / pi; // degrees

    // Sunrise/sunset in UTC minutes from midnight
    final sunriseUtcMin = 720 - 4 * (lon + ha) - eqTime;
    final sunsetUtcMin  = 720 - 4 * (lon - ha) - eqTime;

    // Convert to local time (minutes from midnight)
    int toLocal(double utcMin) =>
        (utcMin + utcOffset * 60).round().clamp(0, 1440);

    return SunTimes(
      sunriseMinutes: toLocal(sunriseUtcMin),
      sunsetMinutes: toLocal(sunsetUtcMin),
      isPolarDay: false,
      isPolarNight: false,
    );
  }
}

class SunTimes {
  const SunTimes({
    required this.sunriseMinutes,
    required this.sunsetMinutes,
    required this.isPolarDay,
    required this.isPolarNight,
  });

  /// Minutes from midnight (local) when the sun rises.
  final int sunriseMinutes;

  /// Minutes from midnight (local) when the sun sets.
  final int sunsetMinutes;

  final bool isPolarDay;
  final bool isPolarNight;
}

import 'dart:math' as math;

import '../api/models.dart';

/// Hotels are offered for a night when they are within this distance of
/// that night's sleep point. Shared by the day cards and by the check
/// below so "still fits" means the same thing in both places.
const double kMaxHotelKmFromSleep = 150.0;

enum SelectionKind { hotel, restaurant, fuel, mealStop, sleepStop }

/// A pick the driver made that would not survive a replan.
class LostSelection {
  const LostSelection({required this.kind, required this.name, this.day});

  final SelectionKind kind;
  final String name;

  /// Night / day index, for hotels.
  final int? day;
}

String _coord4(double lat, double lon) =>
    '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

/// Key a fuel pick is stored under (`fuel:name:lat,lon`). Null when the
/// station has no coordinate and so cannot have been picked.
String? fuelPickKey(FuelPrice p) {
  final c = p.coordinate;
  if (c == null) return null;
  return 'fuel:${p.stationName}:${_coord4(c.lat, c.lon)}';
}

String restaurantPickKey(Restaurant r) =>
    'restaurant:${r.name}:${_coord4(r.coordinate.lat, r.coordinate.lon)}';

/// True when [h] is the hotel stored as [name] at [lat],[lon]: the same
/// name, or within ~100 m (a re-plan may rename or re-order a listing).
bool hotelMatches(Hotel h, String name, double lat, double lon) =>
    h.name == name ||
    ((h.coordinate.lat - lat).abs() < 0.001 &&
        (h.coordinate.lon - lon).abs() < 0.001);

double haversineKm(LatLon a, LatLon b) {
  const r = 6371.0;
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLon = (b.lon - a.lon) * math.pi / 180;
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.lat * math.pi / 180) *
          math.cos(b.lat * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
}

/// `lat4,lon4` suffix of a `fuel:` / `restaurant:` key.
String _keySuffix(String key) => key.substring(key.lastIndexOf(':') + 1);

/// Name part of a `fuel:` / `restaurant:` key.
String _keyName(String key, String prefix) =>
    key.substring(prefix.length, key.lastIndexOf(':'));

/// Which of the driver's [selections] (the blob `_currentSelections`
/// produces) would NOT survive on [fresh], the plan that a replan just
/// returned.
///
/// A pick survives when the app can find it again on the new plan:
///  * fuel / restaurant: the same station / place is still listed;
///  * hotel: it is still listed AND still within [kMaxHotelKmFromSleep] of
///    that night's sleep point (the stretch moved, so the night may have
///    moved with it), and that night still exists.
///
/// [routedThrough] holds `lat4,lon4` strings of stops the new route is
/// forced through (request waypoints). Those are not lost: the route
/// passes through them whether or not they are still listed.
List<LostSelection> lostSelections(
  Map<String, dynamic>? selections,
  TripPlanResponse fresh, {
  Set<String> routedThrough = const {},
}) {
  if (selections == null) return const [];
  final lost = <LostSelection>[];

  final fuelKeys = selections['picked_fuel_keys'];
  if (fuelKeys is List) {
    for (final k in fuelKeys.whereType<String>()) {
      if (routedThrough.contains(_keySuffix(k))) continue;
      final found = fresh.fuelPrices.any((p) => fuelPickKey(p) == k);
      if (!found) {
        lost.add(LostSelection(
            kind: SelectionKind.fuel, name: _keyName(k, 'fuel:')));
      }
    }
  }

  final restKeys = selections['picked_restaurant_keys'];
  if (restKeys is List) {
    for (final k in restKeys.whereType<String>()) {
      if (routedThrough.contains(_keySuffix(k))) continue;
      final found = fresh.restaurants.any((r) => restaurantPickKey(r) == k);
      if (!found) {
        lost.add(LostSelection(
            kind: SelectionKind.restaurant,
            name: _keyName(k, 'restaurant:')));
      }
    }
  }

  final hotelsByDay = selections['picked_hotel_keys_by_day'];
  if (hotelsByDay is Map) {
    hotelsByDay.forEach((k, v) {
      final day = int.tryParse(k.toString());
      if (day == null || v is! Map) return;
      final name = v['name'] as String?;
      final lat = (v['lat'] as num?)?.toDouble();
      final lon = (v['lon'] as num?)?.toDouble();
      if (name == null || lat == null || lon == null) return;

      Hotel? hotel;
      for (final h in fresh.hotels) {
        if (hotelMatches(h, name, lat, lon)) {
          hotel = h;
          break;
        }
      }
      var fits = hotel != null;
      if (hotel != null) {
        final d = fresh.days.where((x) => x.dayIndex == day).firstOrNull;
        if (d == null) {
          fits = false; // that night no longer exists
        } else if (d.sleepCoord != null &&
            haversineKm(d.sleepCoord!, hotel.coordinate) >
                kMaxHotelKmFromSleep) {
          fits = false; // the night moved away from this hotel
        }
      }
      if (!fits) {
        lost.add(LostSelection(
            kind: SelectionKind.hotel, name: name, day: day));
      }
    });
  }

  return lost;
}

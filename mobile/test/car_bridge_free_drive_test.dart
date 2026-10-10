import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/services/car_bridge.dart';
import 'package:mytravelpal/services/trip_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('free drive drops route figures and keeps speed + position', () async {
    SharedPreferences.setMockInitialValues({});
    await CarBridge.instance.updateTrip(
      progress: TripProgress(
        progressKm: 10,
        totalKm: 1670,
        remainingKm: 1660,
        offRouteMeters: 0,
        currentSpeedKmh: 90,
        etaToDestination: DateTime.now().add(const Duration(hours: 20)),
      ),
      me: const LatLon(lat: 47.0, lon: 8.0),
      destination: const LatLon(lat: 40.4, lon: -3.7),
    );
    await CarBridge.instance.updateFreeDrive(
      speedKmh: 87.4,
      me: const LatLon(lat: 46.5, lon: 7.5),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('flutter.remainingKm') ||
        prefs.containsKey('remainingKm'), isFalse);
    expect(prefs.getKeys().any((k) => k.contains('totalKm')), isFalse);
    expect(prefs.getKeys().any((k) => k.contains('destinationEta')), isFalse);
    expect(prefs.getInt('speedKmh'), 87);
    expect(prefs.getBool('activeTrip'), isTrue);
  });
}

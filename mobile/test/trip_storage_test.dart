import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/storage/saved_trip.dart';
import 'package:mytravelpal/storage/trip_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedTrip _trip(String id, {DateTime? savedAt}) => SavedTrip(
      id: id,
      origin: const GeocodeResult(
        displayName: 'Paris, France',
        coordinate: LatLon(lat: 48.8566, lon: 2.3522),
        country: Country.fr,
      ),
      destination: const GeocodeResult(
        displayName: 'Madrid, Spain',
        coordinate: LatLon(lat: 40.4168, lon: -3.7038),
        country: Country.es,
      ),
      desiredDepartureAt: DateTime.utc(2026, 8, 24, 8),
      savedAt: savedAt ?? DateTime.utc(2026, 8, 20, 12),
      distanceKm: 1316.1,
      recommendedDepartureAt: DateTime.utc(2026, 8, 24, 5, 30),
      recommendedMinutes: 872.8,
      countriesCrossed: const [Country.fr, Country.es],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('list returns empty when nothing has been saved', () async {
    final storage = await TripStorage.open();
    expect(await storage.list(), isEmpty);
  });

  test('save then list roundtrips a trip', () async {
    final storage = await TripStorage.open();
    final t = _trip('abc');
    await storage.save(t);

    final loaded = await storage.list();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'abc');
    expect(loaded.single.origin.country, Country.fr);
    expect(loaded.single.destination.displayName, 'Madrid, Spain');
    expect(loaded.single.countriesCrossed, [Country.fr, Country.es]);
    expect(loaded.single.recommendedMinutes, 872.8);
  });

  test('saving the same id twice keeps only the newer copy', () async {
    final storage = await TripStorage.open();
    await storage.save(_trip('abc', savedAt: DateTime.utc(2026, 8, 1)));
    await storage.save(_trip('abc', savedAt: DateTime.utc(2026, 8, 20)));
    final loaded = await storage.list();
    expect(loaded, hasLength(1));
    expect(loaded.single.savedAt, DateTime.utc(2026, 8, 20));
  });

  test('list returns newest-saved first', () async {
    final storage = await TripStorage.open();
    await storage.save(_trip('old'));
    await storage.save(_trip('new'));
    final loaded = await storage.list();
    expect(loaded.map((t) => t.id).toList(), ['new', 'old']);
  });

  test('delete removes only the matching trip', () async {
    final storage = await TripStorage.open();
    await storage.save(_trip('a'));
    await storage.save(_trip('b'));
    await storage.delete('a');
    final loaded = await storage.list();
    expect(loaded.map((t) => t.id).toList(), ['b']);
  });

  test('clear wipes storage', () async {
    final storage = await TripStorage.open();
    await storage.save(_trip('a'));
    await storage.clear();
    expect(await storage.list(), isEmpty);
  });

  test('SavedTrip JSON roundtrip preserves all fields', () {
    final t = _trip('abc');
    final decoded = SavedTrip.fromJson(t.toJson());
    expect(decoded.id, t.id);
    expect(decoded.origin.displayName, t.origin.displayName);
    expect(decoded.origin.coordinate, t.origin.coordinate);
    expect(decoded.destination.country, t.destination.country);
    expect(decoded.desiredDepartureAt, t.desiredDepartureAt);
    expect(decoded.savedAt, t.savedAt);
    expect(decoded.distanceKm, t.distanceKm);
    expect(decoded.recommendedDepartureAt, t.recommendedDepartureAt);
    expect(decoded.recommendedMinutes, t.recommendedMinutes);
    expect(decoded.countriesCrossed, t.countriesCrossed);
  });
}

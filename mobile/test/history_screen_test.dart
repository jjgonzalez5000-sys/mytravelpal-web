import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/providers.dart';
import 'package:mytravelpal/screens/history_screen.dart';
import 'package:mytravelpal/storage/saved_trip.dart';
import 'package:mytravelpal/storage/trip_storage.dart';
import 'package:mytravelpal/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TripStorage> _seed(List<SavedTrip> trips) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final storage = await TripStorage.open();
  for (final t in trips) {
    await storage.save(t);
  }
  return storage;
}

Widget _appHost(TripStorage storage) => ProviderScope(
      overrides: [tripStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const HistoryScreen(),
      ),
    );

SavedTrip _sampleTrip(String id) => SavedTrip(
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
      savedAt: DateTime.utc(2026, 8, 20, 12),
      distanceKm: 1316.1,
      recommendedDepartureAt: DateTime.utc(2026, 8, 24, 5, 30),
      recommendedMinutes: 872.8,
      countriesCrossed: const [Country.fr, Country.es],
    );

void main() {
  testWidgets('empty state renders when no trips are saved',
      (tester) async {
    final storage = await _seed(const []);
    await tester.pumpWidget(_appHost(storage));
    await tester.pumpAndSettle();
    expect(find.text('No saved trips yet'), findsOneWidget);
  });

  testWidgets('renders saved trips as cards', (tester) async {
    final storage = await _seed([_sampleTrip('abc')]);
    await tester.pumpWidget(_appHost(storage));
    await tester.pumpAndSettle();
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Madrid'), findsOneWidget);
    expect(find.textContaining('1316 km'), findsOneWidget);
  });

  testWidgets('delete button removes the card', (tester) async {
    final storage = await _seed([_sampleTrip('abc')]);
    await tester.pumpWidget(_appHost(storage));
    await tester.pumpAndSettle();
    expect(find.text('Madrid'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Madrid'), findsNothing);
    expect(find.text('No saved trips yet'), findsOneWidget);
  });
}

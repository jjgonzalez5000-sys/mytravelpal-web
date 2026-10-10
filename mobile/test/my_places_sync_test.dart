import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytravelpal/api/api_client.dart';
import 'package:mytravelpal/api/models.dart';
import 'package:mytravelpal/domain/my_place.dart';
import 'package:mytravelpal/providers.dart';
import 'package:mytravelpal/storage/app_prefs.dart';

class _SlowApi implements ApiClient {
  _SlowApi(this.reply);
  final Completer<Map<String, dynamic>?> reply;
  @override
  Future<Map<String, dynamic>?> fetchProfile() => reply.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MyPlace _place(String id) => MyPlace(
      id: id,
      name: 'Place $id',
      coordinate: const LatLon(lat: 40, lon: -3),
      createdAt: DateTime(2026, 10, 10),
    );

void main() {
  test('a place added while the profile is being fetched survives the sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.open();
    await prefs.setMyPlaces([_place('old')]);

    final reply = Completer<Map<String, dynamic>?>();
    final notifier = TripProfileNotifier(prefs)..api = _SlowApi(reply) as dynamic;
    final sync = notifier.syncFromServer();

    // The driver saves a new place before the server answers.
    await prefs.setMyPlaces([...prefs.myPlaces, _place('new')]);

    reply.complete({
      '_my_places': [_place('old').toJson()],
    });
    await sync;

    expect(prefs.myPlaces.map((p) => p.id), containsAll(['old', 'new']));
  });

  test('an empty server list still clears places the driver already had',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.open();
    await prefs.setMyPlaces([_place('old')]);

    final notifier = TripProfileNotifier(prefs)
      ..api = _SlowApi(Completer<Map<String, dynamic>?>()
        ..complete({'_my_places': <dynamic>[]})) as dynamic;
    await notifier.syncFromServer();

    expect(prefs.myPlaces, isEmpty);
  });
}

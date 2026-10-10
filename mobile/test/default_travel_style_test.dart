import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/domain/travel_style_presets.dart';
import 'package:mytravelpal/domain/trip_profile.dart';

void main() {
  test('a fresh profile is the Balanced travel style', () {
    expect(
      TravelStylePreset.matching(const TripProfile()),
      TravelStylePreset.balanced,
    );
  });

  test('applying Balanced to a customised profile restores the preset', () {
    final custom = const TripProfile().copyWith(dailyDrivingCapHours: 13);
    expect(TravelStylePreset.matching(custom), isNull);
    expect(
      TravelStylePreset.matching(TravelStylePreset.balanced.apply(custom)),
      TravelStylePreset.balanced,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mytravelpal/widgets/trip_quality_score.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const lightSurface = Color(0xFFFAFAF7);
  const darkSurface = Color(0xFF14151F);

  test('light-theme tier colours are legible as text on the light surface', () {
    for (final tier in [0, 1, 2]) {
      expect(
        _contrast(qualityTierColor(tier, false), lightSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'tier $tier',
      );
    }
  });

  test('dark-theme tier colours stay legible on a dark surface', () {
    for (final tier in [0, 1, 2]) {
      expect(
        _contrast(qualityTierColor(tier, true), darkSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'tier $tier',
      );
    }
  });
}

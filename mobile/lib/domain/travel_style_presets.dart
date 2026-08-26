import 'package:flutter/material.dart';

import 'trip_profile.dart';

/// One-tap templates for the six travel-style axes.
///
/// Applying a preset overwrites the six style fields but preserves
/// unrelated ones (travellers, vehicle, meal times). Users can still
/// tweak individual axes afterwards via the Advanced section of the
/// profile screen — there's no lock-in.
enum TravelStylePreset {
  direct(
    icon: Icons.timer_outlined,
    pace: TravelPace.push,
    overnight: OvernightPolicy.never,
    dailyCap: 12,
    breakStyle: BreakStyle.minimal,
  ),
  balanced(
    icon: Icons.explore_outlined,
    pace: TravelPace.steady,
    overnight: OvernightPolicy.ifNeeded,
    dailyCap: 8,
    breakStyle: BreakStyle.scenic,
  ),
  slow(
    icon: Icons.spa_outlined,
    pace: TravelPace.savour,
    overnight: OvernightPolicy.alwaysIfLong,
    // Lowered from 6 h → 4 h (2026-08-25) after testers said
    // 6 h × ~90 km/h averaged too many kilometres per day for
    // "relajado". At 4 h the plan tops out around 350-400 km
    // per day — closer to what a slow-travel driver actually
    // wants to eat.
    dailyCap: 4,
    breakStyle: BreakStyle.foodie,
  );

  const TravelStylePreset({
    required this.icon,
    required this.pace,
    required this.overnight,
    required this.dailyCap,
    required this.breakStyle,
  });

  final IconData icon;
  final TravelPace pace;
  final OvernightPolicy overnight;
  final int dailyCap;
  final BreakStyle breakStyle;

  TripProfile apply(TripProfile base) => base.copyWith(
        travelPace: pace,
        overnightPolicy: overnight,
        dailyDrivingCapHours: dailyCap,
        breakStyle: breakStyle,
      );

  /// Returns the preset whose four axes match `profile` exactly, or
  /// null if the profile has been customised beyond any preset. Used
  /// by the AppBar chip to show "Balanced" when the user hasn't
  /// diverged from the defaults, and "Custom" otherwise.
  static TravelStylePreset? matching(TripProfile profile) {
    for (final p in values) {
      if (p.pace == profile.travelPace &&
          p.overnight == profile.overnightPolicy &&
          p.dailyCap == profile.dailyDrivingCapHours &&
          p.breakStyle == profile.breakStyle) {
        return p;
      }
    }
    return null;
  }
}

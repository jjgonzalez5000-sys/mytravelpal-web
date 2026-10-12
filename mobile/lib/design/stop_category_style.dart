import 'package:flutter/material.dart';

import '../domain/my_place.dart';

/// Icon and colour of a stop type, shared by the filter chips, the map pins
/// and the suggestion cards so one type always looks the same.
class StopCategoryStyle {
  const StopCategoryStyle({required this.icon, required this.color});

  final IconData icon;

  /// Background of a pin; white on top of it reads at 4.5:1 or better.
  final Color color;

  /// Same hue for text and icons that sit on a surface: [color] on light
  /// surfaces, a lightened [color] on dark ones.
  Color onSurface(Brightness brightness) => brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.45)!
      : color;
}

StopCategoryStyle stopCategoryStyle(MyPlaceCategory c) => switch (c) {
      MyPlaceCategory.food => const StopCategoryStyle(
          icon: Icons.restaurant_outlined, color: Color(0xFFC2410C)),
      MyPlaceCategory.viewpoint => const StopCategoryStyle(
          icon: Icons.landscape_outlined, color: Color(0xFF1565C0)),
      MyPlaceCategory.culture => const StopCategoryStyle(
          icon: Icons.museum_outlined, color: Color(0xFF7B1FA2)),
      MyPlaceCategory.history => const StopCategoryStyle(
          icon: Icons.castle_outlined, color: Color(0xFF6D4C41)),
      MyPlaceCategory.nature => const StopCategoryStyle(
          icon: Icons.park_outlined, color: Color(0xFF4D7C0F)),
      MyPlaceCategory.beach => const StopCategoryStyle(
          icon: Icons.beach_access_outlined, color: Color(0xFF00758A)),
      MyPlaceCategory.kids => const StopCategoryStyle(
          icon: Icons.child_care_outlined, color: Color(0xFFC2185B)),
      MyPlaceCategory.shopping => const StopCategoryStyle(
          icon: Icons.shopping_bag_outlined, color: Color(0xFFA15C00)),
      MyPlaceCategory.other => const StopCategoryStyle(
          icon: Icons.place_outlined, color: Color(0xFF546E7A)),
    };

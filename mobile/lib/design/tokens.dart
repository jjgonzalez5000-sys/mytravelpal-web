import 'package:flutter/material.dart';

/// Design tokens for MyTravelPal — "Nordic / Airbnb" system.
///
/// Everything visual should reference these constants rather than inline
/// magic values. When the brand evolves, we change tokens here and every
/// screen picks it up.
class Tokens {
  Tokens._();

  // -- Spacing (8pt grid) ---------------------------------------------------

  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;

  // -- Radii ----------------------------------------------------------------

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // -- Elevation shadows (soft, warm) --------------------------------------

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A171818),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x14171818),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1A171818),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  // -- Motion ---------------------------------------------------------------

  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionBase = Duration(milliseconds: 240);
  static const Duration motionSlow = Duration(milliseconds: 420);
  static const Curve curveOut = Curves.easeOutCubic;
}

/// Nordic warm palette. Forest green primary, warm neutral surfaces, a
/// subtle terracotta accent for chips and highlights. Tuned for
/// accessibility — all pairings meet WCAG AA on the surfaces they apply to.
class BrandColors {
  BrandColors._();

  // Primary — deep forest green
  static const Color forest = Color(0xFF2F5D50);
  static const Color forestOn = Color(0xFFFFFFFF);
  static const Color forestContainer = Color(0xFFE0EBE4);
  static const Color forestContainerOn = Color(0xFF102820);

  // Secondary — muted sage
  static const Color sage = Color(0xFF7A9E85);
  static const Color sageOn = Color(0xFF0F1E15);
  static const Color sageContainer = Color(0xFFE8EFE9);
  static const Color sageContainerOn = Color(0xFF1F3628);

  // Tertiary / accent — warm terracotta
  static const Color terracotta = Color(0xFFC77747);
  static const Color terracottaOn = Color(0xFFFFFFFF);
  static const Color terracottaContainer = Color(0xFFF7E1D4);
  static const Color terracottaContainerOn = Color(0xFF3B1C0A);

  // Warm neutrals — light
  static const Color surface = Color(0xFFFAFAF7);
  static const Color surfaceLow = Color(0xFFF4F2ED);
  static const Color surfaceHigh = Color(0xFFEEEBE3);
  static const Color surfaceContainer = Color(0xFFF1EFE9);
  static const Color surfaceContainerHigh = Color(0xFFE9E6DE);
  static const Color onSurface = Color(0xFF1E1D1A);
  static const Color onSurfaceMuted = Color(0xFF57544D);
  static const Color outline = Color(0xFFC9C5BE);
  static const Color outlineSoft = Color(0xFFE1DED6);

  // Warm neutrals — dark
  static const Color surfaceDark = Color(0xFF16181B);
  static const Color surfaceDarkLow = Color(0xFF13161A);
  static const Color surfaceDarkHigh = Color(0xFF1E2226);
  static const Color surfaceDarkContainer = Color(0xFF1B1E22);
  static const Color surfaceDarkContainerHigh = Color(0xFF262A2E);
  static const Color onSurfaceDark = Color(0xFFEFEDE7);
  static const Color onSurfaceDarkMuted = Color(0xFFB8B5AE);
  static const Color outlineDark = Color(0xFF3E4247);
  static const Color outlineDarkSoft = Color(0xFF2A2E32);

  // Semantic
  static const Color danger = Color(0xFFB94A48);
  static const Color dangerContainer = Color(0xFFF6D9D6);
  static const Color warn = Color(0xFFB27A26);
  static const Color warnContainer = Color(0xFFF3E2C6);
  static const Color info = Color(0xFF3E6D8C);
  static const Color infoContainer = Color(0xFFD8E5EE);
}

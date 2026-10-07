import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'storage/app_prefs.dart';

/// User-selectable colour preset. Each maps to a seed colour we
/// feed to [ColorScheme.fromSeed] so light + dark stay balanced.
/// `forest` is the historical hand-built palette and stays as the
/// default so existing users don't see a jarring change on
/// upgrade.
enum ThemePreset {
  forest, // original green-based palette
  sunset, // coral → magenta, matches the v4 icon gradient
  ocean,  // sea blue → teal
  ;

  String get slug => name;

  static ThemePreset fromSlug(String? s) => switch (s) {
        'sunset' => ThemePreset.sunset,
        'ocean' => ThemePreset.ocean,
        _ => ThemePreset.forest,
      };

  /// Seed colour used by [ColorScheme.fromSeed]. Picked to sit at
  /// ~S:0.7 L:0.5 in HSL so the generated palette has room to
  /// breathe in both light and dark modes.
  Color get seed => switch (this) {
        ThemePreset.forest => const Color(0xFF2F6B4E),
        ThemePreset.sunset => const Color(0xFFF44F72),
        ThemePreset.ocean  => const Color(0xFF1E7BC4),
      };
}

/// Nordic-flavoured Material 3 theme. Light + dark share the same primary,
/// swap neutral surfaces. Typography is Inter across the board — geometric,
/// warm at large sizes, legible at small sizes.
class AppTheme {
  AppTheme._();

  /// Legacy entry points — kept for tests and any leftover call
  /// sites. Prefer [buildLight] / [buildDark] with a preset.
  static ThemeData light() => _build(_lightScheme, brightness: Brightness.light);
  static ThemeData dark() => _build(_darkColorScheme(), brightness: Brightness.dark);

  /// Build a light-mode [ThemeData] for the requested [preset].
  /// When [dynamicScheme] is non-null (Material You on Android
  /// 12+), it wins over the preset seed.
  static ThemeData buildLight({
    required ThemePreset preset,
    ColorScheme? dynamicScheme,
    UiDensity density = UiDensity.comfortable,
  }) {
    if (preset == ThemePreset.forest && dynamicScheme == null) {
      return _build(_lightScheme,
          brightness: Brightness.light, density: density);
    }
    final scheme = dynamicScheme?.harmonized() ??
        ColorScheme.fromSeed(
          seedColor: preset.seed,
          brightness: Brightness.light,
        );
    return _build(scheme, brightness: Brightness.light, density: density);
  }

  /// Build a dark-mode [ThemeData] for the requested [preset].
  /// [oled] forces surfaces to pure black so OLED panels can gain
  /// battery + contrast without needing a whole separate theme.
  static ThemeData buildDark({
    required ThemePreset preset,
    ColorScheme? dynamicScheme,
    bool oled = false,
    UiDensity density = UiDensity.comfortable,
  }) {
    ColorScheme scheme;
    if (dynamicScheme != null) {
      scheme = dynamicScheme.harmonized();
    } else if (preset == ThemePreset.forest) {
      // Brand-tuned dark palette matches the compass-M logo (deep
      // indigo primary, warm amber tertiary, muted teal secondary).
      // Users on the historical Forest preset get the polished
      // hand-picked scheme instead of Material's generated one.
      scheme = _darkColorScheme();
    } else {
      scheme = ColorScheme.fromSeed(
        seedColor: preset.seed,
        brightness: Brightness.dark,
      );
    }
    if (oled) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF060606),
        surfaceContainer: const Color(0xFF0A0A0A),
        surfaceContainerHigh: const Color(0xFF101010),
        surfaceContainerHighest: const Color(0xFF161616),
      );
    }
    return _build(scheme, brightness: Brightness.dark, density: density);
  }

  // -- Color schemes -------------------------------------------------------

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.forest,
    onPrimary: BrandColors.forestOn,
    primaryContainer: BrandColors.forestContainer,
    onPrimaryContainer: BrandColors.forestContainerOn,
    secondary: BrandColors.sage,
    onSecondary: BrandColors.sageOn,
    secondaryContainer: BrandColors.sageContainer,
    onSecondaryContainer: BrandColors.sageContainerOn,
    tertiary: BrandColors.terracotta,
    onTertiary: BrandColors.terracottaOn,
    tertiaryContainer: BrandColors.terracottaContainer,
    onTertiaryContainer: BrandColors.terracottaContainerOn,
    error: BrandColors.danger,
    onError: Colors.white,
    errorContainer: BrandColors.dangerContainer,
    onErrorContainer: Color(0xFF410002),
    surface: BrandColors.surface,
    onSurface: BrandColors.onSurface,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: BrandColors.surfaceLow,
    surfaceContainer: BrandColors.surfaceContainer,
    surfaceContainerHigh: BrandColors.surfaceContainerHigh,
    surfaceContainerHighest: BrandColors.surfaceHigh,
    onSurfaceVariant: BrandColors.onSurfaceMuted,
    outline: BrandColors.outline,
    outlineVariant: BrandColors.outlineSoft,
    inverseSurface: Color(0xFF2A2926),
    onInverseSurface: BrandColors.surface,
    inversePrimary: Color(0xFF9BC2B0),
    shadow: Colors.black,
    scrim: Colors.black,
  );

  /// Brand-tuned dark palette. Hand-picked to match the compass-M
  /// logo — deep indigo primary, muted teal secondary, warm amber
  /// tertiary for CTAs. Contrast ratios on text pairs verified
  /// against WCAG AA (≥4.5:1 for body text).
  static ColorScheme _darkColorScheme() => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF7C8FF7),
        onPrimary: Color(0xFF0F1633),
        primaryContainer: Color(0xFF2A2D5B),
        onPrimaryContainer: Color(0xFFDFE1FF),
        secondary: Color(0xFF7ECCC0),
        onSecondary: Color(0xFF0A2A28),
        secondaryContainer: Color(0xFF274543),
        onSecondaryContainer: Color(0xFFB4E9DE),
        tertiary: Color(0xFFF5B678),
        onTertiary: Color(0xFF3A2004),
        tertiaryContainer: Color(0xFF5C3510),
        onTertiaryContainer: Color(0xFFFFDBB0),
        error: Color(0xFFFF9B9B),
        onError: Color(0xFF420000),
        errorContainer: Color(0xFF8C1D18),
        onErrorContainer: Color(0xFFFFDAD5),
        surface: Color(0xFF12142B),
        onSurface: Color(0xFFE4E1F1),
        surfaceContainerLowest: Color(0xFF0B0D22),
        surfaceContainerLow: Color(0xFF161832),
        surfaceContainer: Color(0xFF1B1D3A),
        surfaceContainerHigh: Color(0xFF242749),
        surfaceContainerHighest: Color(0xFF2E325A),
        onSurfaceVariant: Color(0xFFC4C2D6),
        outline: Color(0xFF5A5E80),
        outlineVariant: Color(0xFF3B3E60),
        inverseSurface: Color(0xFFE4E1F1),
        onInverseSurface: Color(0xFF12142B),
        inversePrimary: Color(0xFF3B4CB5),
        shadow: Colors.black,
        scrim: Colors.black,
      );

  // -- Theme builder --------------------------------------------------------

  static ThemeData _build(
    ColorScheme scheme, {
    required Brightness brightness,
    UiDensity density = UiDensity.comfortable,
  }) {
    final isCompact = density == UiDensity.compact;
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: isCompact
          ? VisualDensity.compact
          : VisualDensity.comfortable,
    );

    final textTheme = _buildTextTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
      compact: isCompact,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        // Compact mode leaves a small vertical breathing room so
        // stacked cards don't visually collide even without the
        // outline. Comfortable keeps the historical zero margin —
        // parent widgets already inject their own gap.
        margin: isCompact
            ? const EdgeInsets.symmetric(vertical: 4)
            : EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        labelPadding: isCompact
            ? const EdgeInsets.symmetric(horizontal: 4)
            : null,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? Tokens.space8 : Tokens.space12,
          vertical: isCompact ? 2 : Tokens.space4,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.space16,
          vertical: Tokens.space16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space24,
            vertical: Tokens.space16,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space20,
            vertical: Tokens.space16,
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space12,
            vertical: Tokens.space8,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStateProperty.all(scheme.outlineVariant),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHigh,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  // -- Typography (Manrope headings + Inter body) --------------------------
  //
  // Manrope carries the display/headline/title/label ranges — its
  // slightly rounder terminals feel warmer than Inter at large sizes
  // while its geometric skeleton keeps eyebrows crisp. Body copy
  // stays on Inter because it was tuned specifically for legibility
  // at 12–16 pt on screen and small caption sizes still need every
  // last hint of x-height that Inter gives us.

  static TextTheme _buildTextTheme(
    Color body,
    Color muted, {
    bool compact = false,
  }) {
    // Fonts are bundled as assets (see pubspec.yaml). We build the
    // text themes from Flutter's built-in Material 3 typography and
    // re-anchor fontFamily to the bundled Manrope/Inter — going
    // through GoogleFonts.*TextTheme() would still trigger its asset
    // lookup for `Manrope-Regular.ttf` (static filename convention)
    // which our bundled variable font doesn't satisfy, throwing the
    // "font not found in assets" exception Sentry surfaced right
    // after the fonts.gstatic.com fetch was disabled on 2026-09-29.
    final baseM3 = Typography.material2021().englishLike;
    final heading = baseM3.apply(fontFamily: 'Manrope');
    final text = baseM3.apply(fontFamily: 'Inter');
    // Body/label copy scales by 0.94, titles/headlineSmall by 0.90
    // in compact mode. The bigger displays keep their weight so
    // hero moments still hit; the middle titles shrink hardest
    // because that's where card headers eat vertical space.
    final bodyScale = compact ? 0.94 : 1.0;
    final titleScale = compact ? 0.90 : 1.0;
    return TextTheme(
      displayLarge: heading.displayLarge?.copyWith(
        fontSize: 40, height: 1.15, fontWeight: FontWeight.w600,
        letterSpacing: -0.5, color: body,
      ),
      displayMedium: heading.displayMedium?.copyWith(
        fontSize: 32, height: 1.2, fontWeight: FontWeight.w600,
        letterSpacing: -0.3, color: body,
      ),
      displaySmall: heading.displaySmall?.copyWith(
        fontSize: 26, height: 1.25, fontWeight: FontWeight.w600, color: body,
      ),
      headlineLarge: heading.headlineLarge?.copyWith(
        fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, color: body,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        fontSize: 20, height: 1.35, fontWeight: FontWeight.w600, color: body,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        fontSize: 18 * titleScale,
        height: 1.35, fontWeight: FontWeight.w600, color: body,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        fontSize: 18 * titleScale,
        height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      titleMedium: heading.titleMedium?.copyWith(
        fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      titleSmall: heading.titleSmall?.copyWith(
        fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      bodyLarge: text.bodyLarge?.copyWith(
        fontSize: 16 * bodyScale, height: 1.5, color: body,
      ),
      bodyMedium: text.bodyMedium?.copyWith(
        fontSize: 14 * bodyScale, height: 1.5, color: body,
      ),
      bodySmall: text.bodySmall?.copyWith(
        fontSize: 12, height: 1.4, color: muted,
      ),
      labelLarge: heading.labelLarge?.copyWith(
        fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: body,
      ),
      labelMedium: heading.labelMedium?.copyWith(
        fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, color: body,
      ),
      labelSmall: heading.labelSmall?.copyWith(
        fontSize: 11, height: 1.3, fontWeight: FontWeight.w500,
        letterSpacing: 0.5, color: muted,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design/tokens.dart';

/// Nordic-flavoured Material 3 theme. Light + dark share the same primary,
/// swap neutral surfaces. Typography is Inter across the board — geometric,
/// warm at large sizes, legible at small sizes.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(_lightScheme, brightness: Brightness.light);
  static ThemeData dark() => _build(_darkScheme, brightness: Brightness.dark);

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

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9BC2B0),
    onPrimary: Color(0xFF0F2A22),
    primaryContainer: Color(0xFF1F4638),
    onPrimaryContainer: Color(0xFFB8DBC9),
    secondary: Color(0xFFA8C3B0),
    onSecondary: Color(0xFF102A1E),
    secondaryContainer: Color(0xFF2A4133),
    onSecondaryContainer: Color(0xFFC5DDCB),
    tertiary: Color(0xFFF0A57F),
    onTertiary: Color(0xFF3B1C0A),
    tertiaryContainer: Color(0xFF6E3A1E),
    onTertiaryContainer: Color(0xFFFCDCC7),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: BrandColors.surfaceDark,
    onSurface: BrandColors.onSurfaceDark,
    surfaceContainerLowest: BrandColors.surfaceDarkLow,
    surfaceContainerLow: BrandColors.surfaceDarkLow,
    surfaceContainer: BrandColors.surfaceDarkContainer,
    surfaceContainerHigh: BrandColors.surfaceDarkContainerHigh,
    surfaceContainerHighest: BrandColors.surfaceDarkHigh,
    onSurfaceVariant: BrandColors.onSurfaceDarkMuted,
    outline: BrandColors.outlineDark,
    outlineVariant: BrandColors.outlineDarkSoft,
    inverseSurface: BrandColors.surface,
    onInverseSurface: BrandColors.onSurface,
    inversePrimary: BrandColors.forest,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  // -- Theme builder --------------------------------------------------------

  static ThemeData _build(ColorScheme scheme, {required Brightness brightness}) {
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
    );

    final textTheme = _buildTextTheme(scheme.onSurface, scheme.onSurfaceVariant);

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
        margin: EdgeInsets.zero,
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
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space12,
          vertical: Tokens.space4,
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

  // -- Typography (Inter) --------------------------------------------------

  static TextTheme _buildTextTheme(Color body, Color muted) {
    final base = GoogleFonts.interTextTheme();
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40, height: 1.15, fontWeight: FontWeight.w600,
        letterSpacing: -0.5, color: body,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 32, height: 1.2, fontWeight: FontWeight.w600,
        letterSpacing: -0.3, color: body,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 26, height: 1.25, fontWeight: FontWeight.w600, color: body,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, color: body,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 20, height: 1.35, fontWeight: FontWeight.w600, color: body,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, color: body,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18, height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: body,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16, height: 1.5, color: body,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14, height: 1.5, color: body,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12, height: 1.4, color: muted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: body,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, color: body,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11, height: 1.3, fontWeight: FontWeight.w500,
        letterSpacing: 0.5, color: muted,
      ),
    );
  }
}

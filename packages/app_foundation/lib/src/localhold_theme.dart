// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Builds the four supported visual adaptations from shared Localhold tokens.
abstract final class LocalholdTheme {
  static ThemeData light({
    LocalholdContentDensity density = LocalholdContentDensity.comfortable,
  }) => _build(
    brightness: Brightness.light,
    colors: LocalholdColors.light,
    density: density,
  );

  static ThemeData dark({
    LocalholdContentDensity density = LocalholdContentDensity.comfortable,
  }) => _build(
    brightness: Brightness.dark,
    colors: LocalholdColors.dark,
    density: density,
  );

  static ThemeData highContrastLight({
    LocalholdContentDensity density = LocalholdContentDensity.comfortable,
  }) => _build(
    brightness: Brightness.light,
    colors: LocalholdColors.highContrastLight,
    density: density,
    highContrast: true,
  );

  static ThemeData highContrastDark({
    LocalholdContentDensity density = LocalholdContentDensity.comfortable,
  }) => _build(
    brightness: Brightness.dark,
    colors: LocalholdColors.highContrastDark,
    density: density,
    highContrast: true,
  );

  static ThemeData _build({
    required Brightness brightness,
    required LocalholdColors colors,
    required LocalholdContentDensity density,
    bool highContrast = false,
  }) {
    final isLight = brightness == Brightness.light;
    final borderWidth = highContrast ? 2.0 : 1.0;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.brandAccent,
      onSecondary: colors.onBrandAccent,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceSecondary,
      outline: colors.border,
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LocalholdRadii.control),
      borderSide: BorderSide(color: colors.border, width: borderWidth),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.appBackground,
      canvasColor: colors.canvas,
      dividerColor: colors.border,
      focusColor: colors.focusRing,
      visualDensity: density.visualDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LocalholdRadii.section),
          side: BorderSide(color: colors.border, width: borderWidth),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.focusRing, width: 2),
        ),
        errorBorder: outline.copyWith(
          borderSide: BorderSide(color: colors.error, width: borderWidth),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: LocalholdSpacing.md,
          vertical: density.controlVerticalPadding,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            LocalholdAccessibility.minimumTouchTarget,
            LocalholdAccessibility.minimumTouchTarget,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LocalholdRadii.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            LocalholdAccessibility.minimumTouchTarget,
            LocalholdAccessibility.minimumTouchTarget,
          ),
          side: BorderSide(color: colors.border, width: borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LocalholdRadii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(
            LocalholdAccessibility.minimumTouchTarget,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: borderWidth,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: isLight ? 0.22 : 0.32),
        selectionHandleColor: colors.primary,
      ),
    );
  }
}

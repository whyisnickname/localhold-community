// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';

abstract final class LocalholdSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class LocalholdRadii {
  static const double control = 8;
  static const double section = 10;
}

abstract final class LocalholdBreakpoints {
  static const double compactEnd = 600;
  static const double mediumEnd = 840;

  static LocalholdWindowClass classify(double logicalWidth) {
    assert(logicalWidth >= 0, 'Logical width cannot be negative.');
    if (logicalWidth < compactEnd) return LocalholdWindowClass.compact;
    if (logicalWidth < mediumEnd) return LocalholdWindowClass.medium;
    return LocalholdWindowClass.expanded;
  }
}

enum LocalholdWindowClass { compact, medium, expanded }

abstract final class LocalholdAccessibility {
  static const double minimumTouchTarget = 48;
  static const double minimumSupportedWidth = 320;
  static const double acceptanceTextScale = 2;
}

enum LocalholdContentDensity {
  compact,
  comfortable;

  VisualDensity get visualDensity => switch (this) {
    compact => const VisualDensity(horizontal: -1, vertical: -1),
    comfortable => VisualDensity.standard,
  };

  double get controlVerticalPadding => switch (this) {
    compact => LocalholdSpacing.sm,
    comfortable => LocalholdSpacing.md,
  };
}

enum LocalholdThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    system => ThemeMode.system,
    light => ThemeMode.light,
    dark => ThemeMode.dark,
  };
}

@immutable
final class LocalholdColors extends ThemeExtension<LocalholdColors> {
  const LocalholdColors({
    required this.canvas,
    required this.appBackground,
    required this.surface,
    required this.surfaceSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.brandAccent,
    required this.onBrandAccent,
    required this.focusRing,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
  });

  static const light = LocalholdColors(
    canvas: Color(0xFFEFF3F7),
    appBackground: Color(0xFFF7F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFEAF0F6),
    textPrimary: Color(0xFF162234),
    textSecondary: Color(0xFF526176),
    border: Color(0xFFC7D1DC),
    primary: Color(0xFF185ABD),
    primaryPressed: Color(0xFF124A9D),
    onPrimary: Color(0xFFFFFFFF),
    brandAccent: Color(0xFFA84F2B),
    onBrandAccent: Color(0xFFFFFFFF),
    focusRing: Color(0xFF4D7FE5),
    success: Color(0xFF176B4D),
    warning: Color(0xFF875B00),
    error: Color(0xFFA62935),
    onError: Color(0xFFFFFFFF),
  );

  static const dark = LocalholdColors(
    canvas: Color(0xFF0B1118),
    appBackground: Color(0xFF101821),
    surface: Color(0xFF16212C),
    surfaceSecondary: Color(0xFF202D39),
    textPrimary: Color(0xFFF3F6F9),
    textSecondary: Color(0xFFAAB7C5),
    border: Color(0xFF394B5A),
    primary: Color(0xFF78AFFF),
    primaryPressed: Color(0xFF9BC2FF),
    onPrimary: Color(0xFF08111D),
    brandAccent: Color(0xFFF0A36B),
    onBrandAccent: Color(0xFF08111D),
    focusRing: Color(0xFFA9C7FF),
    success: Color(0xFF76D4AB),
    warning: Color(0xFFF0C56F),
    error: Color(0xFFFF9A9A),
    onError: Color(0xFF08111D),
  );

  static const highContrastLight = LocalholdColors(
    canvas: Color(0xFFFFFFFF),
    appBackground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF0F0F0),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF303030),
    border: Color(0xFF000000),
    primary: Color(0xFF003E8A),
    primaryPressed: Color(0xFF002F69),
    onPrimary: Color(0xFFFFFFFF),
    brandAccent: Color(0xFF873717),
    onBrandAccent: Color(0xFFFFFFFF),
    focusRing: Color(0xFF003E8A),
    success: Color(0xFF075B3D),
    warning: Color(0xFF694400),
    error: Color(0xFF8A1520),
    onError: Color(0xFFFFFFFF),
  );

  static const highContrastDark = LocalholdColors(
    canvas: Color(0xFF000000),
    appBackground: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceSecondary: Color(0xFF1C1C1C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE0E0E0),
    border: Color(0xFFFFFFFF),
    primary: Color(0xFFA9C7FF),
    primaryPressed: Color(0xFFC9DCFF),
    onPrimary: Color(0xFF000000),
    brandAccent: Color(0xFFFFB98A),
    onBrandAccent: Color(0xFF000000),
    focusRing: Color(0xFFFFFFFF),
    success: Color(0xFF8BE8BE),
    warning: Color(0xFFFFD580),
    error: Color(0xFFFFA8A8),
    onError: Color(0xFF000000),
  );

  final Color canvas;
  final Color appBackground;
  final Color surface;
  final Color surfaceSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color brandAccent;
  final Color onBrandAccent;
  final Color focusRing;
  final Color success;
  final Color warning;
  final Color error;
  final Color onError;

  @override
  LocalholdColors copyWith({
    Color? canvas,
    Color? appBackground,
    Color? surface,
    Color? surfaceSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? brandAccent,
    Color? onBrandAccent,
    Color? focusRing,
    Color? success,
    Color? warning,
    Color? error,
    Color? onError,
  }) => LocalholdColors(
    canvas: canvas ?? this.canvas,
    appBackground: appBackground ?? this.appBackground,
    surface: surface ?? this.surface,
    surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    primary: primary ?? this.primary,
    primaryPressed: primaryPressed ?? this.primaryPressed,
    onPrimary: onPrimary ?? this.onPrimary,
    brandAccent: brandAccent ?? this.brandAccent,
    onBrandAccent: onBrandAccent ?? this.onBrandAccent,
    focusRing: focusRing ?? this.focusRing,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    onError: onError ?? this.onError,
  );

  @override
  LocalholdColors lerp(covariant LocalholdColors? other, double t) {
    if (other == null) return this;
    return LocalholdColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      onBrandAccent: Color.lerp(onBrandAccent, other.onBrandAccent, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
    );
  }
}

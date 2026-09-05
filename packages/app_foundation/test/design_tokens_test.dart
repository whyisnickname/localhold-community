// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  test('responsive boundaries match the approved logical widths', () {
    expect(LocalholdBreakpoints.classify(0), LocalholdWindowClass.compact);
    expect(LocalholdBreakpoints.classify(599.9), LocalholdWindowClass.compact);
    expect(LocalholdBreakpoints.classify(600), LocalholdWindowClass.medium);
    expect(LocalholdBreakpoints.classify(839.9), LocalholdWindowClass.medium);
    expect(LocalholdBreakpoints.classify(840), LocalholdWindowClass.expanded);
  });

  test('appearance preferences map only to supported theme modes', () {
    expect(LocalholdThemePreference.system.themeMode, ThemeMode.system);
    expect(LocalholdThemePreference.light.themeMode, ThemeMode.light);
    expect(LocalholdThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('light and dark themes expose the approved brand tokens', () {
    final light = LocalholdTheme.light();
    final dark = LocalholdTheme.dark();

    expect(
      light.extension<LocalholdColors>()?.primary,
      const Color(0xFF185ABD),
    );
    expect(
      light.extension<LocalholdColors>()?.brandAccent,
      const Color(0xFFA84F2B),
    );
    expect(dark.extension<LocalholdColors>()?.primary, const Color(0xFF78AFFF));
    expect(
      dark.extension<LocalholdColors>()?.brandAccent,
      const Color(0xFFF0A36B),
    );
    expect(light.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(dark.materialTapTargetSize, MaterialTapTargetSize.padded);
  });

  test('high-contrast adaptations do not create another appearance mode', () {
    final light = LocalholdTheme.highContrastLight();
    final dark = LocalholdTheme.highContrastDark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.extension<LocalholdColors>()?.border, const Color(0xFF000000));
    expect(dark.extension<LocalholdColors>()?.border, const Color(0xFFFFFFFF));
  });

  test('density changes spacing without reducing touch-target policy', () {
    final compact = LocalholdTheme.light(
      density: LocalholdContentDensity.compact,
    );
    final comfortable = LocalholdTheme.light();

    expect(compact.visualDensity, isNot(comfortable.visualDensity));
    expect(LocalholdAccessibility.minimumTouchTarget, 48);
    expect(LocalholdAccessibility.minimumSupportedWidth, 320);
    expect(LocalholdAccessibility.acceptanceTextScale, 2);
  });

  test('every text and semantic token meets its contrast role', () {
    const palettes = <LocalholdColors>[
      LocalholdColors.light,
      LocalholdColors.dark,
      LocalholdColors.highContrastLight,
      LocalholdColors.highContrastDark,
    ];

    for (final colors in palettes) {
      expect(
        _contrast(colors.textPrimary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textSecondary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.primary, colors.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.brandAccent, colors.onBrandAccent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.error, colors.onError),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.success, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.warning, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.focusRing, colors.surface),
        greaterThanOrEqualTo(3),
      );
    }
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

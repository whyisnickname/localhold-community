// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';

abstract final class LocalholdTheme {
  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF185ABD),
      secondary: Color(0xFFA84F2B),
      surface: Color(0xFFFFFFFF),
      error: Color(0xFFA62935),
      onPrimary: Color(0xFFFFFFFF),
      onSecondary: Color(0xFFFFFFFF),
      onSurface: Color(0xFF162234),
      onError: Color(0xFFFFFFFF),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F9FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF162234),
      elevation: 0,
    ),
    visualDensity: VisualDensity.standard,
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF78AFFF),
      secondary: Color(0xFFF0A36B),
      surface: Color(0xFF16212C),
      error: Color(0xFFFF9A9A),
      onPrimary: Color(0xFF08111D),
      onSecondary: Color(0xFF08111D),
      onSurface: Color(0xFFF3F6F9),
      onError: Color(0xFF08111D),
    ),
    scaffoldBackgroundColor: const Color(0xFF101821),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF16212C),
      foregroundColor: Color(0xFFF3F6F9),
      elevation: 0,
    ),
    visualDensity: VisualDensity.standard,
  );
}

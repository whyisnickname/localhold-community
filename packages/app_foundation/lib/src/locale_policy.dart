// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/widgets.dart';

abstract final class LocalholdLocalePolicy {
  static const Locale russian = Locale('ru');
  static const Locale english = Locale('en');
  static const List<Locale> productionLocales = <Locale>[russian, english];

  static bool isProductionSupported(Locale locale) => productionLocales.any(
    (candidate) => candidate.languageCode == locale.languageCode,
  );

  static Locale resolve(List<Locale>? preferredLocales) {
    for (final locale in preferredLocales ?? const <Locale>[]) {
      if (isProductionSupported(locale)) {
        return locale.languageCode == russian.languageCode ? russian : english;
      }
    }
    return english;
  }
}

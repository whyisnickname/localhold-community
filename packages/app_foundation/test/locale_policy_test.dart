// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  test('only reviewed Russian and English are production supported', () {
    expect(LocalholdLocalePolicy.productionLocales, const <Locale>[
      Locale('ru'),
      Locale('en'),
    ]);
    expect(
      LocalholdLocalePolicy.isProductionSupported(const Locale('ru')),
      isTrue,
    );
    expect(
      LocalholdLocalePolicy.isProductionSupported(const Locale('en', 'US')),
      isTrue,
    );
    expect(
      LocalholdLocalePolicy.isProductionSupported(const Locale('ar')),
      isFalse,
    );
  });

  test(
    'resolution honors preferred supported language and falls back safely',
    () {
      expect(
        LocalholdLocalePolicy.resolve(const <Locale>[
          Locale('fr'),
          Locale('ru', 'RU'),
        ]),
        const Locale('ru'),
      );
      expect(
        LocalholdLocalePolicy.resolve(const <Locale>[Locale('de')]),
        const Locale('en'),
      );
      expect(LocalholdLocalePolicy.resolve(null), const Locale('en'));
    },
  );

  test('generated RU and EN catalogs have matching callable keys', () async {
    final english = await LocalholdLocalizations.delegate.load(
      const Locale('en'),
    );
    final russian = await LocalholdLocalizations.delegate.load(
      const Locale('ru'),
    );

    expect(english.navVault, 'Vault');
    expect(russian.navVault, 'Хранилище');
    expect(english.stateExpired, isNotEmpty);
    expect(russian.stateExpired, isNotEmpty);
    expect(
      LocalholdLocalizations.supportedLocales,
      contains(const Locale('en')),
    );
    expect(
      LocalholdLocalizations.supportedLocales,
      contains(const Locale('ru')),
    );
  });
}

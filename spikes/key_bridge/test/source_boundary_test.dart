// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distributed spike files carry the MPL SPDX marker', () {
    const individualFiles = <String>[
      '.gitignore',
      '.metadata',
      'CHANGELOG.md',
      'LICENSE',
      'README.md',
      'analysis_options.yaml',
      'pubspec.yaml',
      'android/.gitignore',
      'android/build.gradle.kts',
      'android/settings.gradle.kts',
      'ios/.gitignore',
      'ios/localhold_key_bridge.podspec',
      'ios/localhold_key_bridge/Package.swift',
    ];
    const sourceDirectories = <String>[
      'lib',
      'pigeons',
      'test',
      'tool',
      'android/src',
      'ios/localhold_key_bridge/Sources',
    ];
    final files = <File>[
      ...individualFiles.map(File.new),
      for (final directory in sourceDirectories)
        ...Directory(directory)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>(),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source,
        contains('SPDX-License-Identifier: MPL-2.0'),
        reason: file.path,
      );
    }
  });

  test('schema has no raw key import or export surface', () {
    final schema = File('pigeons/key_bridge_api.dart').readAsStringSync();
    final forbidden = RegExp(
      r'\b(rawDek|rawKek|exportKey|importKey|recoveryKey|secretKey)\b',
      caseSensitive: false,
    );

    expect(schema, isNot(matches(forbidden)));
    expect(schema, isNot(contains('String errorMessage')));
    expect(schema, isNot(contains('String errorDetails')));
  });

  test('all generated bindings carry the MPL SPDX marker', () {
    const generated = <String>[
      'lib/src/key_bridge_messages.g.dart',
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/KeyBridgeMessages.g.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/KeyBridgeMessages.g.swift',
    ];

    for (final path in generated) {
      final firstLine = File(path).readAsLinesSync().first;
      expect(
        firstLine,
        contains('SPDX-License-Identifier: MPL-2.0'),
        reason: path,
      );
    }
  });

  test('generated native emergency errors are redacted', () {
    const generatedNative = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/KeyBridgeMessages.g.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/KeyBridgeMessages.g.swift',
    ];

    for (final path in generatedNative) {
      final source = File(path).readAsStringSync();
      if (path.endsWith('.swift')) {
        expect(
          source,
          contains('return ["internalFailure", nil, nil]'),
          reason: path,
        );
      } else {
        expect(
          source,
          contains('return listOf("internalFailure", null, null)'),
          reason: path,
        );
      }
      expect(source, isNot(contains('getStackTraceString')), reason: path);
      expect(source, isNot(contains('Thread.callStackSymbols')), reason: path);
    }
  });

  test('generated message descriptions cannot disclose payload bytes', () {
    const generated = <String>[
      'lib/src/key_bridge_messages.g.dart',
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/KeyBridgeMessages.g.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/KeyBridgeMessages.g.swift',
    ];
    const forbiddenDescriptionFragments = <String>[
      r'masterPassword: $masterPassword',
      r'newMasterPassword: $newMasterPassword',
      r'plaintext: $plaintext',
      'masterPassword.contentToString()',
      'newMasterPassword.contentToString()',
      'plaintext.contentToString()',
      r'String(describing: masterPassword)',
      r'String(describing: newMasterPassword)',
      r'String(describing: plaintext)',
      r'String(describing: payload)',
      r'String(describing: vaultKeyEnvelope)',
    ];

    for (final path in generated) {
      final source = File(path).readAsStringSync();
      expect(source, contains('<redacted>'), reason: path);
      for (final fragment in forbiddenDescriptionFragments) {
        expect(source, isNot(contains(fragment)), reason: '$path: $fragment');
      }
    }

    final generator = File('tool/generate_bindings.dart').readAsStringSync();
    expect(generator, contains('_redactSensitiveMessageStrings'));
    expect(generator, contains('expectedMessageDescriptionCount'));
  });

  test('native adapters are visibly fail-closed spike code', () {
    const adapters = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/LocalholdKeyBridgePlugin.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/LocalholdKeyBridgePlugin.swift',
    ];

    for (final path in adapters) {
      final source = File(path).readAsStringSync();
      expect(source, contains('STAGE2_SPIKE_DO_NOT_SHIP'), reason: path);
      expect(
        RegExp(r'not_?implemented').hasMatch(source.toLowerCase()),
        isTrue,
        reason: path,
      );
      expect(source, isNot(contains('HttpClient')), reason: path);
      expect(source, isNot(contains('URLSession')), reason: path);
    }
  });

  test('biometric keys cannot be created or rotated without explicit recovery', () {
    const wrappers = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/AndroidBiometricWrapper.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSBiometricWrapper.swift',
    ];

    for (final path in wrappers) {
      final source = File(path).readAsStringSync();
      expect(source, contains('enableAfterMasterConfirmation'), reason: path);
      expect(source, contains('userConfirmed'), reason: path);
      expect(source, isNot(contains('createKeyIfAbsent')), reason: path);
      expect(source, isNot(contains('URLSession')), reason: path);
    }
    final android = File(wrappers.first).readAsStringSync();
    expect(android, contains('.setUserAuthenticationRequired(true)'));
    expect(android, contains('.setInvalidatedByBiometricEnrollment(true)'));
    expect(android, contains('.setRandomizedEncryptionRequired(true)'));
    expect(android, contains('KeyProperties.AUTH_BIOMETRIC_STRONG'));
    expect(android, contains('setUserAuthenticationValidityDurationSeconds(-1)'));
    final ios = File(wrappers.last).readAsStringSync();
    expect(ios, contains('kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly'));
    expect(ios, contains('.biometryCurrentSet'));
    expect(ios, contains('kSecAttrSynchronizable: false'));
    expect(ios, contains('SecRandomCopyBytes'));
  });
}

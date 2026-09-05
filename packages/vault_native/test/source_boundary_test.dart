// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community production source files carry the MPL SPDX marker', () {
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
      'ios/localhold_vault_native.podspec',
      'ios/localhold_key_bridge/Package.swift',
    ];
    const sourceDirectories = <String>[
      'lib',
      'pigeons',
      'test',
      'tool',
      'android/src',
      'ios/localhold_key_bridge/Sources',
      'ios/localhold_key_bridge/Tests',
    ];
    final files = <File>[
      ...individualFiles.map(File.new),
      for (final directory in sourceDirectories)
        ...Directory(directory)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where(
              (file) =>
                  !file.path.contains('third_party') &&
                  !file.path.contains('jniLibs') &&
                  !file.path.contains('cpp\\include') &&
                  !file.path.contains('cpp/include') &&
                  !file.path.endsWith('bip39_english.txt'),
            ),
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

  test('Swift 6 UI and async reply boundaries remain explicit', () {
    final generated = File(
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/KeyBridgeMessages.g.swift',
    ).readAsStringSync();
    final plugin = File(
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/LocalholdKeyBridgePlugin.swift',
    ).readAsStringSync();
    final coordinator = File(
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSBiometricCoordinator.swift',
    ).readAsStringSync();

    expect(
      generated,
      contains('extension VaultSessionReply: @unchecked Sendable {}'),
    );
    expect(
      generated,
      contains('extension StatusReply: @unchecked Sendable {}'),
    );
    expect(generated, contains('protocol KeyBridgeHostApi: Sendable'));
    expect(
      generated,
      contains('class KeyBridgeMessagesPigeonReplyBox: @unchecked Sendable'),
    );
    expect(generated, contains('replyBox.call(wrapResult(result))'));
    expect(plugin, contains('KeyBridgeHostApi, @unchecked Sendable'));
    expect(plugin, contains('MainActor.assumeIsolated'));
    expect(
      plugin,
      contains('@MainActor\n  private static func topViewController'),
    );
    expect(plugin, contains('@MainActor\n  private func updatePrivacyCover'));
    expect(
      coordinator,
      isNot(contains('BiometricStatusReply(configured: false, error:')),
    );
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

  test('native adapters register reviewed production services only', () {
    const adapters = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/LocalholdKeyBridgePlugin.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/LocalholdKeyBridgePlugin.swift',
    ];

    for (final path in adapters) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('STAGE2_SPIKE_DO_NOT_SHIP')), reason: path);
      expect(
        source.toLowerCase(),
        isNot(contains('not_implemented')),
        reason: path,
      );
      expect(source, isNot(contains('HttpClient')), reason: path);
      expect(source, isNot(contains('URLSession')), reason: path);
    }
    expect(
      File(adapters.first).readAsStringSync(),
      contains('NativeVaultCryptoService'),
    );
    expect(
      File(adapters.last).readAsStringSync(),
      contains('IOSVaultCryptoService'),
    );
  });

  test(
    'reminder and share adapters have no network or arbitrary shortcut surface',
    () {
      final manifest = File('android/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final android = File(
        'android/src/main/kotlin/dev/localhold/localhold_key_bridge/AndroidPlatformFeatures.kt',
      ).readAsStringSync();
      final ios = File(
        'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSPlatformFeatures.swift',
      ).readAsStringSync();

      expect(manifest, isNot(contains('android.permission.INTERNET')));
      expect(android, isNot(contains('HttpClient')));
      expect(ios, isNot(contains('URLSession')));
      for (final source in [android, ios]) {
        expect(source, contains('localhold.add'));
        expect(source, contains('localhold.search'));
        expect(source, contains('localhold.lock'));
        expect(source, isNot(contains('recordNameShortcut')));
      }
    },
  );

  test(
    'iOS Share Extension is app-group-only and reuses the streaming stager',
    () {
      final stager = File(
        'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSInboundShareStager.swift',
      ).readAsStringSync();
      final extension = File(
        'example/ios/ShareExtension/ShareViewController.swift',
      ).readAsStringSync();
      final project = File('example/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      const group = 'group.dev.localhold.localholdKeyBridgeExample';
      for (final path in [
        'example/ios/Runner/Info.plist',
        'example/ios/Runner/Runner.entitlements',
        'example/ios/ShareExtension/Info.plist',
        'example/ios/ShareExtension/ShareExtension.entitlements',
      ]) {
        expect(File(path).readAsStringSync(), contains(group), reason: path);
      }
      expect(stager, contains('FileHandle(forReadingFrom:'));
      expect(
        stager,
        contains('containerURL(forSecurityApplicationGroupIdentifier:'),
      );
      expect(stager, contains('queueMaximum = 8'));
      expect(stager, contains('queueByteMaximum = 512 * 1024 * 1024'));
      expect(stager, isNot(contains('UIApplication')));
      expect(stager, isNot(contains('URLSession')));
      expect(extension, contains('loadFileRepresentation'));
      expect(extension, isNot(contains('print(')));
      expect(project, contains('com.apple.product-type.app-extension'));
      expect(project, contains('APPLICATION_EXTENSION_API_ONLY = YES'));
      expect(project, contains('IOSInboundShareStager.swift in Sources'));
    },
  );

  test(
    'biometric keys cannot be created or rotated without explicit recovery',
    () {
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
      expect(
        android,
        contains('setUserAuthenticationValidityDurationSeconds(-1)'),
      );
      final ios = File(wrappers.last).readAsStringSync();
      expect(ios, contains('kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly'));
      expect(ios, contains('.biometryCurrentSet'));
      expect(ios, contains('kSecAttrSynchronizable: false'));
      expect(ios, contains('SecRandomCopyBytes'));
    },
  );

  test('native sensitive actions require master or recovery origin', () {
    const services = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/NativeVaultCryptoService.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSVaultCryptoService.swift',
    ];
    const coordinators = <String>[
      'android/src/main/kotlin/dev/localhold/localhold_key_bridge/AndroidBiometricCoordinator.kt',
      'ios/localhold_key_bridge/Sources/localhold_key_bridge/IOSBiometricCoordinator.swift',
    ];
    for (final path in services) {
      final source = File(path).readAsStringSync();
      expect(source, contains('requireSensitiveSession'), reason: path);
      expect(
        source,
        anyOf(
          contains('REAUTHENTICATION_REQUIRED'),
          contains('reauthenticationRequired'),
        ),
        reason: path,
      );
      expect(source, contains('isMasterCredentialFresh'), reason: path);
      expect(
        source,
        anyOf(
          contains('SENSITIVE_SESSION_FRESHNESS_MILLIS'),
          contains('sensitiveSessionFreshnessSeconds'),
        ),
        reason: path,
      );
      expect(
        source,
        anyOf(
          contains('SystemClock.elapsedRealtime()'),
          contains('ProcessInfo.processInfo.systemUptime'),
        ),
        reason: path,
      );
    }
    for (final path in coordinators) {
      final source = File(path).readAsStringSync();
      expect(source, contains('sensitiveSessionError'), reason: path);
      expect(source, contains('isMasterCredentialFresh'), reason: path);
    }
  });
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

const _dartOutput = 'lib/src/key_bridge_messages.g.dart';
const _kotlinOutput =
    'android/src/main/kotlin/dev/localhold/localhold_key_bridge/KeyBridgeMessages.g.kt';
const _swiftOutput =
    'ios/localhold_key_bridge/Sources/localhold_key_bridge/KeyBridgeMessages.g.swift';
const expectedMessageDescriptionCount = 8;

Future<void> main() async {
  final generation = await Process.run(Platform.resolvedExecutable, const [
    'run',
    'pigeon',
    '--input',
    'pigeons/key_bridge_api.dart',
    '--dart_out',
    _dartOutput,
    '--kotlin_out',
    _kotlinOutput,
    '--kotlin_package',
    'dev.localhold.localhold_key_bridge',
    '--swift_out',
    _swiftOutput,
    '--copyright_header',
    'pigeons/copyright.txt',
  ]);
  stdout.write(generation.stdout);
  stderr.write(generation.stderr);
  if (generation.exitCode != 0) {
    exitCode = generation.exitCode;
    return;
  }

  _redactKotlinEmergencyErrors(File(_kotlinOutput));
  _redactSwiftEmergencyErrors(File(_swiftOutput));
  _redactSensitiveMessageStrings(
    dart: File(_dartOutput),
    kotlin: File(_kotlinOutput),
    swift: File(_swiftOutput),
  );

  final formatting = await Process.run(Platform.resolvedExecutable, const [
    'format',
    _dartOutput,
  ]);
  stdout.write(formatting.stdout);
  stderr.write(formatting.stderr);
  if (formatting.exitCode != 0) {
    exitCode = formatting.exitCode;
  }
}

void _redactSensitiveMessageStrings({
  required File dart,
  required File kotlin,
  required File swift,
}) {
  _replaceExpectedDescriptions(
    dart,
    RegExp(
      r"  String toString\(\) \{\n    return '.*?';\n  \}",
      dotAll: true,
    ),
    "  String toString() {\n    return 'KeyBridgeMessage(<redacted>)';\n  }",
  );
  _replaceExpectedDescriptions(
    kotlin,
    RegExp(
      r'  override fun toString\(\): String \{\n    return ".*?"\n  \}',
      dotAll: true,
    ),
    '  override fun toString(): String {\n    return "KeyBridgeMessage(<redacted>)"\n  }',
  );
  _replaceExpectedDescriptions(
    swift,
    RegExp(
      r'  public var description: String \{\n    return ".*?"\n  \}',
      dotAll: true,
    ),
    '  public var description: String {\n    return "KeyBridgeMessage(<redacted>)"\n  }',
  );
}

void _replaceExpectedDescriptions(File file, RegExp unsafe, String replacement) {
  final source = file.readAsStringSync();
  final count = unsafe.allMatches(source).length;
  if (count != expectedMessageDescriptionCount) {
    throw StateError(
      'Pinned Pigeon message descriptions changed in ${file.path}; '
      'expected $expectedMessageDescriptionCount, found $count.',
    );
  }
  file.writeAsStringSync(source.replaceAll(unsafe, replacement));
}

void _redactKotlinEmergencyErrors(File file) {
  var source = file.readAsStringSync();
  source = source.replaceFirst('import android.util.Log\n', '');
  final unsafe = RegExp(
    r'  fun wrapError\(exception: Throwable\): List<Any\?> \{.*?\n  \}\n  fun doubleEquals',
    dotAll: true,
  );
  if (!unsafe.hasMatch(source)) {
    throw StateError('Pinned Pigeon Kotlin error wrapper changed; review required.');
  }
  source = source.replaceFirst(
    unsafe,
    '''  @Suppress("UNUSED_PARAMETER")
  fun wrapError(exception: Throwable): List<Any?> {
    return listOf("internalFailure", null, null)
  }
  fun doubleEquals''',
  );
  file.writeAsStringSync(source);
}

void _redactSwiftEmergencyErrors(File file) {
  var source = file.readAsStringSync();
  final unsafe = RegExp(
    r'private func wrapError\(_ error: Any\) -> \[Any\?\] \{.*?\n\}\n\nenum KeyBridgeMessagesPigeonInternal',
    dotAll: true,
  );
  if (!unsafe.hasMatch(source)) {
    throw StateError('Pinned Pigeon Swift error wrapper changed; review required.');
  }
  source = source.replaceFirst(
    unsafe,
    '''private func wrapError(_ error: Any) -> [Any?] {
  _ = error
  return ["internalFailure", nil, nil]
}

enum KeyBridgeMessagesPigeonInternal''',
  );
  file.writeAsStringSync(source);
}

// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unicode;
import 'package:zxcvbn/zxcvbn.dart';

import 'errors.dart';

abstract final class VaultLimits {
  static const int maximumRecordBytes = 1024 * 1024;
  static const int maximumBridgePayloadBytes = 2 * 1024 * 1024;
  static const int maximumFieldsPerRecord = 256;
  static const int maximumTagsPerRecord = 100;
  static const int attachmentChunkBytes = 1024 * 1024;
  static const int minimumMasterPasswordCodePoints = 15;
  static const int maximumMasterPasswordBytes = 1024;
}

abstract final class CuratedMasterPasswordBlocklist {
  static const int revision = 1;

  /// Local-only exact candidates that remain dangerous even after the minimum
  /// length check. Pattern-based strength feedback is handled separately.
  static const Set<String> values = {
    'passwordpassword',
    'password123456',
    'qwertyqwerty123',
    '123456789012345',
    'localholdlocalhold',
    'парольпарольпароль',
  };
}

enum PasswordStrengthLevel { veryWeak, weak, fair, strong, veryStrong }

final class MasterPasswordPolicy {
  MasterPasswordPolicy({
    this._blockedPasswords = CuratedMasterPasswordBlocklist.values,
    Zxcvbn? estimator,
  }) : _estimator = estimator ?? Zxcvbn();

  final Set<String> _blockedPasswords;
  final Zxcvbn _estimator;

  MasterPasswordAssessment assess(String password) {
    final bytes = utf8.encode(password).length;
    if (password.runes.length < VaultLimits.minimumMasterPasswordCodePoints ||
        bytes > VaultLimits.maximumMasterPasswordBytes) {
      return const MasterPasswordAssessment.rejected(
        VaultFailureCode.invalidInput,
      );
    }
    if (_blockedPasswords.contains(password.toLowerCase())) {
      return const MasterPasswordAssessment.rejected(
        VaultFailureCode.invalidInput,
      );
    }
    final estimatedScore = (_estimator.evaluate(password).score ?? 0)
        .clamp(0, 4)
        .toInt();
    return MasterPasswordAssessment.accepted(
      strength: PasswordStrengthLevel.values[estimatedScore],
      warnings: {
        if (estimatedScore <= 1) PasswordWarning.weakPattern,
        if (unicode.nfc(password) != password ||
            unicode.nfkc(password) != password)
          PasswordWarning.canonicallyAmbiguousUnicode,
      },
    );
  }
}

enum PasswordWarning { weakPattern, canonicallyAmbiguousUnicode }

final class MasterPasswordAssessment {
  MasterPasswordAssessment.accepted({
    required this.strength,
    Set<PasswordWarning> warnings = const {},
  }) : accepted = true,
       rejection = null,
       warnings = Set.unmodifiable(warnings);

  const MasterPasswordAssessment.rejected(this.rejection)
    : accepted = false,
      strength = null,
      warnings = const {};

  final bool accepted;
  final PasswordStrengthLevel? strength;
  final Set<PasswordWarning> warnings;
  final VaultFailureCode? rejection;
}

enum AutoLockDelay {
  immediately(Duration.zero),
  thirtySeconds(Duration(seconds: 30)),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  fifteenMinutes(Duration(minutes: 15)),
  thirtyMinutes(Duration(minutes: 30));

  const AutoLockDelay(this.duration);
  final Duration duration;
}

enum TrashRetention {
  sevenDays(Duration(days: 7)),
  thirtyDays(Duration(days: 30)),
  ninetyDays(Duration(days: 90)),
  never(null);

  const TrashRetention(this.duration);
  final Duration? duration;
}

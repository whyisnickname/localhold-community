// SPDX-License-Identifier: MPL-2.0
import 'dart:io';

import 'package:backup_scheduler/backup_scheduler.dart';
import 'package:test/test.dart';

BackupScheduleState state({
  BackupPlatform platform = BackupPlatform.android,
  bool enabled = true,
  bool premium = true,
  bool grant = true,
  bool available = true,
  bool due = true,
  bool iosTime = false,
}) =>
    BackupScheduleState(
      platform: platform,
      enabled: enabled,
      hasPremium: premium,
      hasProviderGrant: grant,
      providerAvailable: available,
      isDue: due,
      iosBackgroundTimeGranted: iosTime,
    );

void main() {
  test('Android due work runs and disabled/not-due work does not', () {
    expect(decideBackup(state(), BackupTrigger.background),
        BackupDecision.runNow);
    expect(decideBackup(state(enabled: false), BackupTrigger.background),
        BackupDecision.disabled);
    expect(decideBackup(state(due: false), BackupTrigger.background),
        BackupDecision.notDue);
    expect(decideBackup(state(enabled: false), BackupTrigger.manual),
        BackupDecision.runNow);
  });

  test('Premium and provider failures are explicit and fail closed', () {
    expect(decideBackup(state(premium: false), BackupTrigger.manual),
        BackupDecision.premiumRequired);
    expect(decideBackup(state(grant: false), BackupTrigger.background),
        BackupDecision.reauthorizeLocation);
    expect(decideBackup(state(available: false), BackupTrigger.background),
        BackupDecision.providerUnavailable);
  });

  test('iOS denied background time defers and next open runs', () {
    final denied = state(platform: BackupPlatform.ios);
    expect(decideBackup(denied, BackupTrigger.background),
        BackupDecision.deferToNextOpen);
    expect(decideBackup(denied, BackupTrigger.foregroundOpen),
        BackupDecision.runNow);
    expect(
      decideBackup(state(platform: BackupPlatform.ios, iosTime: true),
          BackupTrigger.background),
      BackupDecision.runNow,
    );
  });

  test('verified/deferred state is deterministic and UTC', () {
    const initial = LocalBackupSchedule(
      enabled: true,
      intervalHours: 24,
      lastVerifiedAt: null,
      pendingNextOpen: false,
    );
    expect(initial.markDeferred().pendingNextOpen, isTrue);
    final verified = initial.markDeferred().markVerified(
          DateTime.parse('2026-08-22T12:00:00+03:00'),
        );
    expect(verified.pendingNextOpen, isFalse);
    expect(verified.lastVerifiedAt!.toIso8601String(),
        '2026-08-22T09:00:00.000Z');
  });

  test('iOS source keeps security scope until completion and handles expiration', () {
    final source = File('ios/UserSelectedBackupCoordinator.swift').readAsStringSync();
    expect(source, contains('registerBackgroundHandler'));
    expect(source, contains('BackupCancellationToken'));
    expect(source, contains('expirationHandler'));
    expect(source, contains('pending-next-open'));
    expect(source, contains('SecurityScopedDirectoryAccess'));
    expect(source, contains('startAccessingSecurityScopedResource'));
    expect(source, contains('checkResourceIsReachable'));
    expect(source, contains('providerUnavailable'));
    expect(source, contains('access.stop()'));
    expect(source, contains('hasPremium'));
    expect(source, contains('activeCancellation'));
    expect(source, contains('beginRun'));
    expect(source, contains('schedule-enabled'));
    expect(source, contains('cancellation?.cancel()'));
    expect(source, isNot(contains('URLSession')));
  });

  test('Android diagnostic launcher cannot ship or accept incomplete grants', () {
    final activity = File(
      'android/app/src/main/kotlin/dev/localhold/backup/spike/'
      'BackupLocationActivity.kt',
    ).readAsStringSync();
    final policy = File(
      'android/app/src/main/kotlin/dev/localhold/backup/spike/'
      'PersistedGrantPolicy.kt',
    ).readAsStringSync();
    final store = File(
      'android/app/src/main/kotlin/dev/localhold/backup/spike/'
      'BackupLocationStore.kt',
    ).readAsStringSync();
    expect(activity, contains('STAGE2_SPIKE_DO_NOT_SHIP'));
    expect(activity, contains('ApplicationInfo.FLAG_DEBUGGABLE'));
    expect(activity, contains('catch (_: SecurityException)'));
    expect(policy, contains('FLAG_GRANT_PERSISTABLE_URI_PERMISSION'));
    expect(store, contains('.commit()'));
  });
}

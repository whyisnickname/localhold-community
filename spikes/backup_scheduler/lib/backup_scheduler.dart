// SPDX-License-Identifier: MPL-2.0
enum BackupPlatform { android, ios }

enum BackupTrigger { background, foregroundOpen, manual }

enum BackupDecision {
  runNow,
  deferToNextOpen,
  notDue,
  disabled,
  premiumRequired,
  reauthorizeLocation,
  providerUnavailable,
}

final class BackupScheduleState {
  const BackupScheduleState({
    required this.platform,
    required this.enabled,
    required this.hasPremium,
    required this.hasProviderGrant,
    required this.providerAvailable,
    required this.isDue,
    this.iosBackgroundTimeGranted = false,
  });

  final BackupPlatform platform;
  final bool enabled;
  final bool hasPremium;
  final bool hasProviderGrant;
  final bool providerAvailable;
  final bool isDue;
  final bool iosBackgroundTimeGranted;
}

BackupDecision decideBackup(
  BackupScheduleState state,
  BackupTrigger trigger,
) {
  if (!state.enabled && trigger != BackupTrigger.manual) {
    return BackupDecision.disabled;
  }
  if (!state.hasPremium) return BackupDecision.premiumRequired;
  if (!state.hasProviderGrant) return BackupDecision.reauthorizeLocation;
  if (!state.providerAvailable) return BackupDecision.providerUnavailable;
  if (!state.isDue && trigger != BackupTrigger.manual) {
    return BackupDecision.notDue;
  }

  if (state.platform == BackupPlatform.ios &&
      trigger == BackupTrigger.background &&
      !state.iosBackgroundTimeGranted) {
    return BackupDecision.deferToNextOpen;
  }
  return BackupDecision.runNow;
}

/// Persisted local scheduling data. Provider handles are deliberately opaque;
/// callers must never serialize them into analytics or backend payloads.
final class LocalBackupSchedule {
  const LocalBackupSchedule({
    required this.enabled,
    required this.intervalHours,
    required this.lastVerifiedAt,
    required this.pendingNextOpen,
  });

  final bool enabled;
  final int intervalHours;
  final DateTime? lastVerifiedAt;
  final bool pendingNextOpen;

  LocalBackupSchedule markDeferred() => LocalBackupSchedule(
        enabled: enabled,
        intervalHours: intervalHours,
        lastVerifiedAt: lastVerifiedAt,
        pendingNextOpen: true,
      );

  LocalBackupSchedule markVerified(DateTime at) => LocalBackupSchedule(
        enabled: enabled,
        intervalHours: intervalHours,
        lastVerifiedAt: at.toUtc(),
        pendingNextOpen: false,
      );
}

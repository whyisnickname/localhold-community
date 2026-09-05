// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';
import 'identifiers.dart';
import 'record_listing.dart';
import 'reminder_service.dart';
import 'reminders.dart';

enum NotificationPermissionState {
  notDetermined,
  denied,
  restricted,
  authorized,
}

abstract interface class NotificationPermissionPort {
  Future<NotificationPermissionState> status();
  Future<NotificationPermissionState> request();
  Future<void> openSystemSettings();
}

/// [replace] is an idempotent upsert keyed only by the synthetic reminder ID.
abstract interface class ReminderSchedulerPort {
  Future<void> replace(ReminderNotificationRequest request);
  Future<void> cancel(ReminderId id);
}

enum ReminderActivationStatus {
  scheduled,
  explanationRequired,
  permissionDenied,
  permissionRestricted,
  past,
  failed,
}

final class ReminderActivationResult {
  const ReminderActivationResult({required this.status, this.schedule});

  final ReminderActivationStatus status;
  final ReminderSchedule? schedule;
}

final class ReminderCoordinator {
  const ReminderCoordinator({
    required this.configurations,
    required this.planner,
    required this.resolver,
    required this.permissions,
    required this.scheduler,
  });

  final ReminderConfigurationPort configurations;
  final ReminderPlanner planner;
  final ReminderWallClockResolver resolver;
  final NotificationPermissionPort permissions;
  final ReminderSchedulerPort scheduler;

  Future<ReminderActivationResult> enable({
    required ReminderSchedule schedule,
    required DateTime nowUtc,
    required SafeRecordProjection safeRecord,
    required bool explanationAccepted,
    SafeNotificationAmount? safeAmount,
  }) async {
    if (!explanationAccepted) {
      return const ReminderActivationResult(
        status: ReminderActivationStatus.explanationRequired,
      );
    }
    try {
      final proposed = schedule.copyWith(state: ReminderScheduleState.enabled);
      final request = await planner.plan(
        proposed,
        nowUtc: nowUtc,
        resolver: resolver,
        safeRecord: safeRecord,
        safeAmount: safeAmount,
      );
      if (request == null) {
        final saved = await _save(
          proposed.copyWith(state: ReminderScheduleState.disabled),
        );
        return ReminderActivationResult(
          status: ReminderActivationStatus.past,
          schedule: saved,
        );
      }
      var permission = await permissions.status();
      if (permission == NotificationPermissionState.notDetermined) {
        permission = await permissions.request();
      }
      if (permission != NotificationPermissionState.authorized) {
        final saved = await _save(
          proposed.copyWith(state: ReminderScheduleState.disabled),
        );
        return ReminderActivationResult(
          status: permission == NotificationPermissionState.restricted
              ? ReminderActivationStatus.permissionRestricted
              : ReminderActivationStatus.permissionDenied,
          schedule: saved,
        );
      }
      final saved = await _save(proposed);
      await scheduler.replace(request);
      return ReminderActivationResult(
        status: ReminderActivationStatus.scheduled,
        schedule: saved,
      );
    } on Object {
      return const ReminderActivationResult(
        status: ReminderActivationStatus.failed,
      );
    }
  }

  Future<void> openSystemSettings() => permissions.openSystemSettings();

  Future<bool> reconcile({
    required DateTime nowUtc,
    required bool entitlementActive,
    required Map<RecordId, SafeRecordProjection> safeRecords,
    Map<RecordId, SafeNotificationAmount> safeAmounts = const {},
  }) async {
    try {
      final snapshot = await configurations.loadAll();
      if (!entitlementActive) {
        for (final schedule in snapshot.schedules) {
          await scheduler.cancel(schedule.id);
        }
        await configurations.suspendEnabled();
        return true;
      }
      for (final schedule in snapshot.schedules) {
        if (schedule.state != ReminderScheduleState.enabled) {
          await scheduler.cancel(schedule.id);
          continue;
        }
        final safeRecord = safeRecords[schedule.recordId];
        if (safeRecord == null) {
          await scheduler.cancel(schedule.id);
          continue;
        }
        final request = await planner.plan(
          schedule,
          nowUtc: nowUtc,
          resolver: resolver,
          safeRecord: safeRecord,
          safeAmount: safeAmounts[schedule.recordId],
        );
        if (request == null) {
          await scheduler.cancel(schedule.id);
        } else {
          await scheduler.replace(request);
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<ReminderSchedule> _save(ReminderSchedule proposed) async {
    final current = await configurations.read(proposed.id);
    if (current == null) return configurations.create(proposed);
    if (current.revision != proposed.revision ||
        current.recordId != proposed.recordId ||
        current.fieldId != proposed.fieldId) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    return configurations.update(
      proposed: proposed,
      expectedRevision: current.revision,
    );
  }
}

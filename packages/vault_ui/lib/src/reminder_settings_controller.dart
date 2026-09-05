// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

enum ReminderSettingsStatus {
  editing,
  explanation,
  working,
  scheduled,
  permissionDenied,
  permissionRestricted,
  past,
  recoverableFailure,
  locked,
}

@immutable
final class ReminderSettingsState {
  const ReminderSettingsState({
    required this.status,
    required this.offsetMinutes,
    required this.preferredMinute,
    required this.quietStartMinute,
    required this.quietEndMinute,
    required this.privacy,
  });

  final ReminderSettingsStatus status;
  final int offsetMinutes;
  final int preferredMinute;
  final int quietStartMinute;
  final int quietEndMinute;
  final ReminderPrivacy privacy;

  ReminderSettingsState copyWith({
    ReminderSettingsStatus? status,
    int? offsetMinutes,
    int? preferredMinute,
    int? quietStartMinute,
    int? quietEndMinute,
    ReminderPrivacy? privacy,
  }) => ReminderSettingsState(
    status: status ?? this.status,
    offsetMinutes: offsetMinutes ?? this.offsetMinutes,
    preferredMinute: preferredMinute ?? this.preferredMinute,
    quietStartMinute: quietStartMinute ?? this.quietStartMinute,
    quietEndMinute: quietEndMinute ?? this.quietEndMinute,
    privacy: privacy ?? this.privacy,
  );

  @override
  String toString() =>
      'ReminderSettingsState(${status.name}, $offsetMinutes, '
      '$preferredMinute, $quietStartMinute, $quietEndMinute, ${privacy.name})';
}

final class ReminderSettingsController extends ChangeNotifier {
  ReminderSettingsController({
    required ReminderSchedule schedule,
    required SafeRecordProjection safeRecord,
    required ReminderCoordinator coordinator,
    DateTime Function()? now,
  }) : _schedule = schedule,
       _safeRecord = safeRecord,
       _coordinator = coordinator,
       _now = now ?? (() => DateTime.now().toUtc()),
       _state = ReminderSettingsState(
         status: ReminderSettingsStatus.editing,
         offsetMinutes: schedule.offset.minutes,
         preferredMinute: schedule.preferredMinute,
         quietStartMinute: schedule.quietHours.startMinute,
         quietEndMinute: schedule.quietHours.endMinute,
         privacy: schedule.privacy,
       );

  ReminderSchedule? _schedule;
  SafeRecordProjection? _safeRecord;
  final ReminderCoordinator _coordinator;
  final DateTime Function() _now;
  bool _disposed = false;
  int _generation = 0;
  ReminderSettingsState _state;

  ReminderSettingsState get state => _state;

  void setOffset(ReminderOffset offset) {
    try {
      offset.validate();
      _updateDraft(offset: offset);
    } on VaultFailure {
      _emit(_state.copyWith(status: ReminderSettingsStatus.recoverableFailure));
    }
  }

  void setPreferredMinute(int minute) {
    if (minute < 0 || minute >= 24 * 60) {
      _emit(_state.copyWith(status: ReminderSettingsStatus.recoverableFailure));
      return;
    }
    _updateDraft(preferredMinute: minute);
  }

  void setQuietHours(ReminderQuietHours quietHours) {
    try {
      quietHours.validate();
      _updateDraft(quietHours: quietHours);
    } on VaultFailure {
      _emit(_state.copyWith(status: ReminderSettingsStatus.recoverableFailure));
    }
  }

  void setPrivacy(ReminderPrivacy privacy) => _updateDraft(privacy: privacy);

  void beginEnable() {
    if (_schedule == null || _safeRecord == null) return;
    _emit(_state.copyWith(status: ReminderSettingsStatus.explanation));
  }

  Future<void> confirmEnable({SafeNotificationAmount? safeAmount}) async {
    final schedule = _schedule;
    final record = _safeRecord;
    if (schedule == null ||
        record == null ||
        _state.status != ReminderSettingsStatus.explanation) {
      return;
    }
    final generation = _generation;
    _emit(_state.copyWith(status: ReminderSettingsStatus.working));
    final result = await _coordinator.enable(
      schedule: schedule,
      nowUtc: _now().toUtc(),
      safeRecord: record,
      safeAmount: safeAmount,
      explanationAccepted: true,
    );
    if (!_isCurrent(generation)) return;
    if (result.schedule case final saved?) _schedule = saved;
    _emit(
      _state.copyWith(
        status: switch (result.status) {
          ReminderActivationStatus.scheduled =>
            ReminderSettingsStatus.scheduled,
          ReminderActivationStatus.explanationRequired =>
            ReminderSettingsStatus.explanation,
          ReminderActivationStatus.permissionDenied =>
            ReminderSettingsStatus.permissionDenied,
          ReminderActivationStatus.permissionRestricted =>
            ReminderSettingsStatus.permissionRestricted,
          ReminderActivationStatus.past => ReminderSettingsStatus.past,
          ReminderActivationStatus.failed =>
            ReminderSettingsStatus.recoverableFailure,
        },
      ),
    );
  }

  Future<void> openSystemSettings() => _coordinator.openSystemSettings();

  void returnToEditing() {
    if (_schedule == null) return;
    _emit(_state.copyWith(status: ReminderSettingsStatus.editing));
  }

  void onBackgroundOrLock() {
    _generation++;
    _schedule = null;
    _safeRecord = null;
    _emit(_state.copyWith(status: ReminderSettingsStatus.locked));
  }

  void _updateDraft({
    ReminderOffset? offset,
    int? preferredMinute,
    ReminderQuietHours? quietHours,
    ReminderPrivacy? privacy,
  }) {
    final schedule = _schedule;
    if (schedule == null) return;
    final updated = schedule.copyWith(
      offset: offset,
      preferredMinute: preferredMinute,
      quietHours: quietHours,
      privacy: privacy,
    );
    _schedule = updated;
    _emit(
      _state.copyWith(
        status: ReminderSettingsStatus.editing,
        offsetMinutes: updated.offset.minutes,
        preferredMinute: updated.preferredMinute,
        quietStartMinute: updated.quietHours.startMinute,
        quietEndMinute: updated.quietHours.endMinute,
        privacy: updated.privacy,
      ),
    );
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _emit(ReminderSettingsState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _schedule = null;
    _safeRecord = null;
    super.dispose();
  }
}

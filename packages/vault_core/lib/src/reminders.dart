// SPDX-License-Identifier: MPL-2.0

import 'errors.dart';
import 'identifiers.dart';
import 'models.dart';
import 'record_listing.dart';

enum ReminderPrivacy { private, safeName, safeNameAndAmount }

enum ReminderScheduleState { disabled, enabled, entitlementSuspended }

enum ReminderNotificationAction { open, snooze }

enum ReminderWallClockResolutionKind {
  unique,
  overlapEarlier,
  overlapLater,
  gapAdjustedForward,
}

abstract final class GenericReminderEligibility {
  static const Map<String, Set<String>> _reviewedExpiryFields = {
    BuiltInRecordTypes.paymentCard: {'expiry'},
    BuiltInRecordTypes.identityDocument: {'expires'},
    BuiltInRecordTypes.softwareLicense: {'expires'},
    BuiltInRecordTypes.apiCredential: {'expires'},
    BuiltInRecordTypes.sshCredential: {'valid_until'},
  };

  static bool supports(
    String typeId,
    VaultField field, {
    bool explicitlySelectedByUser = false,
  }) {
    if (field.kind != VaultFieldKind.date || !field.hasUserValue) return false;
    if (explicitlySelectedByUser) return true;
    return _reviewedExpiryFields[typeId]?.contains(field.definitionId) ?? false;
  }
}

final class ReminderOffset {
  const ReminderOffset.days(int days) : minutes = days * 24 * 60;
  const ReminderOffset.minutes(this.minutes);

  static const maximumMinutes = 365 * 24 * 60;
  final int minutes;

  void validate() {
    if (minutes < 0 || minutes > maximumMinutes) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }
}

final class ReminderQuietHours {
  const ReminderQuietHours({
    required this.startMinute,
    required this.endMinute,
  });

  static const defaults = ReminderQuietHours(
    startMinute: 22 * 60,
    endMinute: 8 * 60,
  );

  final int startMinute;
  final int endMinute;

  void validate() {
    if (startMinute < 0 ||
        startMinute >= 24 * 60 ||
        endMinute < 0 ||
        endMinute >= 24 * 60 ||
        startMinute == endMinute) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  DateTime adjustCalendar(DateTime calendar) {
    validate();
    final minute = calendar.hour * 60 + calendar.minute;
    final overnight = startMinute > endMinute;
    final quiet = overnight
        ? minute >= startMinute || minute < endMinute
        : minute >= startMinute && minute < endMinute;
    if (!quiet) return calendar;
    final afterStart = overnight && minute >= startMinute;
    final date = afterStart
        ? DateTime.utc(calendar.year, calendar.month, calendar.day + 1)
        : DateTime.utc(calendar.year, calendar.month, calendar.day);
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      endMinute ~/ 60,
      endMinute % 60,
    );
  }
}

final class ReminderSchedule {
  ReminderSchedule({
    required this.id,
    required this.recordId,
    required this.fieldId,
    required this.targetDate,
    required this.offset,
    required this.preferredMinute,
    required this.timeZoneId,
    required this.quietHours,
    required this.privacy,
    required this.state,
    required this.revision,
  }) {
    offset.validate();
    quietHours.validate();
    if (!targetDate.isUtc ||
        targetDate.hour != 0 ||
        targetDate.minute != 0 ||
        targetDate.second != 0 ||
        targetDate.millisecond != 0 ||
        targetDate.microsecond != 0 ||
        preferredMinute < 0 ||
        preferredMinute >= 24 * 60 ||
        timeZoneId.isEmpty ||
        timeZoneId.length > 128 ||
        !RegExp(r'^[A-Za-z0-9._+\-/]+$').hasMatch(timeZoneId) ||
        revision < 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final ReminderId id;
  final RecordId recordId;
  final FieldId fieldId;
  final DateTime targetDate;
  final ReminderOffset offset;
  final int preferredMinute;
  final String timeZoneId;
  final ReminderQuietHours quietHours;
  final ReminderPrivacy privacy;
  final ReminderScheduleState state;
  final int revision;

  ReminderSchedule copyWith({
    DateTime? targetDate,
    ReminderOffset? offset,
    int? preferredMinute,
    String? timeZoneId,
    ReminderQuietHours? quietHours,
    ReminderPrivacy? privacy,
    ReminderScheduleState? state,
    int? revision,
  }) => ReminderSchedule(
    id: id,
    recordId: recordId,
    fieldId: fieldId,
    targetDate: targetDate ?? this.targetDate,
    offset: offset ?? this.offset,
    preferredMinute: preferredMinute ?? this.preferredMinute,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    quietHours: quietHours ?? this.quietHours,
    privacy: privacy ?? this.privacy,
    state: state ?? this.state,
    revision: revision ?? this.revision,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id.value,
    'recordId': recordId.value,
    'fieldId': fieldId.value,
    'targetDate': targetDate.toIso8601String(),
    'offsetMinutes': offset.minutes,
    'preferredMinute': preferredMinute,
    'timeZoneId': timeZoneId,
    'quietStartMinute': quietHours.startMinute,
    'quietEndMinute': quietHours.endMinute,
    'privacy': privacy.name,
    'state': state.name,
    'revision': revision,
  };

  factory ReminderSchedule.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const VaultFailure(VaultFailureCode.unsupportedVersion);
    }
    try {
      return ReminderSchedule(
        id: ReminderId.parse(json['id']! as String),
        recordId: RecordId.parse(json['recordId']! as String),
        fieldId: FieldId.parse(json['fieldId']! as String),
        targetDate: DateTime.parse(json['targetDate']! as String).toUtc(),
        offset: ReminderOffset.minutes(json['offsetMinutes']! as int),
        preferredMinute: json['preferredMinute']! as int,
        timeZoneId: json['timeZoneId']! as String,
        quietHours: ReminderQuietHours(
          startMinute: json['quietStartMinute']! as int,
          endMinute: json['quietEndMinute']! as int,
        ),
        privacy: ReminderPrivacy.values.byName(json['privacy']! as String),
        state: ReminderScheduleState.values.byName(json['state']! as String),
        revision: json['revision']! as int,
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }
}

final class ReminderWallClock {
  ReminderWallClock({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.timeZoneId,
  }) {
    final parsed = DateTime.utc(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute ||
        timeZoneId.isEmpty ||
        timeZoneId.length > 128) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String timeZoneId;
}

final class ReminderWallClockResolution {
  ReminderWallClockResolution({required this.utc, required this.kind}) {
    if (!utc.isUtc) throw const VaultFailure(VaultFailureCode.invalidInput);
  }

  final DateTime utc;
  final ReminderWallClockResolutionKind kind;
}

abstract interface class ReminderWallClockResolver {
  Future<ReminderWallClockResolution> resolve(ReminderWallClock value);
}

abstract interface class ReminderEntitlementPolicy {
  void requireSchedulingAllowed();
}

final class PremiumReminderEntitlementPolicy
    implements ReminderEntitlementPolicy {
  const PremiumReminderEntitlementPolicy();

  @override
  void requireSchedulingAllowed() {}
}

final class FreeReminderEntitlementPolicy implements ReminderEntitlementPolicy {
  const FreeReminderEntitlementPolicy();

  @override
  void requireSchedulingAllowed() {
    throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
  }
}

final class SafeNotificationAmount {
  SafeNotificationAmount(String value) : value = _sanitize(value, 64) {
    if (this.value.isEmpty) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final String value;
}

final class ReminderNotificationRequest {
  ReminderNotificationRequest({
    required this.syntheticId,
    required this.deliveryUtc,
    required this.privacy,
    required String? safeName,
    required SafeNotificationAmount? safeAmount,
    required Iterable<ReminderNotificationAction> actions,
  }) : safeName = safeName == null ? null : _sanitize(safeName, 256),
       safeAmount = safeAmount?.value,
       actions = Set.unmodifiable(actions) {
    if (!deliveryUtc.isUtc ||
        this.actions.difference(const {
          ReminderNotificationAction.open,
          ReminderNotificationAction.snooze,
        }).isNotEmpty ||
        this.actions.isEmpty ||
        (privacy == ReminderPrivacy.private &&
            (this.safeName != null || this.safeAmount != null)) ||
        (privacy == ReminderPrivacy.safeName &&
            (this.safeName == null || this.safeAmount != null)) ||
        (privacy == ReminderPrivacy.safeNameAndAmount &&
            (this.safeName == null || this.safeAmount == null))) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final ReminderId syntheticId;
  final DateTime deliveryUtc;
  final ReminderPrivacy privacy;
  final String? safeName;
  final String? safeAmount;
  final Set<ReminderNotificationAction> actions;

  @override
  String toString() =>
      'ReminderNotificationRequest(${syntheticId.value}, $deliveryUtc, '
      '${privacy.name}, $safeName, $safeAmount, '
      '${actions.map((action) => action.name).join(',')})';
}

final class ReminderPlanner {
  const ReminderPlanner();

  Future<ReminderNotificationRequest?> plan(
    ReminderSchedule schedule, {
    required DateTime nowUtc,
    required ReminderWallClockResolver resolver,
    required SafeRecordProjection safeRecord,
    SafeNotificationAmount? safeAmount,
  }) async {
    if (!nowUtc.isUtc) throw const VaultFailure(VaultFailureCode.invalidInput);
    if (safeRecord.id != schedule.recordId) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    if (schedule.state != ReminderScheduleState.enabled) return null;
    final base = DateTime.utc(
      schedule.targetDate.year,
      schedule.targetDate.month,
      schedule.targetDate.day,
      schedule.preferredMinute ~/ 60,
      schedule.preferredMinute % 60,
    ).subtract(Duration(minutes: schedule.offset.minutes));
    final adjusted = schedule.quietHours.adjustCalendar(base);
    final resolved = await resolver.resolve(
      ReminderWallClock(
        year: adjusted.year,
        month: adjusted.month,
        day: adjusted.day,
        hour: adjusted.hour,
        minute: adjusted.minute,
        timeZoneId: schedule.timeZoneId,
      ),
    );
    if (!resolved.utc.isAfter(nowUtc)) return null;
    return ReminderNotificationRequest(
      syntheticId: schedule.id,
      deliveryUtc: resolved.utc,
      privacy: schedule.privacy,
      safeName: switch (schedule.privacy) {
        ReminderPrivacy.private => null,
        ReminderPrivacy.safeName ||
        ReminderPrivacy.safeNameAndAmount => safeRecord.displayName,
      },
      safeAmount: schedule.privacy == ReminderPrivacy.safeNameAndAmount
          ? safeAmount
          : null,
      actions: const {
        ReminderNotificationAction.open,
        ReminderNotificationAction.snooze,
      },
    );
  }
}

String _sanitize(String value, int maximumLength) {
  final clean = value.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ').trim();
  return clean.length > maximumLength
      ? clean.substring(0, maximumLength)
      : clean;
}

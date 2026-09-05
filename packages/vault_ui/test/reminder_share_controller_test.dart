// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  test('reminder controller explains before requesting permission', () async {
    final permissions = _Permissions(NotificationPermissionState.authorized);
    final controller = ReminderSettingsController(
      schedule: _schedule(),
      safeRecord: _safeRecord(),
      coordinator: _coordinator(permissions: permissions),
      now: () => DateTime.utc(2026, 9, 5),
    );
    addTearDown(controller.dispose);

    controller.beginEnable();

    expect(controller.state.status, ReminderSettingsStatus.explanation);
    expect(permissions.statusCalls, 0);
  });

  test('denial remains a disabled draft with a settings action', () async {
    final configurations = _Configurations();
    final controller = ReminderSettingsController(
      schedule: _schedule(),
      safeRecord: _safeRecord(),
      coordinator: _coordinator(
        permissions: _Permissions(NotificationPermissionState.denied),
        configurations: configurations,
      ),
      now: () => DateTime.utc(2026, 9, 5),
    );
    addTearDown(controller.dispose);
    controller.beginEnable();

    await controller.confirmEnable();

    expect(controller.state.status, ReminderSettingsStatus.permissionDenied);
    expect(configurations.values.single.state, ReminderScheduleState.disabled);
  });

  test('lock clears reminder settings and ignores late activation', () async {
    final completer = Completer<NotificationPermissionState>();
    final permissions = _Permissions(
      NotificationPermissionState.notDetermined,
      requestCallback: () => completer.future,
    );
    final controller = ReminderSettingsController(
      schedule: _schedule(),
      safeRecord: _safeRecord(),
      coordinator: _coordinator(permissions: permissions),
      now: () => DateTime.utc(2026, 9, 5),
    );
    addTearDown(controller.dispose);
    controller.beginEnable();

    final pending = controller.confirmEnable();
    controller.onBackgroundOrLock();
    completer.complete(NotificationPermissionState.authorized);
    await pending;

    expect(controller.state.status, ReminderSettingsStatus.locked);
  });

  test(
    'share controller state has descriptors but never payload bytes',
    () async {
      final descriptor = _descriptor();
      final staging = _Staging(descriptor, [115, 101, 99, 114, 101, 116]);
      final controller = InboundShareController(
        staging: staging,
        coordinator: InboundShareCoordinator(
          staging: staging,
          encryptedDraftSink: _DraftSink(),
        ),
        now: () => DateTime.utc(2026, 9, 5, 12),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.descriptors, [descriptor]);
      expect(controller.state.toString(), isNot(contains('secret')));
    },
  );

  test(
    'share controller imports then removes the pending descriptor',
    () async {
      final descriptor = _descriptor();
      final staging = _Staging(descriptor, [1, 2, 3, 4, 5, 6]);
      final controller = InboundShareController(
        staging: staging,
        coordinator: InboundShareCoordinator(
          staging: staging,
          encryptedDraftSink: _DraftSink(),
        ),
        now: () => DateTime.utc(2026, 9, 5, 12),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.import(descriptor.id);

      expect(controller.state.status, InboundShareViewStatus.imported);
      expect(controller.state.descriptors, isEmpty);
      expect(staging.deleted, isTrue);
    },
  );
}

ReminderCoordinator _coordinator({
  required _Permissions permissions,
  _Configurations? configurations,
}) => ReminderCoordinator(
  configurations: configurations ?? _Configurations(),
  planner: const ReminderPlanner(),
  resolver: _Resolver(),
  permissions: permissions,
  scheduler: _Scheduler(),
);

ReminderSchedule _schedule() => ReminderSchedule(
  id: ReminderId.generate(),
  recordId: _recordId,
  fieldId: FieldId.generate(),
  targetDate: DateTime.utc(2027, 1, 1),
  offset: const ReminderOffset.days(1),
  preferredMinute: 9 * 60,
  timeZoneId: 'Europe/Moscow',
  quietHours: ReminderQuietHours.defaults,
  privacy: ReminderPrivacy.private,
  state: ReminderScheduleState.disabled,
  revision: 1,
);

SafeRecordProjection _safeRecord() => SafeRecordProjection(
  id: _recordId,
  typeId: BuiltInRecordTypes.account,
  displayName: 'Safe record',
  secondary: null,
  favorite: false,
  pinned: false,
  lifecycle: RecordLifecycle.active,
  folderId: null,
  folderName: null,
  tagIds: const {},
  tagNames: const [],
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

final _recordId = RecordId.parse('AAAAAAAAAAAAAAAAAAAAAA');

final class _Permissions implements NotificationPermissionPort {
  _Permissions(this.value, {this.requestCallback});
  NotificationPermissionState value;
  final Future<NotificationPermissionState> Function()? requestCallback;
  int statusCalls = 0;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<NotificationPermissionState> request() async {
    value = await (requestCallback?.call() ?? Future.value(value));
    return value;
  }

  @override
  Future<NotificationPermissionState> status() async {
    statusCalls++;
    return value;
  }
}

final class _Configurations implements ReminderConfigurationPort {
  final List<ReminderSchedule> values = [];

  @override
  Future<ReminderSchedule> create(ReminderSchedule schedule) async {
    values.add(schedule);
    return schedule;
  }

  @override
  Future<ReminderLoadSnapshot> loadAll() async =>
      ReminderLoadSnapshot(schedules: values, quarantinedObjectIds: const []);

  @override
  Future<ReminderSchedule?> read(ReminderId id) async =>
      values.where((value) => value.id == id).firstOrNull;

  @override
  Future<List<ReminderSchedule>> suspendEnabled() async => const [];

  @override
  Future<ReminderSchedule> update({
    required ReminderSchedule proposed,
    required int expectedRevision,
  }) async {
    final index = values.indexWhere((value) => value.id == proposed.id);
    final saved = proposed.copyWith(revision: expectedRevision + 1);
    values[index] = saved;
    return saved;
  }
}

final class _Resolver implements ReminderWallClockResolver {
  @override
  Future<ReminderWallClockResolution> resolve(ReminderWallClock value) async =>
      ReminderWallClockResolution(
        utc: DateTime.utc(value.year, value.month, value.day, 6),
        kind: ReminderWallClockResolutionKind.unique,
      );
}

final class _Scheduler implements ReminderSchedulerPort {
  @override
  Future<void> cancel(ReminderId id) async {}

  @override
  Future<void> replace(ReminderNotificationRequest request) async {}
}

InboundShareDescriptor _descriptor() => InboundShareDescriptor(
  id: PendingShareId.generate(),
  kind: InboundShareKind.text,
  byteLength: 6,
  receivedAt: DateTime.utc(2026, 9, 5),
  expiresAt: DateTime.utc(2026, 9, 6),
);

final class _Staging implements InboundShareStagingPort {
  _Staging(this.descriptor, this.bytes);
  final InboundShareDescriptor descriptor;
  final List<int> bytes;
  bool deleted = false;

  @override
  Future<void> delete(PendingShareId id) async => deleted = true;

  @override
  Future<List<InboundShareDescriptor>> list() async =>
      deleted ? [] : [descriptor];

  @override
  Stream<List<int>> open(PendingShareId id) => Stream.value(bytes);

  @override
  Future<void> purgeExpired(DateTime now) async {}
}

final class _DraftSink implements EncryptedInboundDraftSink {
  @override
  Future<DraftId> createFromShare({
    required InboundShareKind kind,
    required int byteLength,
    required Stream<List<int>> plaintext,
  }) async {
    await plaintext.expand((value) => value).drain<void>();
    return DraftId.generate();
  }
}

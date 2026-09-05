// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('reminder planning', () {
    test('generic eligibility is reviewed or explicitly selected', () {
      final expiry = VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.date,
        label: 'Expiry',
        value: '2027-01-01',
        definitionId: 'expiry',
      );
      final custom = VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.date,
        label: 'Custom date',
        value: '2027-01-01',
      );

      expect(
        GenericReminderEligibility.supports(
          BuiltInRecordTypes.paymentCard,
          expiry,
        ),
        isTrue,
      );
      expect(
        GenericReminderEligibility.supports(BuiltInRecordTypes.account, custom),
        isFalse,
      );
      expect(
        GenericReminderEligibility.supports(
          BuiltInRecordTypes.account,
          custom,
          explicitlySelectedByUser: true,
        ),
        isTrue,
      );
    });

    test(
      'subtracts calendar days and keeps the approved local default',
      () async {
        final resolver = _Resolver(DateTime.utc(2026, 3, 29, 6));
        final schedule = _schedule(
          targetDate: DateTime.utc(2026, 3, 30),
          offset: const ReminderOffset.days(1),
        );

        final request = await ReminderPlanner().plan(
          schedule,
          nowUtc: DateTime.utc(2026, 3, 1),
          resolver: resolver,
          safeRecord: _safeRecord(),
        );

        expect(resolver.last!.year, 2026);
        expect(resolver.last!.month, 3);
        expect(resolver.last!.day, 29);
        expect(resolver.last!.hour, 9);
        expect(request!.deliveryUtc, DateTime.utc(2026, 3, 29, 6));
      },
    );

    test('moves a quiet-hours wall clock to the next quiet end', () async {
      final resolver = _Resolver(DateTime.utc(2026, 4, 1, 5));
      final schedule = _schedule(
        targetDate: DateTime.utc(2026, 3, 31),
        preferredMinute: 23 * 60,
      );

      await ReminderPlanner().plan(
        schedule,
        nowUtc: DateTime.utc(2026, 3, 1),
        resolver: resolver,
        safeRecord: _safeRecord(),
      );

      expect(resolver.last!.day, 1);
      expect(resolver.last!.hour, 8);
    });

    test('does not plan a delivery in the past', () async {
      final request = await ReminderPlanner().plan(
        _schedule(targetDate: DateTime.utc(2026, 1, 1)),
        nowUtc: DateTime.utc(2026, 2, 1),
        resolver: _Resolver(DateTime.utc(2026, 1, 1, 6)),
        safeRecord: _safeRecord(),
      );

      expect(request, isNull);
    });

    test(
      'safe OS request has no vault, record, field or secret value',
      () async {
        final schedule = _schedule(
          targetDate: DateTime.utc(2026, 12, 1),
          privacy: ReminderPrivacy.safeName,
        );
        final request = await ReminderPlanner().plan(
          schedule,
          nowUtc: DateTime.utc(2026, 1, 1),
          resolver: _Resolver(DateTime.utc(2026, 12, 1, 6)),
          safeRecord: _safeRecord(),
        );
        final rendered = request.toString();

        expect(rendered, contains('Safe account'));
        expect(rendered, isNot(contains(schedule.recordId.value)));
        expect(rendered, isNot(contains(schedule.fieldId.value)));
        expect(rendered, isNot(contains('secret-canary')));
        expect(request!.actions, {
          ReminderNotificationAction.open,
          ReminderNotificationAction.snooze,
        });
      },
    );

    test('rejects a safe projection from a different record', () async {
      final other = SafeRecordProjection(
        id: RecordId.generate(),
        typeId: BuiltInRecordTypes.account,
        displayName: 'Wrong record',
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

      await expectLater(
        ReminderPlanner().plan(
          _schedule(targetDate: DateTime.utc(2026, 12, 1)),
          nowUtc: DateTime.utc(2026, 1, 1),
          resolver: _Resolver(DateTime.utc(2026, 12, 1, 6)),
          safeRecord: other,
        ),
        throwsA(isA<VaultFailure>()),
      );
    });

    test('Free policy rejects new scheduling without changing dates', () {
      final schedule = _schedule(targetDate: DateTime.utc(2026, 12, 1));

      expect(
        () => const FreeReminderEntitlementPolicy().requireSchedulingAllowed(),
        throwsA(isA<VaultFailure>()),
      );
      expect(schedule.targetDate, DateTime.utc(2026, 12, 1));
    });

    test('permission is requested only after the explanation', () async {
      final permissions = _Permissions(
        NotificationPermissionState.notDetermined,
      );
      final configurations = _Configurations();
      final coordinator = ReminderCoordinator(
        configurations: configurations,
        planner: const ReminderPlanner(),
        resolver: _Resolver(DateTime.utc(2026, 12, 1, 6)),
        permissions: permissions,
        scheduler: _Scheduler(),
      );

      final result = await coordinator.enable(
        schedule: _schedule(targetDate: DateTime.utc(2026, 12, 1)),
        nowUtc: DateTime.utc(2026, 1, 1),
        safeRecord: _safeRecord(),
        explanationAccepted: false,
      );

      expect(result.status, ReminderActivationStatus.explanationRequired);
      expect(permissions.requestCount, 0);
      expect(configurations.values, isEmpty);
    });

    test(
      'permission denial preserves a disabled encrypted configuration',
      () async {
        final permissions = _Permissions(
          NotificationPermissionState.notDetermined,
          requested: NotificationPermissionState.denied,
        );
        final configurations = _Configurations();
        final scheduler = _Scheduler();
        final coordinator = ReminderCoordinator(
          configurations: configurations,
          planner: const ReminderPlanner(),
          resolver: _Resolver(DateTime.utc(2026, 12, 1, 6)),
          permissions: permissions,
          scheduler: scheduler,
        );

        final result = await coordinator.enable(
          schedule: _schedule(targetDate: DateTime.utc(2026, 12, 1)),
          nowUtc: DateTime.utc(2026, 1, 1),
          safeRecord: _safeRecord(),
          explanationAccepted: true,
        );

        expect(result.status, ReminderActivationStatus.permissionDenied);
        expect(
          configurations.values.single.state,
          ReminderScheduleState.disabled,
        );
        expect(scheduler.requests, isEmpty);
      },
    );

    test('scheduler replace is idempotent by synthetic reminder ID', () async {
      final schedule = _schedule(targetDate: DateTime.utc(2026, 12, 1));
      final configurations = _Configurations();
      final scheduler = _Scheduler();
      final coordinator = ReminderCoordinator(
        configurations: configurations,
        planner: const ReminderPlanner(),
        resolver: _Resolver(DateTime.utc(2026, 12, 1, 6)),
        permissions: _Permissions(NotificationPermissionState.authorized),
        scheduler: scheduler,
      );

      await coordinator.enable(
        schedule: schedule,
        nowUtc: DateTime.utc(2026, 1, 1),
        safeRecord: _safeRecord(),
        explanationAccepted: true,
      );
      await coordinator.enable(
        schedule: configurations.values.single,
        nowUtc: DateTime.utc(2026, 1, 1),
        safeRecord: _safeRecord(),
        explanationAccepted: true,
      );

      expect(scheduler.requests, hasLength(1));
      expect(scheduler.requests.values.single.syntheticId, schedule.id);
    });
  });

  group('share and launcher boundary', () {
    test('launcher allowlist has only Add, Search and Lock', () {
      expect(LauncherShortcutAction.values, [
        LauncherShortcutAction.add,
        LauncherShortcutAction.search,
        LauncherShortcutAction.lock,
      ]);
      expect(LauncherShortcutAction.values.map((action) => action.safeId), [
        'localhold.add',
        'localhold.search',
        'localhold.lock',
      ]);
    });

    test('pending descriptor enforces inline and staging bounds', () {
      expect(
        () => _descriptor(
          kind: InboundShareKind.text,
          bytes: InboundShareLimits.maximumInlineBytes + 1,
        ),
        throwsA(isA<VaultFailure>()),
      );
      expect(
        () => _descriptor(
          kind: InboundShareKind.file,
          bytes: InboundShareLimits.maximumStagedFileBytes + 1,
        ),
        throwsA(isA<VaultFailure>()),
      );
      final descriptor = _descriptor(kind: InboundShareKind.image, bytes: 42);
      expect(descriptor.toString(), isNot(contains('filename')));
    });

    test(
      'share materializer streams into encrypted sink and clears staging',
      () async {
        final descriptor = _descriptor(kind: InboundShareKind.text, bytes: 5);
        final staging = _Staging(descriptor, utf8.encode('hello'));
        final sink = _Sink();

        final result = await InboundShareCoordinator(
          staging: staging,
          encryptedDraftSink: sink,
        ).consume(descriptor, now: DateTime.utc(2026, 9, 5, 12));

        expect(result.status, InboundShareStatus.imported);
        expect(result.draftId, isNotNull);
        expect(sink.bytes, utf8.encode('hello'));
        expect(staging.deleted, isTrue);
      },
    );

    test(
      'expired or failed share leaves no staging and no partial result',
      () async {
        final descriptor = _descriptor(
          kind: InboundShareKind.file,
          bytes: 5,
          expiresAt: DateTime.utc(2026, 9, 5, 11),
        );
        final staging = _Staging(descriptor, [1, 2, 3, 4, 5]);
        final sink = _Sink(fail: true);
        final coordinator = InboundShareCoordinator(
          staging: staging,
          encryptedDraftSink: sink,
        );

        final expired = await coordinator.consume(
          descriptor,
          now: DateTime.utc(2026, 9, 5, 12),
        );

        expect(expired.status, InboundShareStatus.expired);
        expect(expired.draftId, isNull);
        expect(staging.deleted, isTrue);
      },
    );
  });
}

ReminderSchedule _schedule({
  required DateTime targetDate,
  ReminderOffset offset = const ReminderOffset.days(0),
  int preferredMinute = 9 * 60,
  ReminderPrivacy privacy = ReminderPrivacy.private,
}) => ReminderSchedule(
  id: ReminderId.generate(),
  recordId: _recordId,
  fieldId: FieldId.generate(),
  targetDate: targetDate,
  offset: offset,
  preferredMinute: preferredMinute,
  timeZoneId: 'Europe/Moscow',
  quietHours: const ReminderQuietHours(startMinute: 22 * 60, endMinute: 8 * 60),
  privacy: privacy,
  state: ReminderScheduleState.enabled,
  revision: 1,
);

SafeRecordProjection _safeRecord() => SafeRecordProjection(
  id: _recordId,
  typeId: BuiltInRecordTypes.account,
  displayName: 'Safe account',
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

final class _Resolver implements ReminderWallClockResolver {
  _Resolver(this.value);

  final DateTime value;
  ReminderWallClock? last;

  @override
  Future<ReminderWallClockResolution> resolve(ReminderWallClock value) async {
    last = value;
    return ReminderWallClockResolution(
      utc: this.value,
      kind: ReminderWallClockResolutionKind.unique,
    );
  }
}

final class _Permissions implements NotificationPermissionPort {
  _Permissions(this.value, {NotificationPermissionState? requested})
    : requested = requested ?? value;

  NotificationPermissionState value;
  final NotificationPermissionState requested;
  int requestCount = 0;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<NotificationPermissionState> request() async {
    requestCount++;
    value = requested;
    return value;
  }

  @override
  Future<NotificationPermissionState> status() async => value;
}

final class _Scheduler implements ReminderSchedulerPort {
  final Map<String, ReminderNotificationRequest> requests = {};

  @override
  Future<void> cancel(ReminderId id) async => requests.remove(id.value);

  @override
  Future<void> replace(ReminderNotificationRequest request) async {
    requests[request.syntheticId.value] = request;
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
  Future<List<ReminderSchedule>> suspendEnabled() async {
    final changed = <ReminderSchedule>[];
    for (var index = 0; index < values.length; index++) {
      if (values[index].state != ReminderScheduleState.enabled) continue;
      values[index] = values[index].copyWith(
        state: ReminderScheduleState.entitlementSuspended,
        revision: values[index].revision + 1,
      );
      changed.add(values[index]);
    }
    return changed;
  }

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

InboundShareDescriptor _descriptor({
  required InboundShareKind kind,
  required int bytes,
  DateTime? expiresAt,
}) => InboundShareDescriptor(
  id: PendingShareId.generate(),
  kind: kind,
  byteLength: bytes,
  receivedAt: DateTime.utc(2026, 9, 5),
  expiresAt: expiresAt ?? DateTime.utc(2026, 9, 6),
);

final class _Staging implements InboundShareStagingPort {
  _Staging(this.descriptor, this.value);

  final InboundShareDescriptor descriptor;
  final List<int> value;
  bool deleted = false;

  @override
  Future<void> delete(PendingShareId id) async {
    deleted = true;
  }

  @override
  Future<List<InboundShareDescriptor>> list() async => [descriptor];

  @override
  Stream<List<int>> open(PendingShareId id) => Stream.value(value);

  @override
  Future<void> purgeExpired(DateTime now) async {}
}

final class _Sink implements EncryptedInboundDraftSink {
  _Sink({this.fail = false});

  final bool fail;
  List<int> bytes = const [];

  @override
  Future<DraftId> createFromShare({
    required InboundShareKind kind,
    required int byteLength,
    required Stream<List<int>> plaintext,
  }) async {
    bytes = await plaintext.expand((chunk) => chunk).toList();
    if (fail) throw const VaultFailure(VaultFailureCode.internalFailure);
    return DraftId.generate();
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  testWidgets(
    'reminder explains before permission at 320 px and 200% Russian',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.reset);
      final permissions = _Permissions(NotificationPermissionState.authorized);
      final controller = ReminderSettingsController(
        schedule: _schedule(),
        safeRecord: _safeRecord(),
        coordinator: _coordinator(permissions),
        now: () => DateTime.utc(2026, 9, 5),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _app(
          locale: const Locale('ru'),
          textScale: 2,
          home: ReminderSettingsScreen(controller: controller),
        ),
      );
      expect(find.text('Включить напоминание'), findsOneWidget);
      controller.beginEnable();
      await tester.pump();

      expect(find.text('Разрешение на уведомления'), findsOneWidget);
      expect(permissions.statusCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied permission offers system settings without losing draft', (
    tester,
  ) async {
    final permissions = _Permissions(NotificationPermissionState.denied);
    final controller = ReminderSettingsController(
      schedule: _schedule(),
      safeRecord: _safeRecord(),
      coordinator: _coordinator(permissions),
      now: () => DateTime.utc(2026, 9, 5),
    );
    addTearDown(controller.dispose);
    controller.beginEnable();
    await controller.confirmEnable();

    await tester.pumpWidget(
      _app(home: ReminderSettingsScreen(controller: controller)),
    );

    expect(find.text('Open system settings'), findsOneWidget);
    await tester.tap(find.text('Open system settings'));
    expect(permissions.settingsCalls, 1);
  });

  testWidgets('share inbox exposes descriptor metadata but no payload', (
    tester,
  ) async {
    final descriptor = _descriptor();
    final staging = _Staging(descriptor, 'secret-payload-canary'.codeUnits);
    final controller = InboundShareController(
      staging: staging,
      coordinator: InboundShareCoordinator(
        staging: staging,
        encryptedDraftSink: _DraftSink(),
      ),
      now: () => DateTime.utc(2026, 9, 5, 12),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(home: InboundShareScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shared text'), findsOneWidget);
    expect(find.textContaining('secret-payload-canary'), findsNothing);
    expect(find.text('Import as encrypted draft'), findsOneWidget);
  });
}

Widget _app({
  required Widget home,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: LocalholdLocalizations.supportedLocales,
  localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
  theme: LocalholdTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

ReminderCoordinator _coordinator(_Permissions permissions) =>
    ReminderCoordinator(
      configurations: _Configurations(),
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
  _Permissions(this.value);
  NotificationPermissionState value;
  int statusCalls = 0;
  int settingsCalls = 0;

  @override
  Future<void> openSystemSettings() async => settingsCalls++;

  @override
  Future<NotificationPermissionState> request() async => value;

  @override
  Future<NotificationPermissionState> status() async {
    statusCalls++;
    return value;
  }
}

final class _Configurations implements ReminderConfigurationPort {
  ReminderSchedule? value;

  @override
  Future<ReminderSchedule> create(ReminderSchedule schedule) async =>
      value = schedule;

  @override
  Future<ReminderLoadSnapshot> loadAll() async => ReminderLoadSnapshot(
    schedules: value == null ? const [] : [value!],
    quarantinedObjectIds: const [],
  );

  @override
  Future<ReminderSchedule?> read(ReminderId id) async => value;

  @override
  Future<List<ReminderSchedule>> suspendEnabled() async => const [];

  @override
  Future<ReminderSchedule> update({
    required ReminderSchedule proposed,
    required int expectedRevision,
  }) async => value = proposed.copyWith(revision: expectedRevision + 1);
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
  byteLength: 'secret-payload-canary'.length,
  receivedAt: DateTime.utc(2026, 9, 5),
  expiresAt: DateTime.utc(2026, 9, 6),
);

final class _Staging implements InboundShareStagingPort {
  _Staging(this.descriptor, this.bytes);
  final InboundShareDescriptor descriptor;
  final List<int> bytes;

  @override
  Future<void> delete(PendingShareId id) async {}

  @override
  Future<List<InboundShareDescriptor>> list() async => [descriptor];

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
    await plaintext.drain<void>();
    return DraftId.generate();
  }
}

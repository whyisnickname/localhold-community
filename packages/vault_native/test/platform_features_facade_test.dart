// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_native/localhold_vault_native.dart';

void main() {
  test('reminder bridge forwards only the closed safe projection', () async {
    final transport = _Transport();
    final bridge = LocalholdPlatformFeatures(transport: transport);
    final id = ReminderId.generate();

    await bridge.replace(
      ReminderNotificationRequest(
        syntheticId: id,
        deliveryUtc: DateTime.utc(2027, 1, 1),
        privacy: ReminderPrivacy.private,
        safeName: null,
        safeAmount: null,
        actions: const {
          ReminderNotificationAction.open,
          ReminderNotificationAction.snooze,
        },
      ),
    );

    expect(transport.reminder?.syntheticId, id.value);
    expect(transport.reminder?.safeName, isNull);
    expect(transport.reminder?.safeAmount, isNull);
    expect(transport.reminder.toString(), isNot(contains('recordId')));
  });

  test('wall clock resolution rejects a malformed native instant', () async {
    final transport = _Transport()
      ..wallClock = WallClockReply(
        utcEpochMilliseconds: -1,
        resolution: WallClockResolutionCode.unique,
      );
    final bridge = LocalholdPlatformFeatures(transport: transport);

    await expectLater(
      bridge.resolve(
        ReminderWallClock(
          year: 2027,
          month: 1,
          day: 1,
          hour: 9,
          minute: 0,
          timeZoneId: 'Europe/Moscow',
        ),
      ),
      throwsA(isA<PlatformFeatureFailure>()),
    );
  });

  test('inbound staging streams bounded chunks in exact order', () async {
    final transport = _Transport()
      ..shareBytes = Uint8List.fromList(
        List<int>.generate(70000, (i) => i % 251),
      );
    final staging = LocalholdPlatformFeatures(transport: transport);
    final descriptor = (await staging.list()).single;

    final result = await staging
        .open(descriptor.id)
        .expand((value) => value)
        .toList();

    expect(result, transport.shareBytes);
    expect(transport.maximumChunkRequested, 64 * 1024);
  });

  test('unknown native error is a secret-free closed failure', () async {
    final transport = _Transport()
      ..permission = NotificationPermissionReply(
        state: NotificationPermissionCode.denied,
        error: PlatformFeatureErrorCode.internalFailure,
      );
    final bridge = LocalholdPlatformFeatures(transport: transport);

    await expectLater(
      bridge.status(),
      throwsA(
        predicate(
          (value) =>
              value is PlatformFeatureFailure &&
              !value.toString().contains('secret-canary'),
        ),
      ),
    );
  });
}

final class _Transport implements PlatformFeaturesTransport {
  SafeReminderRequest? reminder;
  WallClockReply? wallClock;
  Uint8List shareBytes = Uint8List.fromList([1, 2, 3]);
  int maximumChunkRequested = 0;
  NotificationPermissionReply permission = NotificationPermissionReply(
    state: NotificationPermissionCode.authorized,
  );

  @override
  Future<FeatureStatusReply> cancelReminder(String syntheticId) async =>
      FeatureStatusReply();

  @override
  Future<LauncherActionReply> consumeLauncherAction() async =>
      LauncherActionReply(actionCode: 0);

  @override
  Future<FeatureStatusReply> deleteInboundShare(String id) async =>
      FeatureStatusReply();

  @override
  Future<FeatureStatusReply> installLauncherShortcuts() async =>
      FeatureStatusReply();

  @override
  Future<InboundShareListReply> listInboundShares() async =>
      InboundShareListReply(
        items: [
          InboundShareDescriptorReply(
            id: PendingShareId.generate().value,
            kind: ShareKindCode.file,
            byteLength: shareBytes.length,
            receivedUtcEpochMilliseconds: DateTime.utc(
              2026,
              9,
              5,
            ).millisecondsSinceEpoch,
            expiresUtcEpochMilliseconds: DateTime.utc(
              2026,
              9,
              6,
            ).millisecondsSinceEpoch,
          ),
        ],
      );

  @override
  Future<NotificationPermissionReply> notificationPermissionStatus() async =>
      permission;

  @override
  Future<FeatureStatusReply> openNotificationSettings() async =>
      FeatureStatusReply();

  @override
  Future<FeatureStatusReply> purgeExpiredInboundShares(
    int nowUtcEpochMilliseconds,
  ) async => FeatureStatusReply();

  @override
  Future<InboundShareChunkReply> readInboundShareChunk(
    InboundShareChunkRequest request,
  ) async {
    maximumChunkRequested = request.maximumBytes;
    final end = (request.offset + request.maximumBytes).clamp(
      0,
      shareBytes.length,
    );
    return InboundShareChunkReply(
      bytes: Uint8List.fromList(shareBytes.sublist(request.offset, end)),
      done: end == shareBytes.length,
    );
  }

  @override
  Future<FeatureStatusReply> replaceReminder(
    SafeReminderRequest request,
  ) async {
    reminder = request;
    return FeatureStatusReply();
  }

  @override
  Future<NotificationPermissionReply> requestNotificationPermission() async =>
      permission;

  @override
  Future<WallClockReply> resolveWallClock(WallClockRequest request) async =>
      wallClock ??
      WallClockReply(
        utcEpochMilliseconds: DateTime.utc(
          request.year,
          request.month,
          request.day,
          request.hour,
          request.minute,
        ).millisecondsSinceEpoch,
        resolution: WallClockResolutionCode.unique,
      );
}

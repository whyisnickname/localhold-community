// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'key_bridge_messages.g.dart';

const _maximumChunkBytes = 64 * 1024;

final class PlatformFeatureFailure implements Exception {
  const PlatformFeatureFailure(this.code);

  final PlatformFeatureErrorCode code;

  @override
  String toString() => 'PlatformFeatureFailure(${code.name})';
}

abstract interface class PlatformFeaturesTransport {
  Future<NotificationPermissionReply> notificationPermissionStatus();
  Future<NotificationPermissionReply> requestNotificationPermission();
  Future<FeatureStatusReply> openNotificationSettings();
  Future<WallClockReply> resolveWallClock(WallClockRequest request);
  Future<FeatureStatusReply> replaceReminder(SafeReminderRequest request);
  Future<FeatureStatusReply> cancelReminder(String syntheticId);
  Future<FeatureStatusReply> installLauncherShortcuts();
  Future<LauncherActionReply> consumeLauncherAction();
  Future<InboundShareListReply> listInboundShares();
  Future<InboundShareChunkReply> readInboundShareChunk(
    InboundShareChunkRequest request,
  );
  Future<FeatureStatusReply> deleteInboundShare(String id);
  Future<FeatureStatusReply> purgeExpiredInboundShares(
    int nowUtcEpochMilliseconds,
  );
}

final class PigeonPlatformFeaturesTransport
    implements PlatformFeaturesTransport {
  PigeonPlatformFeaturesTransport([KeyBridgeHostApi? api])
    : _api = api ?? KeyBridgeHostApi();

  final KeyBridgeHostApi _api;

  @override
  Future<FeatureStatusReply> cancelReminder(String syntheticId) =>
      _api.cancelReminder(syntheticId);

  @override
  Future<FeatureStatusReply> deleteInboundShare(String id) =>
      _api.deleteInboundShare(id);

  @override
  Future<FeatureStatusReply> installLauncherShortcuts() =>
      _api.installLauncherShortcuts();

  @override
  Future<LauncherActionReply> consumeLauncherAction() =>
      _api.consumeLauncherAction();

  @override
  Future<InboundShareListReply> listInboundShares() => _api.listInboundShares();

  @override
  Future<NotificationPermissionReply> notificationPermissionStatus() =>
      _api.notificationPermissionStatus();

  @override
  Future<FeatureStatusReply> openNotificationSettings() =>
      _api.openNotificationSettings();

  @override
  Future<FeatureStatusReply> purgeExpiredInboundShares(
    int nowUtcEpochMilliseconds,
  ) => _api.purgeExpiredInboundShares(nowUtcEpochMilliseconds);

  @override
  Future<InboundShareChunkReply> readInboundShareChunk(
    InboundShareChunkRequest request,
  ) => _api.readInboundShareChunk(request);

  @override
  Future<FeatureStatusReply> replaceReminder(SafeReminderRequest request) =>
      _api.replaceReminder(request);

  @override
  Future<NotificationPermissionReply> requestNotificationPermission() =>
      _api.requestNotificationPermission();

  @override
  Future<WallClockReply> resolveWallClock(WallClockRequest request) =>
      _api.resolveWallClock(request);
}

final class LocalholdPlatformFeatures
    implements
        NotificationPermissionPort,
        ReminderSchedulerPort,
        ReminderWallClockResolver,
        InboundShareStagingPort {
  LocalholdPlatformFeatures({PlatformFeaturesTransport? transport})
    : _transport = transport ?? PigeonPlatformFeaturesTransport();

  final PlatformFeaturesTransport _transport;

  @override
  Future<NotificationPermissionState> status() async =>
      _permission(await _guard(_transport.notificationPermissionStatus));

  @override
  Future<NotificationPermissionState> request() async =>
      _permission(await _guard(_transport.requestNotificationPermission));

  @override
  Future<void> openSystemSettings() async {
    _status(await _guard(_transport.openNotificationSettings));
  }

  @override
  Future<ReminderWallClockResolution> resolve(ReminderWallClock value) async {
    final reply = await _guard(
      () => _transport.resolveWallClock(
        WallClockRequest(
          year: value.year,
          month: value.month,
          day: value.day,
          hour: value.hour,
          minute: value.minute,
          timeZoneId: value.timeZoneId,
        ),
      ),
    );
    _throwError(reply.error);
    if (reply.utcEpochMilliseconds <= 0) {
      throw const PlatformFeatureFailure(
        PlatformFeatureErrorCode.internalFailure,
      );
    }
    return ReminderWallClockResolution(
      utc: DateTime.fromMillisecondsSinceEpoch(
        reply.utcEpochMilliseconds,
        isUtc: true,
      ),
      kind: switch (reply.resolution) {
        WallClockResolutionCode.unique =>
          ReminderWallClockResolutionKind.unique,
        WallClockResolutionCode.earlier =>
          ReminderWallClockResolutionKind.overlapEarlier,
        WallClockResolutionCode.later =>
          ReminderWallClockResolutionKind.overlapLater,
        WallClockResolutionCode.gapAdjusted =>
          ReminderWallClockResolutionKind.gapAdjustedForward,
      },
    );
  }

  @override
  Future<void> replace(ReminderNotificationRequest request) async {
    final privacyCode = switch (request.privacy) {
      ReminderPrivacy.private => 0,
      ReminderPrivacy.safeName => 1,
      ReminderPrivacy.safeNameAndAmount => 2,
    };
    _status(
      await _guard(
        () => _transport.replaceReminder(
          SafeReminderRequest(
            syntheticId: request.syntheticId.value,
            utcEpochMilliseconds: request.deliveryUtc.millisecondsSinceEpoch,
            privacyCode: privacyCode,
            safeName: request.safeName,
            safeAmount: request.safeAmount,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> cancel(ReminderId id) async {
    _status(await _guard(() => _transport.cancelReminder(id.value)));
  }

  Future<void> installLauncherShortcuts() async {
    _status(await _guard(_transport.installLauncherShortcuts));
  }

  Future<LauncherShortcutAction?> consumeLauncherAction() async {
    final reply = await _guard(_transport.consumeLauncherAction);
    _throwError(reply.error);
    return switch (reply.actionCode) {
      0 => null,
      1 => LauncherShortcutAction.add,
      2 => LauncherShortcutAction.search,
      3 => LauncherShortcutAction.lock,
      _ => throw const PlatformFeatureFailure(
        PlatformFeatureErrorCode.internalFailure,
      ),
    };
  }

  @override
  Future<List<InboundShareDescriptor>> list() async {
    final reply = await _guard(_transport.listInboundShares);
    _throwError(reply.error);
    return List.unmodifiable(
      reply.items.map(
        (value) => InboundShareDescriptor(
          id: PendingShareId.parse(value.id),
          kind: switch (value.kind) {
            ShareKindCode.text => InboundShareKind.text,
            ShareKindCode.url => InboundShareKind.url,
            ShareKindCode.file => InboundShareKind.file,
            ShareKindCode.image => InboundShareKind.image,
          },
          byteLength: value.byteLength,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            value.receivedUtcEpochMilliseconds,
            isUtc: true,
          ),
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            value.expiresUtcEpochMilliseconds,
            isUtc: true,
          ),
        ),
      ),
    );
  }

  @override
  Stream<List<int>> open(PendingShareId id) async* {
    var offset = 0;
    while (true) {
      final reply = await _guard(
        () => _transport.readInboundShareChunk(
          InboundShareChunkRequest(
            id: id.value,
            offset: offset,
            maximumBytes: _maximumChunkBytes,
          ),
        ),
      );
      _throwError(reply.error);
      final bytes = Uint8List.fromList(reply.bytes);
      if (bytes.length > _maximumChunkBytes || (bytes.isEmpty && !reply.done)) {
        throw const PlatformFeatureFailure(
          PlatformFeatureErrorCode.internalFailure,
        );
      }
      if (bytes.isNotEmpty) {
        offset += bytes.length;
        yield bytes;
      }
      if (reply.done) return;
    }
  }

  @override
  Future<void> delete(PendingShareId id) async {
    _status(await _guard(() => _transport.deleteInboundShare(id.value)));
  }

  @override
  Future<void> purgeExpired(DateTime now) async {
    _status(
      await _guard(
        () => _transport.purgeExpiredInboundShares(
          now.toUtc().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  NotificationPermissionState _permission(NotificationPermissionReply reply) {
    _throwError(reply.error);
    return switch (reply.state) {
      NotificationPermissionCode.notDetermined =>
        NotificationPermissionState.notDetermined,
      NotificationPermissionCode.denied => NotificationPermissionState.denied,
      NotificationPermissionCode.restricted =>
        NotificationPermissionState.restricted,
      NotificationPermissionCode.authorized =>
        NotificationPermissionState.authorized,
    };
  }

  void _status(FeatureStatusReply reply) => _throwError(reply.error);

  void _throwError(PlatformFeatureErrorCode? error) {
    if (error != null) throw PlatformFeatureFailure(error);
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException {
      throw const PlatformFeatureFailure(
        PlatformFeatureErrorCode.internalFailure,
      );
    } on MissingPluginException {
      throw const PlatformFeatureFailure(
        PlatformFeatureErrorCode.platformUnavailable,
      );
    }
  }
}

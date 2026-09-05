// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'reminder configuration round-trips only through ciphertext service',
    () async {
      final repository = _AtomicRepository();
      final service = _service(repository);
      final schedule = _schedule();

      await service.create(schedule);
      final savedBytes = repository.values[schedule.id.value]!.envelope;

      expect(savedBytes, isNotEmpty);
      expect((await service.read(schedule.id))!.toJson(), schedule.toJson());
      expect((await service.loadAll()).schedules, hasLength(1));
    },
  );

  test('Free policy denies creating or changing a schedule', () async {
    final repository = _AtomicRepository();
    final service = EncryptedReminderService(
      repository: repository,
      cipher: const _PassThroughCipher(),
      entitlement: const FreeReminderEntitlementPolicy(),
    );

    await expectLater(
      service.create(_schedule()),
      throwsA(_failure(VaultFailureCode.capabilityUnavailable)),
    );
    expect(repository.values, isEmpty);
  });

  test(
    'stale update does not create a conflict reminder or overwrite',
    () async {
      final repository = _AtomicRepository();
      final service = _service(repository);
      final schedule = _schedule();
      await service.create(schedule);

      await expectLater(
        service.update(
          proposed: schedule.copyWith(privacy: ReminderPrivacy.safeName),
          expectedRevision: 7,
        ),
        throwsA(_failure(VaultFailureCode.revisionConflict)),
      );

      expect(
        (await service.read(schedule.id))!.privacy,
        ReminderPrivacy.private,
      );
      expect((await service.read(schedule.id))!.revision, 1);
    },
  );

  test(
    'entitlement suspension updates all enabled schedules atomically',
    () async {
      final repository = _AtomicRepository();
      final service = _service(repository);
      final first = _schedule();
      final second = _schedule();
      await service.create(first);
      await service.create(second);

      final suspended = await service.suspendEnabled();

      expect(suspended, hasLength(2));
      expect(
        (await service.loadAll()).schedules.map((value) => value.state),
        everyElement(ReminderScheduleState.entitlementSuspended),
      );
      expect(
        (await service.loadAll()).schedules.map((value) => value.revision),
        everyElement(2),
      );
    },
  );
}

EncryptedReminderService _service(CiphertextRepository repository) =>
    EncryptedReminderService(
      repository: repository,
      cipher: const _PassThroughCipher(),
      entitlement: const PremiumReminderEntitlementPolicy(),
    );

ReminderSchedule _schedule() => ReminderSchedule(
  id: ReminderId.generate(),
  recordId: RecordId.generate(),
  fieldId: FieldId.generate(),
  targetDate: DateTime.utc(2027, 1, 1),
  offset: const ReminderOffset.days(7),
  preferredMinute: 9 * 60,
  timeZoneId: 'Europe/Moscow',
  quietHours: ReminderQuietHours.defaults,
  privacy: ReminderPrivacy.private,
  state: ReminderScheduleState.enabled,
  revision: 1,
);

final class _PassThroughCipher implements PayloadCipher {
  const _PassThroughCipher();

  @override
  String get vaultId => 'AAAAAAAAAAAAAAAAAAAAAA';

  @override
  String get keyGenerationId => 'BBBBBBBBBBBBBBBBBBBBBB';

  @override
  Future<Uint8List> decrypt({
    required Uint8List envelope,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(envelope);

  @override
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List authenticatedData,
  }) async => Uint8List.fromList(plaintext);
}

final class _AtomicRepository implements AtomicCiphertextRepository {
  final Map<String, EncryptedObject> values = {};

  @override
  Future<void> create(EncryptedObject object) async {
    if (values.containsKey(object.objectId)) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Future<void> quarantine({
    required String objectId,
    required int expectedRevision,
    required VaultFailureCode reason,
  }) async => values.remove(objectId);

  @override
  Future<EncryptedObject?> read(String objectId) async => values[objectId];

  @override
  Future<List<EncryptedObject>> readAll() async => List.of(values.values);

  @override
  Future<void> remove({
    required String objectId,
    required int expectedRevision,
  }) async {
    final current = values[objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values.remove(objectId);
  }

  @override
  Future<void> replace({
    required EncryptedObject object,
    required int expectedRevision,
  }) async {
    final current = values[object.objectId];
    if (current == null || current.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    values[object.objectId] = object;
  }

  @override
  Future<void> replaceMany(
    Iterable<ExpectedEncryptedObject> replacements,
  ) async {
    final source = replacements.toList(growable: false);
    for (final replacement in source) {
      final current = values[replacement.object.objectId];
      if (current == null || current.revision != replacement.expectedRevision) {
        throw const VaultFailure(VaultFailureCode.revisionConflict);
      }
    }
    for (final replacement in source) {
      values[replacement.object.objectId] = replacement.object;
    }
  }

  @override
  Stream<List<EncryptedObject>> watchAll() =>
      Stream.value(List.of(values.values));
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((failure) => failure.code, 'code', code);

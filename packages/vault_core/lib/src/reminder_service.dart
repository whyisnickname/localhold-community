// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'document_codec.dart';
import 'document_repository.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'reminders.dart';
import 'repository.dart';
import 'vault_health.dart';

final class ReminderScheduleCodec {
  const ReminderScheduleCodec({this._documents = const VaultDocumentCodec()});

  final VaultDocumentCodec _documents;

  Uint8List encode(ReminderSchedule schedule) =>
      _documents.encode(kind: 'reminder', payload: schedule.toJson());

  ReminderSchedule decode(Uint8List bytes) {
    final document = _documents.decode(bytes);
    if (document.kind != 'reminder') {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
    return ReminderSchedule.fromJson(document.payload);
  }
}

final class ReminderLoadSnapshot {
  ReminderLoadSnapshot({
    required Iterable<ReminderSchedule> schedules,
    required Iterable<String> quarantinedObjectIds,
  }) : schedules = List.unmodifiable(schedules),
       quarantinedObjectIds = List.unmodifiable(quarantinedObjectIds);

  final List<ReminderSchedule> schedules;
  final List<String> quarantinedObjectIds;
}

abstract interface class ReminderConfigurationPort {
  Future<ReminderSchedule?> read(ReminderId id);
  Future<ReminderLoadSnapshot> loadAll();
  Future<ReminderSchedule> create(ReminderSchedule schedule);
  Future<ReminderSchedule> update({
    required ReminderSchedule proposed,
    required int expectedRevision,
  });
  Future<List<ReminderSchedule>> suspendEnabled();
}

final class EncryptedReminderService implements ReminderConfigurationPort {
  const EncryptedReminderService({
    required this._repository,
    required this._cipher,
    required this._entitlement,
    this._codec = const ReminderScheduleCodec(),
    this._health,
  });

  final CiphertextRepository _repository;
  final PayloadCipher _cipher;
  final ReminderEntitlementPolicy _entitlement;
  final ReminderScheduleCodec _codec;
  final VaultHealthController? _health;

  @override
  Future<ReminderSchedule?> read(ReminderId id) async {
    final object = await _repository.read(id.value);
    if (object == null) return null;
    return _decrypt(object);
  }

  @override
  Future<ReminderLoadSnapshot> loadAll() async {
    final loader = EncryptedVaultDocumentLoader(
      repository: _repository,
      cipher: _cipher,
      health: _health,
    );
    final snapshot = await loader.loadAll();
    final schedules = <ReminderSchedule>[];
    final quarantined = [...snapshot.quarantinedObjectIds];
    for (final encrypted in snapshot.documents) {
      if (encrypted.document.kind != 'reminder') continue;
      try {
        final schedule = ReminderSchedule.fromJson(encrypted.document.payload);
        if (schedule.id.value != encrypted.object.objectId ||
            schedule.revision != encrypted.object.revision) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        schedules.add(schedule);
      } on VaultFailure catch (failure) {
        if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
        await loader.quarantine(
          encrypted.object,
          VaultFailureCode.integrityFailure,
        );
        quarantined.add(encrypted.object.objectId);
      }
    }
    schedules.sort((a, b) => a.id.value.compareTo(b.id.value));
    return ReminderLoadSnapshot(
      schedules: schedules,
      quarantinedObjectIds: quarantined,
    );
  }

  @override
  Future<ReminderSchedule> create(ReminderSchedule schedule) async {
    _health?.requireWritable();
    _entitlement.requireSchedulingAllowed();
    if (schedule.revision != 1) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    await _repository.create(await _encryptedObject(schedule));
    return schedule;
  }

  @override
  Future<ReminderSchedule> update({
    required ReminderSchedule proposed,
    required int expectedRevision,
  }) async {
    _health?.requireWritable();
    _entitlement.requireSchedulingAllowed();
    final object = await _repository.read(proposed.id.value);
    if (object == null) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    if (object.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    final current = await _decrypt(object);
    if (current.recordId != proposed.recordId ||
        current.fieldId != proposed.fieldId ||
        proposed.revision != expectedRevision) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    final saved = proposed.copyWith(revision: expectedRevision + 1);
    await _repository.replace(
      object: await _encryptedObject(saved),
      expectedRevision: expectedRevision,
    );
    return saved;
  }

  /// Internal entitlement transition. It never deletes a schedule or record.
  @override
  Future<List<ReminderSchedule>> suspendEnabled() async {
    _health?.requireWritable();
    final snapshot = await loadAll();
    final enabled = snapshot.schedules
        .where((schedule) => schedule.state == ReminderScheduleState.enabled)
        .toList(growable: false);
    if (enabled.isEmpty) return const [];
    final saved = enabled
        .map(
          (schedule) => schedule.copyWith(
            state: ReminderScheduleState.entitlementSuspended,
            revision: schedule.revision + 1,
          ),
        )
        .toList(growable: false);
    final replacements = <ExpectedEncryptedObject>[];
    for (var index = 0; index < saved.length; index++) {
      replacements.add(
        ExpectedEncryptedObject(
          object: await _encryptedObject(saved[index]),
          expectedRevision: enabled[index].revision,
        ),
      );
    }
    final repository = _repository;
    if (repository is AtomicCiphertextRepository) {
      await repository.replaceMany(replacements);
    } else if (replacements.length == 1) {
      final replacement = replacements.single;
      await repository.replace(
        object: replacement.object,
        expectedRevision: replacement.expectedRevision,
      );
    } else {
      throw const VaultFailure(VaultFailureCode.capabilityUnavailable);
    }
    return List.unmodifiable(saved);
  }

  Future<EncryptedObject> _encryptedObject(ReminderSchedule schedule) async {
    final plaintext = _codec.encode(schedule);
    try {
      final aad = ObjectAuthenticationData.encode(
        vaultId: _cipher.vaultId,
        objectId: schedule.id.value,
        revision: schedule.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
      );
      final envelope = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: aad,
      );
      return EncryptedObject(
        objectId: schedule.id.value,
        revision: schedule.revision,
        schemaVersion: 1,
        keyGenerationId: _cipher.keyGenerationId,
        envelope: envelope,
      );
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<ReminderSchedule> _decrypt(EncryptedObject object) async {
    if (object.schemaVersion != 1 ||
        object.keyGenerationId != _cipher.keyGenerationId) {
      throw const VaultFailure(VaultFailureCode.unsupportedVersion);
    }
    final aad = ObjectAuthenticationData.encode(
      vaultId: _cipher.vaultId,
      objectId: object.objectId,
      revision: object.revision,
      schemaVersion: object.schemaVersion,
      keyGenerationId: object.keyGenerationId,
    );
    final plaintext = await _cipher.decrypt(
      envelope: object.envelope,
      authenticatedData: aad,
    );
    try {
      final schedule = _codec.decode(plaintext);
      if (schedule.id.value != object.objectId ||
          schedule.revision != object.revision) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      return schedule;
    } on VaultFailure catch (failure) {
      if (failure.code == VaultFailureCode.unsupportedVersion) rethrow;
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

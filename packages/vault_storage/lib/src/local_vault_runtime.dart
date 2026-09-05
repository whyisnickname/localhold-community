// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_native/localhold_vault_native.dart';
import 'package:path/path.dart' as path;

import 'database.dart';
import 'drift_ciphertext_repository.dart';
import 'encrypted_attachment_store.dart';

final class UnlockedVaultServices {
  const UnlockedVaultServices({
    required this.metadata,
    required this.records,
    required this.drafts,
    required this.editorDrafts,
    required this.customTypes,
    required this.organization,
    required this.attachments,
    required this.previews,
    required this.health,
  });

  final EncryptedVaultMetadataService metadata;
  final EncryptedRecordService records;
  final EncryptedDraftService drafts;
  final EncryptedEditorDraftService editorDrafts;
  final EncryptedCustomTypeService customTypes;
  final EncryptedOrganizationService organization;
  final EncryptedAttachmentStore attachments;
  final VaultAttachmentPreviewService previews;
  final VaultHealthController health;
}

final class LocalVaultActivation {
  const LocalVaultActivation({required this.metadata, required this.services});

  /// Null only when encrypted vault metadata is absent or corrupt and the
  /// activation has entered read-only recovery mode.
  final VaultMetadata? metadata;
  final UnlockedVaultServices services;
}

/// UI-independent Stage 4 composition root. It assembles only reviewed local
/// services and has no network or backend dependency.
final class LocalVaultRuntime {
  LocalVaultRuntime({
    required this._database,
    required this._gateway,
    required this._sessions,
    required this._selection,
    required this._unlockDirectory,
    required this._creationPolicy,
    required this._backupExclusion,
    required this._attachmentRoot,
    required this._previewTemporaryRoot,
    AttachmentPreviewCoordinator? previewCoordinator,
  }) : _previewCoordinator =
           previewCoordinator ?? AttachmentPreviewCoordinator() {
    _sessions.addObserver(_previewCoordinator);
  }

  final LocalholdVaultDatabase _database;
  final NativeVaultKeyGateway _gateway;
  final VaultSessionCoordinator _sessions;
  final VaultSelectionStore _selection;
  final VaultUnlockDirectoryStore _unlockDirectory;
  final VaultCreationPolicy _creationPolicy;
  final BackupExclusionGateway _backupExclusion;
  final Directory _attachmentRoot;
  final Directory _previewTemporaryRoot;
  final AttachmentPreviewCoordinator _previewCoordinator;

  VaultSessionCoordinator get sessions => _sessions;

  Future<VaultId?> lastSelectedVault() => _selection.readLastSelected();

  Future<List<VaultUnlockEntry>> lockedVaults() => _unlockDirectory.list();

  Future<void> updatePublicLockScreenLabel(
    VaultId vaultId,
    String? publicLabel,
  ) => _unlockDirectory.updatePublicLabel(vaultId, publicLabel);

  Future<LocalVaultActivation> create({
    required VaultId vaultId,
    required String localizedName,
    required Uint8List masterPassword,
    required DateTime now,
    required bool isAdditionalVault,
    String? publicLockScreenLabel,
  }) async {
    if (_database.isReadOnly) {
      throw const VaultFailure(VaultFailureCode.readOnly);
    }
    if (isAdditionalVault) {
      _creationPolicy.requireAllowed(VaultCreationCapability.additionalVault);
    }
    try {
      late VaultMetadata metadata;
      late UnlockedVaultServices services;
      await _database.transaction(() async {
        await _sessions.create(
          vaultId: vaultId,
          masterPassword: masterPassword,
        );
        services = await _services(vaultId);
        metadata = VaultMetadata(
          id: vaultId,
          name: localizedName,
          createdAt: now.toUtc(),
          updatedAt: now.toUtc(),
        );
        await services.metadata.create(metadata);
        await _unlockDirectory.register(
          vaultId,
          publicLabel: publicLockScreenLabel,
        );
        await _selection.select(vaultId);
      });
      return LocalVaultActivation(metadata: metadata, services: services);
    } on Object {
      await _sessions.lock();
      rethrow;
    }
  }

  Future<LocalVaultActivation> open({
    required VaultId vaultId,
    required Uint8List masterPassword,
    String? safeResumeRoute,
  }) async {
    try {
      await _sessions.open(
        vaultId: vaultId,
        masterPassword: masterPassword,
        safeResumeRoute: safeResumeRoute,
      );
      return await _activateOpenedVault(vaultId);
    } on Object {
      await _sessions.lock();
      rethrow;
    }
  }

  Future<LocalVaultActivation> openWithBiometric({
    required VaultId vaultId,
    String? safeResumeRoute,
  }) async {
    try {
      await _sessions.openUsing(
        vaultId: vaultId,
        openSession: () => _gateway.openWithBiometric(vaultId),
        safeResumeRoute: safeResumeRoute,
      );
      return await _activateOpenedVault(vaultId);
    } on Object {
      await _sessions.lock();
      rethrow;
    }
  }

  Future<LocalVaultActivation> recover({
    required VaultId vaultId,
    required Uint8List recoveryPhraseUtf8,
    required Uint8List newMasterPassword,
    String? safeResumeRoute,
  }) async {
    try {
      await _sessions.openUsing(
        vaultId: vaultId,
        openSession: () => _gateway.recoverAndReplaceMaster(
          vaultId: vaultId,
          recoveryPhraseUtf8: recoveryPhraseUtf8,
          newMasterPassword: newMasterPassword,
        ),
        safeResumeRoute: safeResumeRoute,
      );
      return await _activateOpenedVault(vaultId);
    } on Object {
      await _sessions.lock();
      rethrow;
    }
  }

  Future<void> changeMasterPassword({
    required VaultId vaultId,
    required Uint8List newMasterPassword,
  }) => _gateway.changeMasterPassword(
    vaultId: vaultId,
    session: _sessions.requireSession,
    newMasterPassword: newMasterPassword,
  );

  Future<RecoveryCeremony> beginRecovery() =>
      _gateway.beginRecovery(_sessions.requireSession);

  Future<void> presentRecovery(RecoveryCeremony ceremony) =>
      _gateway.presentRecovery(ceremony);

  Future<void> confirmRecovery({
    required VaultId vaultId,
    required RecoveryCeremony ceremony,
    required Uint8List challengeWordsUtf8,
  }) => _gateway.confirmRecovery(
    vaultId: vaultId,
    ceremony: ceremony,
    challengeWordsUtf8: challengeWordsUtf8,
  );

  Future<void> cancelRecovery(RecoveryCeremony ceremony) =>
      _gateway.cancelRecovery(ceremony);

  Future<void> enableBiometric() =>
      _gateway.enableBiometric(_sessions.requireSession);

  Future<void> disableBiometric() =>
      _gateway.disableBiometric(_sessions.requireSession);

  Future<BiometricStatus> biometricStatus(VaultId vaultId) =>
      _gateway.biometricStatus(vaultId);

  Future<LocalVaultActivation> _activateOpenedVault(VaultId vaultId) async {
    final services = await _services(vaultId);
    VaultMetadata? metadata;
    try {
      metadata = await services.metadata.read(vaultId);
    } on VaultFailure catch (failure) {
      if (failure.code != VaultFailureCode.integrityFailure) rethrow;
      services.health.enterReadOnly(VaultFailureCode.integrityFailure);
    }
    if (metadata == null) {
      services.health.enterReadOnly(VaultFailureCode.integrityFailure);
    }
    if (!_database.isReadOnly) await _selection.select(vaultId);
    return LocalVaultActivation(metadata: metadata, services: services);
  }

  Future<UnlockedVaultServices> _services(VaultId vaultId) async {
    final cipher = _gateway.payloadCipher(_sessions.requireSession);
    final repository = DriftCiphertextRepository(_database, vaultId: vaultId);
    final health = VaultHealthController();
    if (_database.isReadOnly) {
      health.enterReadOnly(VaultFailureCode.readOnly);
    }
    final root = Directory(path.join(_attachmentRoot.path, vaultId.value));
    if (!_database.isReadOnly) {
      await root.create(recursive: true);
      await _backupExclusion.excludeAbsolutePath(root.absolute.path);
    }
    final attachments = EncryptedAttachmentStore(
      root: root,
      cipher: cipher,
      creationPolicy: _creationPolicy,
      health: health,
    );
    if (!_database.isReadOnly) {
      final attachmentRecoveryFailures = await attachments
          .recoverInterruptedOperations();
      if (attachmentRecoveryFailures.isNotEmpty) {
        health.enterReadOnly(VaultFailureCode.integrityFailure);
      }
    }
    final previewRoot = Directory(
      path.join(_previewTemporaryRoot.path, vaultId.value),
    );
    return UnlockedVaultServices(
      metadata: EncryptedVaultMetadataService(
        repository: repository,
        cipher: cipher,
        health: health,
      ),
      records: EncryptedRecordService(
        repository: repository,
        cipher: cipher,
        creationPolicy: _creationPolicy,
        health: health,
      ),
      drafts: EncryptedDraftService(
        repository: repository,
        cipher: cipher,
        health: health,
      ),
      editorDrafts: EncryptedEditorDraftService(
        repository: repository,
        cipher: cipher,
        health: health,
      ),
      customTypes: EncryptedCustomTypeService(
        repository: repository,
        cipher: cipher,
        creationPolicy: _creationPolicy,
        health: health,
      ),
      organization: EncryptedOrganizationService(
        repository: repository,
        cipher: cipher,
        health: health,
      ),
      attachments: attachments,
      previews: VaultAttachmentPreviewService(
        coordinator: _previewCoordinator,
        store: attachments,
        privateTemporaryRoot: previewRoot,
      ),
      health: health,
    );
  }
}

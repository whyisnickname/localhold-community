// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:path/path.dart' as path;

final class EncryptedAttachmentStore implements AttachmentCipherStore {
  EncryptedAttachmentStore({
    required this._root,
    required this._cipher,
    required this._creationPolicy,
    this._health,
  });

  final Directory _root;
  final PayloadCipher _cipher;
  final VaultCreationPolicy _creationPolicy;
  final VaultHealthController? _health;
  final Map<String, int> _cancellationEpoch = {};
  Future<void> _operationTail = Future.value();
  Future<void> _previewTail = Future.value();

  @override
  Future<void> importEncrypted({
    required AttachmentId id,
    required Stream<List<int>> plaintext,
    required int declaredSize,
  }) {
    final cancellationEpoch = _epoch(id);
    return _exclusive(() async {
      _health?.requireWritable();
      if (declaredSize < 0) {
        throw const VaultFailure(VaultFailureCode.invalidInput);
      }
      await _root.create(recursive: true);
      final staging = Directory(
        path.join(_root.path, '.staging-${id.value}-${OpaqueId.generate()}'),
      );
      final finalDirectory = Directory(path.join(_root.path, id.value));
      if (!await finalDirectory.exists()) {
        _creationPolicy.requireAllowed(VaultCreationCapability.attachment);
      }
      final previous = Directory(
        path.join(_root.path, '.previous-${id.value}'),
      );
      await staging.create();
      final digestSink = _SingleDigestSink();
      final digestInput = sha256.startChunkedConversion(digestSink);
      var digestClosed = false;
      var chunk = BytesBuilder(copy: false);
      var chunkIndex = 0;
      var consumed = 0;
      try {
        await for (final incoming in plaintext) {
          var offset = 0;
          while (offset < incoming.length) {
            _throwIfCancelled(id, cancellationEpoch);
            final remaining = VaultLimits.attachmentChunkBytes - chunk.length;
            final take = min(incoming.length - offset, remaining);
            final slice = Uint8List.fromList(
              incoming.sublist(offset, offset + take),
            );
            chunk.add(slice);
            digestInput.add(slice);
            consumed += take;
            offset += take;
            if (consumed > declaredSize) {
              throw const VaultFailure(VaultFailureCode.integrityFailure);
            }
            if (chunk.length == VaultLimits.attachmentChunkBytes) {
              await _writeChunk(
                staging,
                id,
                chunkIndex++,
                declaredSize,
                chunk.takeBytes(),
              );
              chunk = BytesBuilder(copy: false);
            }
          }
        }
        if (chunk.isNotEmpty) {
          await _writeChunk(
            staging,
            id,
            chunkIndex++,
            declaredSize,
            chunk.takeBytes(),
          );
        }
        if (consumed != declaredSize) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        digestInput.close();
        digestClosed = true;
        final manifest = AttachmentManifest(
          id: id,
          declaredSize: declaredSize,
          chunkCount: chunkIndex,
          authenticatedDigest: Uint8List.fromList(digestSink.value!.bytes),
        );
        await _writeManifest(staging, manifest);
        _throwIfCancelled(id, cancellationEpoch);
        if (await previous.exists()) await previous.delete(recursive: true);
        if (await finalDirectory.exists()) {
          await finalDirectory.rename(previous.path);
        }
        try {
          await staging.rename(finalDirectory.path);
        } catch (_) {
          if (await previous.exists() && !await finalDirectory.exists()) {
            await previous.rename(finalDirectory.path);
          }
          rethrow;
        }
        if (await previous.exists()) {
          try {
            await previous.delete(recursive: true);
          } on FileSystemException {
            // Last-good object is already promoted; cleanup is best effort.
          }
        }
      } on FileSystemException {
        throw const VaultFailure(VaultFailureCode.storageFull);
      } finally {
        if (!digestClosed) digestInput.close();
        if (await staging.exists()) {
          try {
            await staging.delete(recursive: true);
          } on FileSystemException {
            // A later cleanup pass removes stale staging directories.
          }
        }
      }
    });
  }

  @override
  Stream<Uint8List> openVerified(AttachmentId id) async* {
    final previewTurn = Completer<void>();
    final previousPreview = _previewTail;
    _previewTail = previewTurn.future;
    final cancellationEpoch = _epoch(id);
    await previousPreview;
    ByteConversionSink? digestInput;
    var digestClosed = true;
    try {
      _throwIfCancelled(id, cancellationEpoch);
      final directory = Directory(path.join(_root.path, id.value));
      if (!await directory.exists()) {
        throw const VaultFailure(VaultFailureCode.objectNotFound);
      }
      final manifest = await _readManifest(directory, id);
      final digestSink = _SingleDigestSink();
      digestInput = sha256.startChunkedConversion(digestSink);
      digestClosed = false;
      var total = 0;
      for (var index = 0; index < manifest.chunkCount; index++) {
        _throwIfCancelled(id, cancellationEpoch);
        final encrypted = await File(_chunkPath(directory, index))
            .readAsBytes();
        final plaintext = await _cipher.decrypt(
          envelope: encrypted,
          authenticatedData: _chunkAad(id, index, manifest.declaredSize),
        );
        if (plaintext.length > VaultLimits.attachmentChunkBytes ||
            (index < manifest.chunkCount - 1 &&
                plaintext.length != VaultLimits.attachmentChunkBytes)) {
          plaintext.fillRange(0, plaintext.length, 0);
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        total += plaintext.length;
        digestInput.add(plaintext);
        try {
          yield plaintext;
        } finally {
          plaintext.fillRange(0, plaintext.length, 0);
        }
      }
      digestInput.close();
      digestClosed = true;
      final actual = digestSink.value!.bytes;
      if (total != manifest.declaredSize ||
          !_constantTimeEquals(actual, manifest.authenticatedDigest)) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
    } on FileSystemException {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    } finally {
      if (!digestClosed) digestInput?.close();
      previewTurn.complete();
    }
  }

  @override
  Future<void> moveToTrash(AttachmentId id) => _exclusive(() async {
    _health?.requireWritable();
    final source = Directory(path.join(_root.path, id.value));
    if (!await source.exists()) return;
    final trash = Directory(path.join(_root.path, '.trash'));
    await trash.create(recursive: true);
    final destination = Directory(path.join(trash.path, id.value));
    if (await destination.exists()) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    try {
      await source.rename(destination.path);
    } on FileSystemException {
      throw const VaultFailure(VaultFailureCode.storageFull);
    }
  });

  @override
  Future<void> restoreFromTrash(AttachmentId id) => _exclusive(() async {
    _health?.requireWritable();
    final source = Directory(path.join(_root.path, '.trash', id.value));
    if (!await source.exists()) {
      throw const VaultFailure(VaultFailureCode.objectNotFound);
    }
    final destination = Directory(path.join(_root.path, id.value));
    if (await destination.exists()) {
      throw const VaultFailure(VaultFailureCode.revisionConflict);
    }
    try {
      await source.rename(destination.path);
    } on FileSystemException {
      throw const VaultFailure(VaultFailureCode.storageFull);
    }
  });

  @override
  Future<void> permanentlyDelete(AttachmentId id) => _exclusive(() async {
    _health?.requireWritable();
    try {
      for (final candidate in [
        Directory(path.join(_root.path, id.value)),
        Directory(path.join(_root.path, '.trash', id.value)),
      ]) {
        if (await candidate.exists()) await candidate.delete(recursive: true);
      }
    } on FileSystemException {
      throw const VaultFailure(VaultFailureCode.storageFull);
    }
  });

  @override
  Future<void> cancel(AttachmentId id) async {
    _cancellationEpoch[id.value] = _epoch(id) + 1;
  }

  Future<List<String>> cleanupStaleStaging() => _exclusive(() async {
    if (!await _root.exists()) return const [];
    final failures = <String>[];
    await for (final entity in _root.list()) {
      if (entity is Directory &&
          path.basename(entity.path).startsWith('.staging-')) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          failures.add(path.basename(entity.path));
        }
      }
    }
    return List.unmodifiable(failures);
  });

  /// Restores the last-good directory after an interrupted two-phase promote.
  /// If both versions exist, the promoted directory wins and the old one is
  /// removed. Failures are returned without secret-bearing filesystem details.
  Future<List<String>> recoverInterruptedOperations() => _exclusive(() async {
    if (!await _root.exists()) return const [];
    final failures = <String>[];
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = path.basename(entity.path);
      if (name.startsWith('.staging-')) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          failures.add('staging_cleanup');
        }
        continue;
      }
      if (!name.startsWith('.previous-')) continue;
      final rawId = name.substring('.previous-'.length);
      try {
        final id = AttachmentId.parse(rawId);
        final promoted = Directory(path.join(_root.path, id.value));
        if (await promoted.exists()) {
          await entity.delete(recursive: true);
        } else {
          await entity.rename(promoted.path);
        }
      } on Object {
        failures.add('promotion_recovery');
      }
    }
    return List.unmodifiable(failures);
  });

  Future<void> _writeChunk(
    Directory staging,
    AttachmentId id,
    int index,
    int declaredSize,
    Uint8List plaintext,
  ) async {
    try {
      final encrypted = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: _chunkAad(id, index, declaredSize),
      );
      await File(_chunkPath(staging, index))
          .writeAsBytes(encrypted, flush: true);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<void> _writeManifest(
    Directory staging,
    AttachmentManifest manifest,
  ) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'id': manifest.id.value,
          'declaredSize': manifest.declaredSize,
          'chunkCount': manifest.chunkCount,
          'digest': base64UrlEncode(manifest.authenticatedDigest),
        }),
      ),
    );
    try {
      final encrypted = await _cipher.encrypt(
        plaintext: plaintext,
        authenticatedData: _manifestAad(manifest.id),
      );
      await File(path.join(staging.path, 'manifest.bin'))
          .writeAsBytes(encrypted, flush: true);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<AttachmentManifest> _readManifest(
    Directory directory,
    AttachmentId id,
  ) async {
    final encrypted = await File(path.join(directory.path, 'manifest.bin'))
        .readAsBytes();
    final plaintext = await _cipher.decrypt(
      envelope: encrypted,
      authenticatedData: _manifestAad(id),
    );
    try {
      final json = jsonDecode(utf8.decode(plaintext, allowMalformed: false));
      if (json is! Map<String, Object?> ||
          json['version'] != 1 ||
          json['id'] != id.value) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      final declaredSize = json['declaredSize'];
      final chunkCount = json['chunkCount'];
      final digestText = json['digest'];
      if (declaredSize is! int || chunkCount is! int || digestText is! String) {
        throw const FormatException();
      }
      final digest = base64Url.decode(digestText);
      if (digest.length != sha256.convert(const <int>[]).bytes.length) {
        throw const FormatException();
      }
      return AttachmentManifest(
        id: id,
        declaredSize: declaredSize,
        chunkCount: chunkCount,
        authenticatedDigest: Uint8List.fromList(digest),
      );
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Uint8List _chunkAad(
    AttachmentId id,
    int index,
    int declaredSize,
  ) => Uint8List.fromList(
    ascii.encode(
      'localhold.attachment.chunk.v1|${_cipher.vaultId}|${_cipher.keyGenerationId}|${id.value}|$index|$declaredSize',
    ),
  );

  Uint8List _manifestAad(AttachmentId id) => Uint8List.fromList(
    ascii.encode(
      'localhold.attachment.manifest.v1|${_cipher.vaultId}|${_cipher.keyGenerationId}|${id.value}',
    ),
  );

  String _chunkPath(Directory directory, int index) => path.join(
    directory.path,
    'chunk-${index.toString().padLeft(10, '0')}.bin',
  );

  int _epoch(AttachmentId id) => _cancellationEpoch[id.value] ?? 0;

  void _throwIfCancelled(AttachmentId id, int expectedEpoch) {
    if (_epoch(id) != expectedEpoch) {
      throw const VaultFailure(VaultFailureCode.sessionLocked);
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

final class _SingleDigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    if (value != null) throw StateError('Digest already completed');
    value = data;
  }

  @override
  void close() {}
}

final class AttachmentPreviewLease {
  AttachmentPreviewLease._(this.file, [this._onClosed]);

  final File file;
  final void Function(bool removed)? _onClosed;
  bool _closed = false;

  Future<bool> close() async {
    if (_closed) return true;
    try {
      if (await file.exists()) await file.delete();
      final removed = !await file.exists();
      _closed = removed;
      _onClosed?.call(removed);
      return removed;
    } on FileSystemException {
      _onClosed?.call(false);
      return false;
    }
  }
}

Future<AttachmentPreviewLease> _createAttachmentPreview({
  required AttachmentCipherStore store,
  required AttachmentId id,
  required String mimeType,
  required Directory privateTemporaryRoot,
  void Function(bool removed)? onClosed,
}) async {
  if (classifyPreview(mimeType) == AttachmentPreviewKind.unsupported) {
    throw const VaultFailure(VaultFailureCode.invalidInput);
  }
  await privateTemporaryRoot.create(recursive: true);
  final file = File(
    path.join(
      privateTemporaryRoot.path,
      'preview-${id.value}-${OpaqueId.generate()}',
    ),
  );
  RandomAccessFile? sink;
  try {
    sink = await file.open(mode: FileMode.writeOnly);
    await for (final chunk in store.openVerified(id)) {
      await sink.writeFrom(chunk);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    return AttachmentPreviewLease._(file, onClosed);
  } on VaultFailure {
    await _removePartialPreview(sink, file);
    rethrow;
  } on FileSystemException {
    await _removePartialPreview(sink, file);
    throw const VaultFailure(VaultFailureCode.storageFull);
  } on Object {
    await _removePartialPreview(sink, file);
    throw const VaultFailure(VaultFailureCode.internalFailure);
  }
}

Future<void> _removePartialPreview(RandomAccessFile? sink, File file) async {
  try {
    await sink?.close();
  } on FileSystemException {
    // The following deletion attempt remains authoritative.
  }
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // A lifecycle cleanup pass retries deletion without exposing path details.
  }
}

/// Owns plaintext preview lifetimes for the active vault session. A lifecycle
/// transition invalidates in-flight preview creation and retries deletion of
/// any file that the platform could not remove immediately.
final class AttachmentPreviewCoordinator implements VaultSessionObserver {
  final Set<AttachmentPreviewLease> _leases = {};
  final Set<String> _temporaryRoots = {};
  var _lifecycleEpoch = 0;
  var _active = false;
  var _cleanupPending = false;

  bool get hasPendingCleanup => _leases.isNotEmpty || _cleanupPending;

  Future<AttachmentPreviewLease> open({
    required AttachmentCipherStore store,
    required AttachmentId id,
    required String mimeType,
    required Directory privateTemporaryRoot,
  }) async {
    if (!_active) {
      throw const VaultFailure(VaultFailureCode.sessionLocked);
    }
    final expectedEpoch = _lifecycleEpoch;
    _temporaryRoots.add(privateTemporaryRoot.absolute.path);
    late final AttachmentPreviewLease lease;
    try {
      lease = await _createAttachmentPreview(
        store: store,
        id: id,
        mimeType: mimeType,
        privateTemporaryRoot: privateTemporaryRoot,
        onClosed: (removed) {
          if (removed) _leases.remove(lease);
        },
      );
    } on Object {
      _cleanupPending = true;
      rethrow;
    }
    if (!_active || expectedEpoch != _lifecycleEpoch) {
      await lease.close();
      throw const VaultFailure(VaultFailureCode.sessionLocked);
    }
    _leases.add(lease);
    return lease;
  }

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) async {
    _lifecycleEpoch += 1;
    await _closeAll();
    _active = true;
  }

  @override
  Future<void> onBackground() async {
    _active = false;
    _lifecycleEpoch += 1;
    await _closeAll();
  }

  @override
  Future<void> onForeground() async {
    await _closeAll();
    _active = true;
  }

  @override
  Future<void> onLocking() async {
    _active = false;
    _lifecycleEpoch += 1;
    await _closeAll();
  }

  Future<void> _closeAll() async {
    for (final lease in _leases.toList(growable: false)) {
      await lease.close();
    }
    _cleanupPending = false;
    for (final rootPath in _temporaryRoots) {
      final root = Directory(rootPath);
      if (!await root.exists()) continue;
      try {
        await for (final entity in root.list(followLinks: false)) {
          if (entity is File &&
              path.basename(entity.path).startsWith('preview-')) {
            try {
              await entity.delete();
            } on FileSystemException {
              _cleanupPending = true;
            }
          }
        }
      } on FileSystemException {
        _cleanupPending = true;
      }
    }
    for (final lease in _leases.toList(growable: false)) {
      if (!await lease.file.exists()) _leases.remove(lease);
    }
  }
}

final class VaultAttachmentPreviewService {
  const VaultAttachmentPreviewService({
    required this._coordinator,
    required this._store,
    required this._privateTemporaryRoot,
  });

  final AttachmentPreviewCoordinator _coordinator;
  final AttachmentCipherStore _store;
  final Directory _privateTemporaryRoot;

  Future<AttachmentPreviewLease> open({
    required AttachmentId id,
    required String mimeType,
  }) => _coordinator.open(
    store: _store,
    id: id,
    mimeType: mimeType,
    privateTemporaryRoot: _privateTemporaryRoot,
  );
}

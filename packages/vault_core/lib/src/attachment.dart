// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'errors.dart';
import 'identifiers.dart';
import 'policies.dart';

final class AttachmentManifest {
  AttachmentManifest({
    required this.id,
    required this.declaredSize,
    required this.chunkCount,
    required Uint8List authenticatedDigest,
  }) : authenticatedDigest = Uint8List.fromList(authenticatedDigest) {
    if (declaredSize < 0 ||
        chunkCount < 0 ||
        chunkCount != _requiredChunks(declaredSize) ||
        authenticatedDigest.length != 32) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
  }

  final AttachmentId id;
  final int declaredSize;
  final int chunkCount;
  final Uint8List authenticatedDigest;

  static int _requiredChunks(int size) => size == 0
      ? 0
      : (size + VaultLimits.attachmentChunkBytes - 1) ~/
            VaultLimits.attachmentChunkBytes;
}

abstract interface class AttachmentCipherStore {
  Future<void> importEncrypted({
    required AttachmentId id,
    required Stream<List<int>> plaintext,
    required int declaredSize,
  });

  Stream<Uint8List> openVerified(AttachmentId id);

  Future<void> moveToTrash(AttachmentId id);

  Future<void> restoreFromTrash(AttachmentId id);

  Future<void> permanentlyDelete(AttachmentId id);

  Future<void> cancel(AttachmentId id);
}

enum AttachmentPreviewKind { image, pdf, plainText, unsupported }

AttachmentPreviewKind classifyPreview(String mimeType) {
  final normalized = mimeType.toLowerCase().trim();
  if (normalized.startsWith('image/')) return AttachmentPreviewKind.image;
  if (normalized == 'application/pdf') return AttachmentPreviewKind.pdf;
  if (normalized.startsWith('text/plain')) {
    return AttachmentPreviewKind.plainText;
  }
  return AttachmentPreviewKind.unsupported;
}

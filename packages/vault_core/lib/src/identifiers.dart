// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'errors.dart';

abstract final class OpaqueId {
  static final Random _random = Random.secure();
  static final RegExp _encoded = RegExp(r'^[A-Za-z0-9_-]{22}$');

  static String generate() {
    final bytes = Uint8List(16);
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String requireValid(String value) {
    if (!_encoded.hasMatch(value)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    return value;
  }
}

extension type const VaultId._(String value) {
  factory VaultId.generate() => VaultId._(OpaqueId.generate());
  factory VaultId.parse(String value) =>
      VaultId._(OpaqueId.requireValid(value));
}

extension type const RecordId._(String value) {
  factory RecordId.generate() => RecordId._(OpaqueId.generate());
  factory RecordId.parse(String value) =>
      RecordId._(OpaqueId.requireValid(value));
}

extension type const FieldId._(String value) {
  factory FieldId.generate() => FieldId._(OpaqueId.generate());
  factory FieldId.parse(String value) =>
      FieldId._(OpaqueId.requireValid(value));
}

extension type const FolderId._(String value) {
  factory FolderId.generate() => FolderId._(OpaqueId.generate());
  factory FolderId.parse(String value) =>
      FolderId._(OpaqueId.requireValid(value));
}

extension type const TagId._(String value) {
  factory TagId.generate() => TagId._(OpaqueId.generate());
  factory TagId.parse(String value) => TagId._(OpaqueId.requireValid(value));
}

extension type const AttachmentId._(String value) {
  factory AttachmentId.generate() => AttachmentId._(OpaqueId.generate());
  factory AttachmentId.parse(String value) =>
      AttachmentId._(OpaqueId.requireValid(value));
}

extension type const DraftId._(String value) {
  factory DraftId.generate() => DraftId._(OpaqueId.generate());
  factory DraftId.parse(String value) =>
      DraftId._(OpaqueId.requireValid(value));
}

extension type const OrganizationId._(String value) {
  factory OrganizationId.generate() => OrganizationId._(OpaqueId.generate());
  factory OrganizationId.parse(String value) =>
      OrganizationId._(OpaqueId.requireValid(value));
}

extension type const ReminderId._(String value) {
  factory ReminderId.generate() => ReminderId._(OpaqueId.generate());
  factory ReminderId.parse(String value) =>
      ReminderId._(OpaqueId.requireValid(value));
}

extension type const PendingShareId._(String value) {
  factory PendingShareId.generate() => PendingShareId._(OpaqueId.generate());
  factory PendingShareId.parse(String value) =>
      PendingShareId._(OpaqueId.requireValid(value));
}

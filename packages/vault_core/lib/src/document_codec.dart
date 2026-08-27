// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'errors.dart';
import 'policies.dart';

final class VaultDocument {
  const VaultDocument({required this.kind, required this.payload});

  final String kind;
  final Map<String, Object?> payload;
}

final class VaultDocumentCodec {
  const VaultDocumentCodec();

  Uint8List encode({
    required String kind,
    required Map<String, Object?> payload,
  }) {
    if (!RegExp(r'^[a-z_]{1,32}$').hasMatch(kind)) {
      throw const VaultFailure(VaultFailureCode.invalidInput);
    }
    _validateTree(payload, depth: 0, remainingNodes: [4096]);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'documentVersion': 1, 'kind': kind, 'payload': payload}),
      ),
    );
    if (bytes.lengthInBytes > VaultLimits.maximumRecordBytes) {
      throw const VaultFailure(VaultFailureCode.payloadTooLarge);
    }
    return bytes;
  }

  VaultDocument decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.lengthInBytes > VaultLimits.maximumRecordBytes) {
      throw const VaultFailure(VaultFailureCode.payloadTooLarge);
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map<String, Object?> ||
          decoded['documentVersion'] != 1 ||
          decoded['kind'] is! String ||
          decoded['payload'] is! Map<Object?, Object?>) {
        throw const VaultFailure(VaultFailureCode.unsupportedVersion);
      }
      final kind = decoded['kind']! as String;
      if (!RegExp(r'^[a-z_]{1,32}$').hasMatch(kind)) {
        throw const VaultFailure(VaultFailureCode.integrityFailure);
      }
      _validateTree(decoded, depth: 0, remainingNodes: [4096]);
      return VaultDocument(
        kind: kind,
        payload: Map<String, Object?>.from(
          decoded['payload']! as Map<Object?, Object?>,
        ),
      );
    } on VaultFailure {
      rethrow;
    } on Object {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }

  void _validateTree(
    Object? value, {
    required int depth,
    required List<int> remainingNodes,
  }) {
    if (depth > 12 || --remainingNodes[0] < 0) {
      throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
    switch (value) {
      case final Map<Object?, Object?> map:
        if (map.length > 1024 || map.keys.any((key) => key is! String)) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        for (final entry in map.entries) {
          _validateTree(
            entry.value,
            depth: depth + 1,
            remainingNodes: remainingNodes,
          );
        }
      case final List<Object?> list:
        if (list.length > 1024) {
          throw const VaultFailure(VaultFailureCode.integrityFailure);
        }
        for (final item in list) {
          _validateTree(item, depth: depth + 1, remainingNodes: remainingNodes);
        }
      case final String string:
        if (utf8.encode(string).length > VaultLimits.maximumRecordBytes) {
          throw const VaultFailure(VaultFailureCode.payloadTooLarge);
        }
      case null || bool() || num():
        return;
      default:
        throw const VaultFailure(VaultFailureCode.integrityFailure);
    }
  }
}

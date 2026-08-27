// SPDX-License-Identifier: MPL-2.0
library;

import 'dart:typed_data';

final class EncryptedRecordBlob {
  EncryptedRecordBlob({
    required this.recordId,
    required this.revision,
    required Uint8List envelope,
  }) : envelope = Uint8List.fromList(envelope);

  final String recordId;
  final int revision;
  final Uint8List envelope;
}

final class UnlockedRecord {
  const UnlockedRecord({
    required this.recordId,
    required this.title,
    required this.values,
  });

  final String recordId;
  final String title;
  final List<String> values;
}

typedef AuthenticatedRecordOpener = UnlockedRecord Function(EncryptedRecordBlob blob);

final class UnlockScopedSearchIndex {
  final Map<String, Set<String>> _tokenToIds = <String, Set<String>>{};
  final Map<String, Set<String>> _idToTokens = <String, Set<String>>{};
  bool _unlocked = false;

  bool get isUnlocked => _unlocked;
  int get indexedRecordCount => _idToTokens.length;

  void build(Iterable<EncryptedRecordBlob> blobs, AuthenticatedRecordOpener open) {
    clear();
    _unlocked = true;
    try {
      for (final blob in blobs) {
        final record = open(blob);
        if (record.recordId != blob.recordId) {
          throw StateError('Authenticated record ID mismatch');
        }
        _replace(record);
      }
    } catch (_) {
      clear();
      rethrow;
    }
  }

  List<String> search(String query) {
    if (!_unlocked) throw StateError('Vault is locked');
    final tokens = _tokens(<String>[query]);
    if (tokens.isEmpty) return const <String>[];
    Set<String>? result;
    for (final token in tokens) {
      final ids = _tokenToIds[token] ?? const <String>{};
      result = result == null ? Set<String>.from(ids) : result.intersection(ids);
      if (result.isEmpty) break;
    }
    final sorted = result?.toList() ?? <String>[];
    sorted.sort();
    return sorted;
  }

  void clear() {
    for (final ids in _tokenToIds.values) {
      ids.clear();
    }
    for (final tokens in _idToTokens.values) {
      tokens.clear();
    }
    _tokenToIds.clear();
    _idToTokens.clear();
    _unlocked = false;
  }

  void _replace(UnlockedRecord record) {
    final previous = _idToTokens.remove(record.recordId);
    if (previous != null) {
      for (final token in previous) {
        _tokenToIds[token]?.remove(record.recordId);
      }
    }
    final tokens = _tokens(<String>[record.title, ...record.values]);
    _idToTokens[record.recordId] = tokens;
    for (final token in tokens) {
      (_tokenToIds[token] ??= <String>{}).add(record.recordId);
    }
  }

  static Set<String> _tokens(Iterable<String> values) => values
      .expand((value) => value.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)))
      .where((token) => token.isNotEmpty)
      .toSet();
}

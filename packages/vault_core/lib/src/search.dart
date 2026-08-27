// SPDX-License-Identifier: MPL-2.0

import 'models.dart';
import 'errors.dart';
import 'identifiers.dart';
import 'session.dart';

import 'package:unorm_dart/unorm_dart.dart' as unicode;

enum VaultRecordSort {
  updatedNewest,
  updatedOldest,
  createdNewest,
  createdOldest,
}

final class VaultSearchFilter {
  const VaultSearchFilter({
    this.lifecycle,
    this.favoriteOnly = false,
    this.folderId,
    this.requiredTagIds = const {},
    this.sort = VaultRecordSort.updatedNewest,
  });

  final RecordLifecycle? lifecycle;
  final bool favoriteOnly;
  final String? folderId;
  final Set<String> requiredTagIds;
  final VaultRecordSort sort;
}

abstract interface class SearchNormalizer {
  String normalize(String input);
}

final class UnicodeSearchNormalizer implements SearchNormalizer {
  const UnicodeSearchNormalizer();

  @override
  String normalize(String input) {
    var value = unicode.nfkd(input).toLowerCase();
    value = value.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ');
    value = value.replaceAll(
      RegExp('[\u0300-\u036f\u1ab0-\u1aff\u1dc0-\u1dff\ufe20-\ufe2f]'),
      '',
    );
    return value
        .replaceAll('ß', 'ss')
        .replaceAll('æ', 'ae')
        .replaceAll('œ', 'oe')
        .replaceAll('ø', 'o')
        .replaceAll('ł', 'l')
        .replaceAll('đ', 'd')
        .replaceAll('ð', 'd')
        .replaceAll('þ', 'th')
        .replaceAll('ς', 'σ')
        .trim();
  }
}

final class SearchDocument {
  const SearchDocument({
    required this.record,
    required this.publicText,
    required this.protectedText,
  });

  final VaultRecord record;
  final Iterable<String> publicText;
  final Iterable<String> protectedText;
}

final class SearchIndexProgress {
  const SearchIndexProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}

final class SearchIndexCancellation {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Populates the in-memory index in bounded batches so unlock does not retain
/// an additional full copy of all decrypted records while indexing.
final class VaultSearchIndexer {
  const VaultSearchIndexer({this.batchSize = 50})
    : assert(batchSize > 0 && batchSize <= 1000);

  final int batchSize;

  Future<void> rebuild({
    required VaultSearchIndex index,
    required Iterable<SearchDocument> documents,
    required void Function(SearchIndexProgress progress) onProgress,
    SearchIndexCancellation? cancellation,
  }) async {
    final total = documents.length;
    var completed = 0;
    onProgress(SearchIndexProgress(completed: 0, total: total));
    for (final document in documents) {
      if (cancellation?.isCancelled ?? false) return;
      index.put(document);
      completed++;
      if (completed % batchSize == 0 || completed == total) {
        onProgress(SearchIndexProgress(completed: completed, total: total));
        await Future<void>.delayed(Duration.zero);
      }
    }
  }
}

final class VaultSearchIndex {
  VaultSearchIndex({this._normalizer = const UnicodeSearchNormalizer()});

  final SearchNormalizer _normalizer;
  final Map<String, _IndexedDocument> _documents = {};
  bool _protectedSearchAuthorized = false;
  bool _destroyed = false;

  int get length => _documents.length;

  void authorizeProtectedSearch() {
    _ensureAlive();
    _protectedSearchAuthorized = true;
  }

  void put(SearchDocument document) {
    _ensureAlive();
    _documents[document.record.id.value] = _IndexedDocument(
      record: document.record,
      publicText: _join(document.publicText),
      protectedText: _join(document.protectedText),
    );
  }

  void remove(String recordId) {
    _ensureAlive();
    _documents.remove(recordId);
  }

  List<VaultRecord> search(
    String query, {
    bool includeProtected = false,
    VaultSearchFilter filter = const VaultSearchFilter(),
  }) {
    _ensureAlive();
    final normalized = _normalizer.normalize(query);
    if (normalized.isEmpty) return const [];
    final protectedAllowed = includeProtected && _protectedSearchAuthorized;
    final results = <VaultRecord>[];
    for (final document in _documents.values) {
      if (_matchesFilter(document.record, filter) &&
          (document.publicText.contains(normalized) ||
              (protectedAllowed &&
                  document.protectedText.contains(normalized)))) {
        results.add(document.record);
      }
    }
    results.sort(
      (a, b) => switch (filter.sort) {
        VaultRecordSort.updatedNewest => b.updatedAt.compareTo(a.updatedAt),
        VaultRecordSort.updatedOldest => a.updatedAt.compareTo(b.updatedAt),
        VaultRecordSort.createdNewest => b.createdAt.compareTo(a.createdAt),
        VaultRecordSort.createdOldest => a.createdAt.compareTo(b.createdAt),
      },
    );
    return List.unmodifiable(results);
  }

  bool _matchesFilter(VaultRecord record, VaultSearchFilter filter) {
    if (filter.lifecycle != null && record.lifecycle != filter.lifecycle) {
      return false;
    }
    if (filter.favoriteOnly && !record.favorite) return false;
    if (filter.folderId != null && record.folderId?.value != filter.folderId) {
      return false;
    }
    final tagIds = record.tagIds.map((tag) => tag.value).toSet();
    return tagIds.containsAll(filter.requiredTagIds);
  }

  void destroy() {
    _documents.clear();
    _protectedSearchAuthorized = false;
    _destroyed = true;
  }

  String _join(Iterable<String> values) =>
      values.map(_normalizer.normalize).join('\u0000');

  void _ensureAlive() {
    if (_destroyed) {
      throw StateError('Search index has been destroyed');
    }
  }
}

final class _IndexedDocument {
  const _IndexedDocument({
    required this.record,
    required this.publicText,
    required this.protectedText,
  });

  final VaultRecord record;
  final String publicText;
  final String protectedText;
}

final class SearchSessionObserver implements VaultSessionObserver {
  SearchSessionObserver({required this._createIndex});

  final VaultSearchIndex Function() _createIndex;
  VaultSearchIndex? _index;

  VaultSearchIndex get requireIndex =>
      _index ?? (throw const VaultFailure(VaultFailureCode.sessionLocked));

  @override
  Future<void> onUnlocked(VaultId vaultId, VaultSessionRef session) async {
    _index?.destroy();
    _index = _createIndex();
  }

  @override
  Future<void> onBackground() async {
    _index?.destroy();
    _index = null;
  }

  @override
  Future<void> onForeground() async {
    _index?.destroy();
    _index = _createIndex();
    // Population is explicit and incremental; this creates only an empty
    // unlock-scoped index after the previous plaintext index was destroyed.
  }

  @override
  Future<void> onLocking() => onBackground();
}

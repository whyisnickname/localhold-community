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
  safeTitleAscending,
  safeTitleDescending,
}

final class VaultSearchFilter {
  const VaultSearchFilter({
    this.lifecycle,
    this.favoriteOnly = false,
    this.pinnedOnly = false,
    this.folderId,
    this.requiredTagIds = const {},
    this.sort = VaultRecordSort.updatedNewest,
  });

  final RecordLifecycle? lifecycle;
  final bool favoriteOnly;
  final bool pinnedOnly;
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
    this.safeSortKey = '',
  });

  final VaultRecord record;
  final Iterable<String> publicText;
  final Iterable<String> protectedText;
  final String safeSortKey;
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

  bool get protectedSearchAuthorized => _protectedSearchAuthorized;

  void revokeProtectedSearch() {
    _ensureAlive();
    _protectedSearchAuthorized = false;
  }

  void put(SearchDocument document) {
    _ensureAlive();
    _documents[document.record.id.value] = _IndexedDocument(
      record: document.record,
      publicText: _join(document.publicText),
      protectedText: _join(document.protectedText),
      safeSortKey: _normalizer.normalize(document.safeSortKey),
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
    _sort(results, filter.sort);
    return List.unmodifiable(results);
  }

  List<VaultRecord> browse({
    VaultSearchFilter filter = const VaultSearchFilter(),
  }) {
    _ensureAlive();
    final results = _documents.values
        .where((document) => _matchesFilter(document.record, filter))
        .map((document) => document.record)
        .toList(growable: false);
    _sort(results, filter.sort);
    return List.unmodifiable(results);
  }

  bool _matchesFilter(VaultRecord record, VaultSearchFilter filter) {
    if (filter.lifecycle != null && record.lifecycle != filter.lifecycle) {
      return false;
    }
    if (filter.favoriteOnly && !record.favorite) return false;
    if (filter.pinnedOnly && !record.pinned) return false;
    if (filter.folderId != null && record.folderId?.value != filter.folderId) {
      return false;
    }
    final tagIds = record.tagIds.map((tag) => tag.value).toSet();
    return tagIds.containsAll(filter.requiredTagIds);
  }

  void _sort(List<VaultRecord> records, VaultRecordSort sort) {
    records.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final result = switch (sort) {
        VaultRecordSort.updatedNewest => b.updatedAt.compareTo(a.updatedAt),
        VaultRecordSort.updatedOldest => a.updatedAt.compareTo(b.updatedAt),
        VaultRecordSort.createdNewest => b.createdAt.compareTo(a.createdAt),
        VaultRecordSort.createdOldest => a.createdAt.compareTo(b.createdAt),
        VaultRecordSort.safeTitleAscending => _safeSortKey(
          a,
        ).compareTo(_safeSortKey(b)),
        VaultRecordSort.safeTitleDescending => _safeSortKey(
          b,
        ).compareTo(_safeSortKey(a)),
      };
      return result != 0 ? result : a.id.value.compareTo(b.id.value);
    });
  }

  String _safeSortKey(VaultRecord record) =>
      _documents[record.id.value]?.safeSortKey ?? '';

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
    required this.safeSortKey,
  });

  final VaultRecord record;
  final String publicText;
  final String protectedText;
  final String safeSortKey;
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

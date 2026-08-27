// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  test('Unicode search separates public and protected values', () {
    final record = _record('Café');
    final index = VaultSearchIndex()
      ..put(
        SearchDocument(
          record: record,
          publicText: const ['Café'],
          protectedText: const ['Sëcret'],
        ),
      );

    expect(index.search('cafe'), [record]);
    expect(index.search('secret', includeProtected: true), isEmpty);
    index.authorizeProtectedSearch();
    expect(index.search('secret', includeProtected: true), [record]);
    expect(index.search('cafe\u0000secret', includeProtected: true), isEmpty);
  });

  test('incremental index can be cancelled at a batch boundary', () async {
    final index = VaultSearchIndex();
    final cancellation = SearchIndexCancellation();
    final progress = <SearchIndexProgress>[];
    final documents = List.generate(
      20,
      (index) => SearchDocument(
        record: _record('record-$index'),
        publicText: ['record-$index'],
        protectedText: const [],
      ),
    );

    await const VaultSearchIndexer(batchSize: 5).rebuild(
      index: index,
      documents: documents,
      cancellation: cancellation,
      onProgress: (value) {
        progress.add(value);
        if (value.completed == 5) cancellation.cancel();
      },
    );

    expect(index.length, 5);
    expect(progress.first.completed, 0);
    expect(progress.last.completed, 5);
  });

  test('10 000-record index and first result satisfy Stage 4 budget', () async {
    const count = 10000;
    final now = DateTime.utc(2026, 8, 26);
    final documents = List<SearchDocument>.generate(count, (index) {
      final suffix = index.toString().padLeft(10, '0');
      final record = VaultRecord(
        id: RecordId.parse('R${index.toString().padLeft(21, '0')}'),
        typeId: BuiltInRecordTypes.account,
        fields: [
          VaultField(
            id: FieldId.parse('F${index.toString().padLeft(21, '0')}'),
            kind: VaultFieldKind.text,
            label: 'Title',
            value: 'Local account $suffix',
            definitionId: 'title',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      return SearchDocument(
        record: record,
        publicText: ['Local account $suffix'],
        protectedText: const [],
      );
    }, growable: false);
    final searchIndex = VaultSearchIndex();
    final build = Stopwatch()..start();

    await const VaultSearchIndexer(batchSize: 250)
        .rebuild(index: searchIndex, documents: documents, onProgress: (_) {});
    build.stop();
    final firstResult = Stopwatch()..start();
    final result = searchIndex.search('account 0000009999');
    firstResult.stop();
    // Secret-free benchmark evidence for the Stage 4 test runner.
    // ignore: avoid_print
    print(
      'STAGE4_SEARCH index_us=${build.elapsedMicroseconds} '
      'first_result_us=${firstResult.elapsedMicroseconds} records=$count',
    );

    expect(searchIndex.length, count);
    expect(result.single.id, documents[9999].record.id);
    expect(
      build.elapsed,
      lessThanOrEqualTo(const Duration(seconds: 2)),
      reason: 'full index budget',
    );
    expect(
      firstResult.elapsed,
      lessThanOrEqualTo(const Duration(milliseconds: 150)),
      reason: 'first result budget',
    );
  });

  test('reveal permission expires and clears on background', () async {
    final authorization = RevealAuthorization();
    final observer = RevealAuthorizationObserver(authorization);
    final now = DateTime.utc(2026, 8, 26);
    authorization.authorize(now);
    expect(authorization.isAuthorized(now), isTrue);

    await observer.onBackground();
    expect(authorization.isAuthorized(now), isFalse);
  });

  test('master credential freshness is bounded to 30 days', () {
    final freshness = MasterCredentialFreshness();
    final now = DateTime.utc(2026, 8, 26);
    expect(freshness.requiresMasterCredential(now), isTrue);
    freshness.markVerified(now);
    expect(
      freshness.requiresMasterCredential(
        now.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
    expect(
      freshness.requiresMasterCredential(now.add(const Duration(days: 30))),
      isFalse,
    );
    expect(
      freshness.requiresMasterCredential(
        now.add(const Duration(days: 30, microseconds: 1)),
      ),
      isTrue,
    );
  });

  test('sensitive reveal state clears immediately on background', () async {
    final reveals = SensitiveRevealController();
    addTearDown(() => reveals.dispose());
    final fieldId = FieldId.generate().value;
    await reveals.onUnlocked(
      VaultId.generate(),
      VaultSessionRef.fromOpaque('test-session'),
    );
    reveals.revealField(fieldId);
    reveals.revealAll();
    expect(reveals.snapshot.isRevealed(fieldId), isTrue);

    await reveals.onBackground();

    expect(reveals.snapshot.revealAll, isFalse);
    expect(reveals.snapshot.revealedFieldIds, isEmpty);
    expect(() => reveals.revealField(fieldId), throwsA(isA<VaultFailure>()));
  });
}

VaultRecord _record(String value) {
  final now = DateTime.utc(2026, 8, 26);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.text,
        label: 'Title',
        value: value,
        definitionId: 'title',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:localhold_record_search_spike/record_search.dart';
import 'package:test/test.dart';

void main() {
  EncryptedRecordBlob blob(int index) => EncryptedRecordBlob(
        recordId: 'record-${index.toString().padLeft(5, '0')}',
        revision: 1,
        envelope: Uint8List.fromList(utf8.encode('synthetic-ciphertext-$index')),
      );

  UnlockedRecord open(EncryptedRecordBlob value) {
    final index = int.parse(value.recordId.substring(7));
    return UnlockedRecord(
      recordId: value.recordId,
      title: 'Synthetic Account $index',
      values: <String>['user$index@example.test', 'group ${index % 100}'],
    );
  }

  test('indexes and searches 10000 synthetic encrypted blobs', () {
    final blobs = List<EncryptedRecordBlob>.generate(10000, blob);
    final index = UnlockScopedSearchIndex();
    final stopwatch = Stopwatch()..start();
    index.build(blobs, open);
    stopwatch.stop();

    expect(index.indexedRecordCount, 10000);
    expect(index.search('user9999 example'), <String>['record-09999']);
    expect(index.search('group 42'), hasLength(100));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('lock clears index and rejects stale queries', () {
    final index = UnlockScopedSearchIndex()..build(<EncryptedRecordBlob>[blob(1)], open);
    index.clear();
    expect(index.indexedRecordCount, 0);
    expect(() => index.search('user1'), throwsStateError);
  });

  test('authenticated ID mismatch clears partial index', () {
    final index = UnlockScopedSearchIndex();
    expect(
      () => index.build(<EncryptedRecordBlob>[blob(1)], (_) => const UnlockedRecord(recordId: 'other', title: 'x', values: <String>[])),
      throwsStateError,
    );
    expect(index.isUnlocked, isFalse);
    expect(index.indexedRecordCount, 0);
  });
}

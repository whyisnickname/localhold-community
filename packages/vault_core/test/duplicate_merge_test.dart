// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('local duplicate detection', () {
    test('uses normalized safe features without exposing their values', () {
      final first = _account(
        title: 'Café',
        username: 'Owner',
        website: 'https://www.example.com/private?a=secret',
        password: 'vault-canary',
      );
      final second = _account(
        title: 'CAFE',
        username: 'owner',
        website: 'example.com/other',
        password: 'different',
      );

      final candidates = DuplicateDetector(
        definitions: BuiltInTemplateCatalog.all,
      ).scan([first, second]);

      expect(candidates, hasLength(1));
      expect(
        candidates.single.reasons,
        containsAll(<DuplicateMatchReason>{
          DuplicateMatchReason.title,
          DuplicateMatchReason.domain,
          DuplicateMatchReason.username,
        }),
      );
      expect(candidates.single.toString(), isNot(contains('vault-canary')));
      expect(candidates.single.toString(), isNot(contains('/private')));
    });

    test('never pairs different canonical types', () {
      final first = _account(title: 'Same', username: 'same');
      final second = _record(
        typeId: BuiltInRecordTypes.secureNote,
        fields: [_field('title', VaultFieldKind.text, 'Same')],
      );

      expect(
        DuplicateDetector(definitions: BuiltInTemplateCatalog.all)
            .scan([first, second]),
        isEmpty,
      );
    });

    test('protected exact match is opt-in and returns an enum only', () {
      final first = _account(title: 'First', password: 'same-secret');
      final second = _account(title: 'Second', password: 'same-secret');
      final detector = DuplicateDetector(
        definitions: BuiltInTemplateCatalog.all,
      );

      expect(detector.scan([first, second]), isEmpty);
      final protected = detector.scan([
        first,
        second,
      ], includeProtectedExactMatches: true);
      expect(protected, hasLength(1));
      expect(protected.single.reasons, {
        DuplicateMatchReason.protectedExactValue,
      });
      expect(protected.single.toString(), isNot(contains('same-secret')));
    });

    test(
      'conflict relationship is neutral and does not need a value match',
      () {
        final first = _account(title: 'Original');
        final copy = _account(title: 'Edited elsewhere', conflictOf: first.id);

        final candidate = DuplicateDetector(
          definitions: BuiltInTemplateCatalog.all,
        ).scan([first, copy]).single;

        expect(candidate.confidence, DuplicateConfidence.conflictCopy);
        expect(candidate.reasons, contains(DuplicateMatchReason.conflictCopy));
      },
    );

    test('bounds candidate expansion for a large shared bucket', () {
      final records = List.generate(
        40,
        (index) =>
            _account(title: 'Shared title $index', username: 'shared-user'),
      );
      final detector = DuplicateDetector(
        definitions: BuiltInTemplateCatalog.all,
        maximumCandidates: 25,
        maximumBucketMembers: 20,
      );

      expect(detector.scan(records), hasLength(25));
    });

    test('10 000-record local scan stays within the Stage 5 budget', () {
      final records = List.generate(
        10000,
        (index) =>
            _account(title: 'Record $index', username: 'local-user-$index'),
      );
      final detector = DuplicateDetector(
        definitions: BuiltInTemplateCatalog.all,
      );
      final stopwatch = Stopwatch()..start();

      final candidates = detector.scan(records);
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'STAGE5_DUPLICATE_SCAN scan_us=${stopwatch.elapsedMicroseconds} '
        'records=${records.length}',
      );
      expect(candidates, isEmpty);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('record merge planning', () {
    test('requires choices and combines metadata without deleting source', () {
      final targetTag = TagId.generate();
      final sourceTag = TagId.generate();
      final folder = FolderId.generate();
      final target = _account(
        title: 'Target',
        username: 'old-user',
        favorite: true,
        folderId: folder,
        tagIds: [targetTag],
      );
      final source = _account(
        title: 'Source',
        username: 'new-user',
        pinned: true,
        tagIds: [sourceTag],
        conflictOf: target.id,
      );
      final planner = RecordMergePlanner(
        definitions: BuiltInTemplateCatalog.all,
      );
      final preview = planner.prepare(target: target, source: source);
      final choices = {
        for (final slot in preview.slots)
          slot.id: slot.sourceField?.definitionId == 'username'
              ? MergeFieldChoice.source
              : MergeFieldChoice.target,
      };
      expect(choices.keys, containsAll(preview.slots.map((slot) => slot.id)));
      expect(choices, hasLength(preview.slots.length));

      final merged = planner.apply(
        preview: preview,
        choices: choices,
        now: DateTime.utc(2026, 9, 5, 12),
      );

      expect(
        merged.target.fields
            .firstWhere((field) => field.definitionId == 'username')
            .value,
        'new-user',
      );
      expect(merged.target.favorite, isTrue);
      expect(merged.target.pinned, isTrue);
      expect(merged.target.folderId, folder);
      expect(merged.target.tagIds, {targetTag, sourceTag});
      expect(merged.target.conflictOf, isNull);
      expect(merged.source.lifecycle, RecordLifecycle.trashed);
      expect(
        merged.source.fields.map((field) => field.id),
        orderedEquals(source.fields.map((field) => field.id)),
      );
      expect(
        merged.source.fields.map((field) => field.value),
        orderedEquals(source.fields.map((field) => field.value)),
      );
    });

    test('rejects different types and incomplete choices', () {
      final target = _account(title: 'Target');
      final otherType = _record(
        typeId: BuiltInRecordTypes.secureNote,
        fields: [_field('title', VaultFieldKind.text, 'Note')],
      );
      final planner = RecordMergePlanner(
        definitions: BuiltInTemplateCatalog.all,
      );

      expect(
        () => planner.prepare(target: target, source: otherType),
        throwsA(isA<VaultFailure>()),
      );
      final source = _account(title: 'Source');
      final preview = planner.prepare(target: target, source: source);
      expect(
        () => planner.apply(
          preview: preview,
          choices: const {},
          now: DateTime.utc(2026, 9, 5),
        ),
        throwsA(isA<VaultFailure>()),
      );
    });

    test('masks an unrecognized custom field by default', () {
      final target = _account(title: 'Target');
      final source = _record(
        typeId: BuiltInRecordTypes.account,
        fields: [
          _field('title', VaultFieldKind.text, 'Source'),
          VaultField(
            id: FieldId.generate(),
            kind: VaultFieldKind.text,
            label: 'Private custom value',
            value: 'custom-canary',
          ),
        ],
      );

      final preview = RecordMergePlanner(
        definitions: BuiltInTemplateCatalog.all,
      ).prepare(target: target, source: source);

      expect(
        preview.slots
            .singleWhere((slot) => slot.sourceField?.definitionId == null)
            .protected,
        isTrue,
      );
    });
  });
}

VaultRecord _account({
  required String title,
  String? username,
  String? website,
  String? password,
  bool favorite = false,
  bool pinned = false,
  FolderId? folderId,
  Iterable<TagId> tagIds = const [],
  RecordId? conflictOf,
}) => _record(
  typeId: BuiltInRecordTypes.account,
  fields: [
    _field('title', VaultFieldKind.text, title),
    if (username != null) _field('username', VaultFieldKind.username, username),
    if (website != null) _field('website', VaultFieldKind.url, website),
    if (password != null) _field('password', VaultFieldKind.secret, password),
  ],
  favorite: favorite,
  pinned: pinned,
  folderId: folderId,
  tagIds: tagIds,
  conflictOf: conflictOf,
);

VaultRecord _record({
  required String typeId,
  required List<VaultField> fields,
  bool favorite = false,
  bool pinned = false,
  FolderId? folderId,
  Iterable<TagId> tagIds = const [],
  RecordId? conflictOf,
}) {
  final now = DateTime.utc(2026, 9, 5);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: typeId,
    fields: fields,
    createdAt: now,
    updatedAt: now,
    favorite: favorite,
    pinned: pinned,
    folderId: folderId,
    tagIds: tagIds,
    conflictOf: conflictOf,
  );
}

VaultField _field(String definitionId, VaultFieldKind kind, String value) =>
    VaultField(
      id: FieldId.generate(),
      kind: kind,
      label: definitionId,
      value: value,
      definitionId: definitionId,
    );

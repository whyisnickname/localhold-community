// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('safe list and search', () {
    test('projection and ordinary search never contain protected canaries', () {
      const secret = 'ST5_D06_SECRET_CANARY';
      final record = _account(
        title: '',
        username: 'alice',
        password: secret,
        website: 'https://example.com/private/path?token=$secret',
      );
      final builder = SafeRecordProjectionBuilder(
        definitions: BuiltInTemplateCatalog.all,
      );

      final projection = builder.project(record);
      final document = builder.searchDocument(record);

      expect(projection.displayName, 'alice');
      expect(projection.secondary, 'example.com');
      expect(projection.toString(), isNot(contains(secret)));
      expect(document.publicText.join(' '), isNot(contains(secret)));
      expect(document.protectedText.join(' '), contains(secret));
    });

    test('protected matches keep the same masked-safe projection', () {
      const secret = 'only-in-protected-scope';
      final record = _account(title: 'Work', password: secret);
      final builder = SafeRecordProjectionBuilder(
        definitions: BuiltInTemplateCatalog.all,
      );
      final index = VaultSearchIndex()..put(builder.searchDocument(record));

      expect(index.search(secret, includeProtected: true), isEmpty);
      index.authorizeProtectedSearch();
      expect(index.search(secret, includeProtected: true), [record]);
      expect(builder.project(record).toString(), isNot(contains(secret)));
      index.revokeProtectedSearch();
      expect(index.search(secret, includeProtected: true), isEmpty);
    });

    test('browse supports pinned, lifecycle and deterministic title sort', () {
      final builder = SafeRecordProjectionBuilder(
        definitions: BuiltInTemplateCatalog.all,
      );
      final alpha = _account(title: 'Alpha').copyWith(pinned: true);
      final zulu = _account(title: 'Zulu').copyWith(pinned: true);
      final archived = _account(title: 'Archived')
          .copyWith(pinned: true, lifecycle: RecordLifecycle.archived);
      final index = VaultSearchIndex()
        ..put(builder.searchDocument(zulu))
        ..put(builder.searchDocument(archived))
        ..put(builder.searchDocument(alpha));

      expect(
        index.browse(
          filter: const VaultSearchFilter(
            lifecycle: RecordLifecycle.active,
            pinnedOnly: true,
            sort: VaultRecordSort.safeTitleAscending,
          ),
        ),
        [alpha, zulu],
      );
    });
  });

  group('organization mutations', () {
    test('folder hierarchy has breadcrumb and a hard depth limit of 16', () {
      var organization = VaultOrganization.empty();
      FolderId? parent;
      for (
        var index = 0;
        index < VaultOrganizationMutations.maximumDepth;
        index++
      ) {
        final folder = VaultFolder(
          id: FolderId.generate(),
          name: 'Level $index',
          parentId: parent,
        );
        organization = VaultOrganizationMutations.addFolder(
          organization,
          folder,
        );
        parent = folder.id;
      }
      expect(
        VaultOrganizationMutations.breadcrumb(organization, parent!),
        hasLength(16),
      );
      expect(
        () => VaultOrganizationMutations.addFolder(
          organization,
          VaultFolder(
            id: FolderId.generate(),
            name: 'Too deep',
            parentId: parent,
          ),
        ),
        throwsA(_failure(VaultFailureCode.invalidInput)),
      );
    });

    test('folder move rejects cycles', () {
      final root = VaultFolder(id: FolderId.generate(), name: 'Root');
      final child = VaultFolder(
        id: FolderId.generate(),
        name: 'Child',
        parentId: root.id,
      );
      final organization = VaultOrganization(
        id: OrganizationId.generate(),
        folders: [root, child],
        tags: const [],
      );

      expect(
        () => VaultOrganizationMutations.moveFolder(
          organization,
          root.id,
          child.id,
        ),
        throwsA(_failure(VaultFailureCode.invalidInput)),
      );
    });

    test('tag merge rewrites assignments and delete never deletes records', () {
      final source = VaultTag(id: TagId.generate(), name: 'Old');
      final target = VaultTag(id: TagId.generate(), name: 'New');
      final organization = VaultOrganization(
        id: OrganizationId.generate(),
        folders: const [],
        tags: [source, target],
      );
      final record = _account(title: 'Tagged')
          .copyWith(tagIds: [source.id, target.id]);

      final merged = VaultOrganizationMutations.mergeTag(
        organization: organization,
        records: [record],
        sourceId: source.id,
        targetId: target.id,
        now: DateTime.utc(2026, 9, 5),
      );
      expect(merged.organization.tags, [target]);
      expect(merged.records.single.tagIds, {target.id});

      final deleted = VaultOrganizationMutations.deleteTag(
        organization: merged.organization,
        records: merged.records,
        tagId: target.id,
        now: DateTime.utc(2026, 9, 5),
      );
      expect(deleted.organization.tags, isEmpty);
      expect(deleted.records.single.tagIds, isEmpty);
      expect(deleted.records.single.id, record.id);
    });

    test('bulk command has a closed safe mutation allowlist', () {
      final now = DateTime.utc(2026, 9, 5);
      final records = [_account(title: 'One'), _account(title: 'Two')];
      final updated = applyBulkRecordCommand(
        records,
        const BulkRecordCommand.setFavorite(true),
        now: now,
      );

      expect(updated.every((record) => record.favorite), isTrue);
      expect(BulkRecordMutationKind.values.map((value) => value.name), [
        'moveToFolder',
        'addTags',
        'removeTags',
        'setFavorite',
        'archive',
        'moveToTrash',
      ]);
    });
  });

  test('legacy record and editor draft default pinned to false', () {
    final record = _account(title: 'Legacy');
    final recordJson = Map<String, Object?>.from(record.toJson())
      ..remove('pinned');
    expect(VaultRecord.fromJson(recordJson).pinned, isFalse);

    final snapshot = EditorDraftSnapshot.fromRecord(
      record.copyWith(
        pinned: true,
        favorite: true,
        lifecycle: RecordLifecycle.archived,
      ),
    );
    final restored = EditorDraftSnapshot.fromJson(snapshot.toJson());
    final materialized = restored.materialize(now: DateTime.utc(2026, 9, 6));
    expect(materialized.pinned, isTrue);
    expect(materialized.favorite, isTrue);
    expect(materialized.lifecycle, RecordLifecycle.archived);
  });
}

VaultRecord _account({
  String title = '',
  String username = '',
  String password = '',
  String website = '',
}) {
  final now = DateTime.utc(2026, 9, 5);
  return VaultRecord(
    id: RecordId.generate(),
    typeId: BuiltInRecordTypes.account,
    fields: [
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.text,
        label: 'Title',
        value: title,
        definitionId: 'title',
      ),
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.username,
        label: 'Username',
        value: username,
        definitionId: 'username',
      ),
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.secret,
        label: 'Password',
        value: password,
        definitionId: 'password',
      ),
      VaultField(
        id: FieldId.generate(),
        kind: VaultFieldKind.url,
        label: 'Website',
        value: website,
        definitionId: 'website',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );
}

Matcher _failure(VaultFailureCode code) =>
    isA<VaultFailure>().having((error) => error.code, 'code', code);

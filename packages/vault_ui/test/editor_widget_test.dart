// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_ui/localhold_vault_ui.dart';

void main() {
  testWidgets('editor reflows at 320 px and 200% Russian text', (tester) async {
    await _surface(tester);
    final controller = _editorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        textScale: 2,
        child: RecordEditorScreen(
          controller: controller,
          onSaved: (_) {},
          onAddCustomField: () {},
        ),
      ),
    );

    expect(find.text('Новая запись'), findsOneWidget);
    expect(find.text('Сохранить запись'), findsOneWidget);
    expect(find.text('Название'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty back flow exposes all four explicit choices', (
    tester,
  ) async {
    final controller = _editorController();
    await tester.pumpWidget(
      _app(
        child: RecordEditorScreen(controller: controller, onSaved: (_) {}),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Changed');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Save record')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Save draft')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Continue editing')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Delete draft')),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets('record view conceals secret and clears reveal on background', (
    tester,
  ) async {
    final template = _template(BuiltInRecordTypes.account);
    final now = DateTime.utc(2026, 9, 5);
    var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
    final title = snapshot.fields.first;
    final password = snapshot.fields.singleWhere(
      (field) => field.definitionId == 'password',
    );
    snapshot = snapshot.withFieldValue(title.id, 'Personal');
    snapshot = snapshot.withFieldValue(password.id, 'canary-secret');
    final controller = RecordViewController(
      record: snapshot.materialize(now: now),
      template: template,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        child: RecordViewScreen(
          controller: controller,
          onEdit: () {},
          onCopy: (_) {},
          onPermanentDelete: () {},
        ),
      ),
    );

    expect(find.text('canary-secret'), findsNothing);
    await tester.tap(find.byTooltip('Reveal'));
    await tester.pump();
    expect(find.text('canary-secret'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('canary-secret'), findsNothing);
  });

  testWidgets('secret-only record uses a localized safe type fallback', (
    tester,
  ) async {
    final template = _template(BuiltInRecordTypes.account);
    final now = DateTime.utc(2026, 9, 5);
    var snapshot = EditorDraftSnapshot.fromTemplate(template, now: now);
    final password = snapshot.fields.singleWhere(
      (field) => field.definitionId == 'password',
    );
    snapshot = snapshot.withFieldValue(password.id, 'canary-secret');
    final controller = RecordViewController(
      record: snapshot.materialize(now: now),
      template: template,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        locale: const Locale('ru'),
        child: RecordViewScreen(
          controller: controller,
          onEdit: () {},
          onCopy: (_) {},
          onPermanentDelete: () {},
        ),
      ),
    );
    expect(find.text('Аккаунт'), findsWidgets);
    expect(find.text('canary-secret'), findsNothing);
  });

  testWidgets('TOTP review rejects web links and never renders the secret', (
    tester,
  ) async {
    Map<String, Object?>? added;
    await tester.pumpWidget(
      _app(child: TotpIntakeDialog(onAdd: (value) => added = value)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('totp_value')),
      'https://example.test/',
    );
    await tester.tap(find.text('Review'));
    await tester.pump();
    expect(find.text('This is not a valid TOTP value.'), findsOneWidget);
    expect(added, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('totp_value')),
      'otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example',
    );
    await tester.tap(find.text('Review'));
    await tester.pump();
    expect(find.text('Review before adding'), findsOneWidget);
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);
    await tester.tap(find.text('Add to draft'));
    await tester.pump();
    expect(added?['account'], 'alice');
  });

  testWidgets(
    'conversion preview masks values while explaining every outcome',
    (tester) async {
      final now = DateTime.utc(2026, 9, 5);
      final sourceTemplate = _template(BuiltInRecordTypes.account);
      var source = EditorDraftSnapshot.fromTemplate(sourceTemplate, now: now);
      final password = source.fields.singleWhere(
        (field) => field.definitionId == 'password',
      );
      source = source.withFieldValue(password.id, 'canary-secret');
      final preview = const RecordConversionPlanner().preview(
        source: source,
        target: _template(BuiltInRecordTypes.socialProfile),
      );
      await tester.pumpWidget(
        _app(
          child: RecordConversionScreen(preview: preview, onApply: (_) {}),
        ),
      );
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Mapped'), findsOneWidget);
      expect(find.text('canary-secret'), findsNothing);
    },
  );

  testWidgets('attachment denial is an actionable closed state', (
    tester,
  ) async {
    final queue = AttachmentQueueController(
      coordinator: AttachmentIntakeCoordinator(
        acquisition: _DeniedAcquisition(),
        store: _NoopStore(),
      ),
      creationPolicy: const _AllowPolicy(),
    );
    addTearDown(queue.dispose);
    await tester.pumpWidget(
      _app(child: AttachmentIntakePanel(controller: queue)),
    );
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Permission was denied. You can enable it in system settings.'),
      findsOneWidget,
    );
  });
}

RecordEditorController _editorController() {
  final now = DateTime.utc(2026, 9, 5);
  final template = _template(BuiltInRecordTypes.secureNote);
  return RecordEditorController(
    draft: EditorDraftDocument.create(
      snapshot: EditorDraftSnapshot.fromTemplate(template, now: now),
      now: now,
    ),
    template: template,
    port: _EditorPort(),
    creationPolicy: const CommunityFreeVaultCreationPolicy(),
    autosaveDelay: const Duration(days: 1),
    now: () => now,
  );
}

RecordTypeDefinition _template(String id) =>
    BuiltInTemplateCatalog.all.singleWhere((value) => value.stableId == id);

Widget _app({
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: LocalholdLocalizations.supportedLocales,
  localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
  theme: LocalholdTheme.light(),
  builder: (context, value) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: value!,
  ),
  home: child,
);

Future<void> _surface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.reset);
}

final class _EditorPort implements RecordEditorPort {
  @override
  Future<EditorDraftSaveResult> saveDraft(
    EditorDraftDocument draft, {
    required bool alreadyPersisted,
    required DateTime now,
  }) async => EditorDraftSaveResult.saved(draft);

  @override
  Future<RecordMutationResult> commit(
    EditorDraftDocument draft, {
    required DateTime now,
    required bool draftWasPersisted,
  }) async => RecordMutationResult.saved(draft.snapshot.materialize(now: now));

  @override
  Future<void> discardDraft(EditorDraftDocument draft) async {}
}

final class _DeniedAcquisition implements AttachmentAcquisitionPort {
  @override
  Future<AttachmentAcquisitionResult> acquire(
    AttachmentSourceKind kind,
  ) async => const AttachmentAcquisitionResult.permissionDenied();
}

final class _AllowPolicy implements VaultCreationPolicy {
  const _AllowPolicy();

  @override
  void requireAllowed(VaultCreationCapability capability) {}
}

final class _NoopStore implements AttachmentCipherStore {
  @override
  Future<void> cancel(AttachmentId id) async {}

  @override
  Future<void> importEncrypted({
    required AttachmentId id,
    required Stream<List<int>> plaintext,
    required int declaredSize,
  }) async {}

  @override
  Future<void> moveToTrash(AttachmentId id) async {}

  @override
  Stream<Uint8List> openVerified(AttachmentId id) => const Stream.empty();

  @override
  Future<void> permanentlyDelete(AttachmentId id) async {}

  @override
  Future<void> restoreFromTrash(AttachmentId id) async {}
}

// SPDX-License-Identifier: MPL-2.0

// This independent entrypoint is never referenced by the release entrypoint.
// Run it explicitly with: flutter run -t lib/stage4_diagnostics_main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:localhold_vault_native/localhold_vault_native.dart';
import 'package:localhold_vault_storage/localhold_vault_storage.dart';
import 'package:path_provider/path_provider.dart';

const _releaseExclusionMarker = 'LOCALHOLD_STAGE4_DIAGNOSTIC_ONLY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await _DiagnosticRuntime.open();
  runApp(_DiagnosticApp(runtime: runtime));
}

final class _DiagnosticRuntime {
  _DiagnosticRuntime({
    required this.database,
    required this.runtime,
    required this.sessions,
    required this.search,
  });

  final LocalholdVaultDatabase database;
  final LocalVaultRuntime runtime;
  final VaultSessionCoordinator sessions;
  final SearchSessionObserver search;
  VaultId? vaultId;
  LocalVaultActivation? activation;

  static Future<_DiagnosticRuntime> open() async {
    final support = await getApplicationSupportDirectory();
    final temporary = await getTemporaryDirectory();
    final bridge = LocalholdKeyBridge();
    final database = await openNativeVaultDatabase(
      databaseFile: File(
        '${support.path}${Platform.pathSeparator}stage4-diagnostics${Platform.pathSeparator}vault.sqlite',
      ),
      privateTemporaryDirectory: Directory(
        '${temporary.path}${Platform.pathSeparator}stage4-diagnostics',
      ),
      backupExclusion: NativeBackupExclusionGateway(bridge),
    );
    final gateway = NativeVaultKeyGateway(
      bridge: bridge,
      envelopeStore: DriftVaultEnvelopeStore(database),
    );
    final search = SearchSessionObserver(createIndex: VaultSearchIndex.new);
    final privacy = PrivacySessionObserver(
      PrivacyLifecycleCoordinator(NativeVaultPrivacyGateway(bridge)),
    );
    final sessions = VaultSessionCoordinator(
      gateway: gateway,
      unlockThrottle: PersistentUnlockThrottle(
        store: DriftUnlockThrottleStore(database),
      ),
      observers: [search, privacy],
    );
    final runtime = LocalVaultRuntime(
      database: database,
      gateway: gateway,
      sessions: sessions,
      selection: DriftVaultSelectionStore(database),
      creationPolicy: const CommunityFreeVaultCreationPolicy(),
      backupExclusion: NativeBackupExclusionGateway(bridge),
      attachmentRoot: Directory(
        '${support.path}${Platform.pathSeparator}stage4-diagnostics${Platform.pathSeparator}attachments',
      ),
      previewTemporaryRoot: Directory(
        '${temporary.path}${Platform.pathSeparator}stage4-diagnostics${Platform.pathSeparator}previews',
      ),
    );
    return _DiagnosticRuntime(
      database: database,
      runtime: runtime,
      sessions: sessions,
      search: search,
    );
  }

  Future<String> createSyntheticVault() async {
    await sessions.lock();
    final id = VaultId.generate();
    final password = Uint8List.fromList(
      utf8.encode('diagnostic-only-master-password'),
    );
    activation = await runtime.create(
      vaultId: id,
      localizedName: 'Diagnostic vault',
      masterPassword: password,
      now: DateTime.now().toUtc(),
      isAdditionalVault: false,
    );
    vaultId = id;
    return 'vault-created';
  }

  Future<String> createSyntheticRecord() async {
    final now = DateTime.now().toUtc();
    final record = VaultRecord(
      id: RecordId.generate(),
      typeId: BuiltInRecordTypes.account,
      fields: [
        VaultField(
          id: FieldId.generate(),
          kind: VaultFieldKind.text,
          label: 'Synthetic title',
          value: 'diagnostic-record',
          definitionId: 'title',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final services =
        activation?.services ??
        (throw const VaultFailure(VaultFailureCode.sessionLocked));
    await services.records.create(record);
    search.requireIndex.put(
      SearchDocument(
        record: record,
        publicText: const ['diagnostic-record'],
        protectedText: const [],
      ),
    );
    return 'record-created';
  }

  Future<String> indexSyntheticRecords() async {
    final index = search.requireIndex;
    final now = DateTime.now().toUtc();
    for (var number = 0; number < 10000; number++) {
      final record = VaultRecord(
        id: RecordId.generate(),
        typeId: BuiltInRecordTypes.account,
        fields: [
          VaultField(
            id: FieldId.generate(),
            kind: VaultFieldKind.text,
            label: 'Synthetic title',
            value: 'item-$number',
            definitionId: 'title',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      index.put(
        SearchDocument(
          record: record,
          publicText: ['item-$number'],
          protectedText: const [],
        ),
      );
    }
    return 'index-size-${index.length}';
  }

  Future<String> lock() async {
    await sessions.lock();
    return 'locked';
  }

  Future<void> dispose() async {
    await sessions.dispose();
    await database.close();
  }
}

final class _DiagnosticApp extends StatelessWidget {
  const _DiagnosticApp({required this.runtime});

  final _DiagnosticRuntime runtime;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Stage 4 diagnostics',
    home: _DiagnosticScreen(runtime: runtime),
  );
}

final class _DiagnosticScreen extends StatefulWidget {
  const _DiagnosticScreen({required this.runtime});

  final _DiagnosticRuntime runtime;

  @override
  State<_DiagnosticScreen> createState() => _DiagnosticScreenState();
}

final class _DiagnosticScreenState extends State<_DiagnosticScreen>
    with WidgetsBindingObserver {
  String _status = 'ready: $_releaseExclusionMarker';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.runtime.sessions.enterForeground());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.runtime.sessions.enterBackground());
    } else if (state == AppLifecycleState.detached) {
      unawaited(widget.runtime.sessions.lock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.runtime.dispose());
    super.dispose();
  }

  Future<void> _run(Future<String> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (mounted) setState(() => _status = result);
    } on VaultFailure catch (failure) {
      if (mounted) setState(() => _status = 'failure:${failure.code.name}');
    } on Object {
      if (mounted) setState(() => _status = 'failure:internalFailure');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stage 4 diagnostics')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SelectableText(_status),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(widget.runtime.createSyntheticVault),
            child: const Text('Create synthetic vault'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(widget.runtime.createSyntheticRecord),
            child: const Text('Create encrypted record'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(widget.runtime.indexSyntheticRecords),
            child: const Text('Build 10,000-record memory index'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(widget.runtime.lock),
            child: const Text('Lock and destroy session'),
          ),
        ],
      ),
    ),
  );
}

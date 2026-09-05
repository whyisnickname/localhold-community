// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_access/localhold_vault_access.dart';

import 'access_issue_view.dart';
import 'unlock_controller.dart';
import 'vault_picker.dart';

final class UnlockScreen extends StatefulWidget {
  const UnlockScreen({
    required this.controller,
    required this.onUnlocked,
    required this.onRecover,
    this.onAccount,
    super.key,
  });

  final UnlockController controller;
  final VoidCallback onUnlocked;
  final VoidCallback onRecover;
  final VoidCallback? onAccount;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

final class _UnlockScreenState extends State<UnlockScreen> {
  final _password = TextEditingController();
  bool _reportedUnlock = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleState);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(UnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleState);
      widget.controller.addListener(_handleState);
      _reportedUnlock = false;
      widget.controller.load();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleState);
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  void _handleState() {
    final unlocked = widget.controller.state.phase == UnlockPhase.unlocked;
    if (unlocked && !_reportedUnlock) {
      _reportedUnlock = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnlocked();
      });
    } else if (!unlocked) {
      _reportedUnlock = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final strings = LocalholdLocalizations.of(context);
          final state = widget.controller.state;
          final selected = state.selectedEntry;
          final busy =
              state.phase == UnlockPhase.loading ||
              state.phase == UnlockPhase.unlocking;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(LocalholdSpacing.lg),
                children: [
                  const Icon(Icons.lock_outline, size: 48, semanticLabel: ''),
                  const SizedBox(height: LocalholdSpacing.lg),
                  Text(
                    strings.unlockTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: LocalholdSpacing.sm),
                    Text(
                      localizedLockedVaultLabel(strings, selected),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  if (state.issue case final issue?) ...[
                    const SizedBox(height: LocalholdSpacing.md),
                    AccessIssueView(issue: issue),
                  ],
                  if (state.entries.length > 1) ...[
                    const SizedBox(height: LocalholdSpacing.md),
                    ExpansionTile(
                      title: Text(strings.unlockChooseVault),
                      children: [
                        VaultPicker(
                          entries: state.entries,
                          selectedVaultId: state.selectedVaultId,
                          onSelected: widget.controller.selectVault,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: LocalholdSpacing.lg),
                  TextField(
                    controller: _password,
                    enabled: !busy && selected != null,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: strings.unlockPassword,
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: LocalholdSpacing.md),
                  FilledButton(
                    onPressed: busy || selected == null ? null : _unlock,
                    child: Text(strings.unlockAction),
                  ),
                  if (state.biometricState == VaultBiometricState.configured)
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : widget.controller.unlockWithBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(strings.unlockBiometric),
                    ),
                  TextButton(
                    onPressed: busy || selected == null
                        ? null
                        : widget.onRecover,
                    child: Text(strings.unlockRecovery),
                  ),
                  if (widget.onAccount != null)
                    TextButton(
                      onPressed: busy ? null : widget.onAccount,
                      child: Text(strings.onboardingAccountSecondary),
                    ),
                  if (busy) ...[
                    const SizedBox(height: LocalholdSpacing.md),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> _unlock() async {
    final bytes = Uint8List.fromList(utf8.encode(_password.text));
    _password.clear();
    await widget.controller.unlockWithPassword(bytes);
  }
}

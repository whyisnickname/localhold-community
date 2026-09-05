// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

import 'access_issue_view.dart';
import 'recovery_input.dart';
import 'recovery_unlock_controller.dart';

final class RecoveryUnlockScreen extends StatefulWidget {
  const RecoveryUnlockScreen({
    required this.controller,
    required this.onRecovered,
    required this.onCancel,
    super.key,
  });

  final RecoveryUnlockController controller;
  final VoidCallback onRecovered;
  final VoidCallback onCancel;

  @override
  State<RecoveryUnlockScreen> createState() => _RecoveryUnlockScreenState();
}

final class _RecoveryUnlockScreenState extends State<RecoveryUnlockScreen> {
  final _phrase = TextEditingController();
  final _newPassword = TextEditingController();
  bool _reportedComplete = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleState);
  }

  @override
  void didUpdateWidget(RecoveryUnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleState);
      widget.controller.addListener(_handleState);
      _reportedComplete = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleState);
    _phrase.clear();
    _newPassword.clear();
    _phrase.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _handleState() {
    if (widget.controller.state.complete && !_reportedComplete) {
      _reportedComplete = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRecovered();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: widget.controller.state.busy ? null : widget.onCancel,
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final strings = LocalholdLocalizations.of(context);
          final state = widget.controller.state;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(LocalholdSpacing.lg),
                children: [
                  Text(
                    strings.recoveryUnlockTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: LocalholdSpacing.sm),
                  Text(strings.recoveryUnlockBody),
                  if (state.issue case final issue?) ...[
                    const SizedBox(height: LocalholdSpacing.md),
                    AccessIssueView(issue: issue),
                  ],
                  const SizedBox(height: LocalholdSpacing.lg),
                  TextField(
                    controller: _phrase,
                    enabled: !state.busy,
                    minLines: 3,
                    maxLines: 5,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: strings.recoveryUnlockPhrase,
                    ),
                  ),
                  const SizedBox(height: LocalholdSpacing.md),
                  TextField(
                    controller: _newPassword,
                    enabled: !state.busy,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: strings.recoveryUnlockNewPassword,
                    ),
                    onSubmitted: (_) => _recover(),
                  ),
                  const SizedBox(height: LocalholdSpacing.md),
                  FilledButton(
                    onPressed: state.busy ? null : _recover,
                    child: Text(strings.recoveryUnlockAction),
                  ),
                  if (state.busy) ...[
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

  Future<void> _recover() async {
    final phrase = encodeRecoveryWords(_phrase.text);
    final password = Uint8List.fromList(utf8.encode(_newPassword.text));
    _phrase.clear();
    _newPassword.clear();
    await widget.controller.recover(
      recoveryPhraseUtf8: phrase,
      newMasterPassword: password,
    );
  }
}

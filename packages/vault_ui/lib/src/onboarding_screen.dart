// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

import 'access_issue_view.dart';
import 'onboarding_controller.dart';
import 'recovery_input.dart';

final class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.controller,
    required this.onOpenVault,
    required this.onAddFirstRecord,
    this.onImport,
    this.onAccount,
    super.key,
  });

  final OnboardingController controller;
  final VoidCallback onOpenVault;
  final VoidCallback onAddFirstRecord;
  final VoidCallback? onImport;
  final VoidCallback? onAccount;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final Map<int, TextEditingController> _challenge = {};
  bool _showNameWhileLocked = false;

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _name.dispose();
    for (final controller in _challenge.values) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(LocalholdSpacing.lg),
                children: [
                  if (state.issue case final issue?)
                    AccessIssueView(issue: issue),
                  AnimatedSwitcher(
                    duration: LocalholdMotion.effective(
                      context,
                      LocalholdMotion.standard,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(state.step),
                      child: _step(context, state),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _step(BuildContext context, OnboardingState state) {
    final strings = LocalholdLocalizations.of(context);
    return switch (state.step) {
      OnboardingStep.trust => _OnboardingSection(
        icon: Icons.shield_outlined,
        title: strings.onboardingTrustTitle,
        body: strings.onboardingTrustBody,
        children: [
          FilledButton.icon(
            onPressed: state.busy ? null : widget.controller.chooseGuest,
            icon: const Icon(Icons.lock_outline),
            label: Text(strings.onboardingLocalVault),
          ),
          if (widget.onImport != null)
            OutlinedButton(
              onPressed: widget.onImport,
              child: Text(strings.onboardingImport),
            ),
          if (widget.onAccount != null)
            TextButton(
              onPressed: widget.onAccount,
              child: Text(strings.onboardingAccountSecondary),
            ),
        ],
      ),
      OnboardingStep.masterPassword => _OnboardingSection(
        icon: Icons.password_outlined,
        title: strings.onboardingMasterTitle,
        body: strings.onboardingMasterBody,
        children: [
          TextField(
            controller: _name,
            enabled: !state.busy,
            textInputAction: TextInputAction.next,
            maxLength: 256,
            decoration: InputDecoration(labelText: strings.onboardingVaultName),
          ),
          TextField(
            controller: _password,
            enabled: !state.busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: strings.onboardingMasterPassword,
            ),
            onSubmitted: (_) => _createVault(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _showNameWhileLocked,
            onChanged: state.busy
                ? null
                : (value) =>
                      setState(() => _showNameWhileLocked = value ?? false),
            title: Text(strings.onboardingShowNameLocked),
          ),
          FilledButton(
            onPressed: state.busy ? null : _createVault,
            child: Text(strings.commonContinue),
          ),
        ],
      ),
      OnboardingStep.recoveryChoice => _OnboardingSection(
        icon: Icons.key_outlined,
        title: strings.onboardingRecoveryTitle,
        body: strings.onboardingRecoveryBody,
        children: [
          FilledButton(
            onPressed: state.busy ? null : widget.controller.beginRecovery,
            child: Text(strings.onboardingRecoveryStart),
          ),
          TextButton(
            onPressed: state.busy ? null : widget.controller.skipRecovery,
            child: Text(strings.onboardingRecoverySkip),
          ),
          Text(strings.onboardingRecoveryWarning),
        ],
      ),
      OnboardingStep.recoveryChallenge => _OnboardingSection(
        icon: Icons.fact_check_outlined,
        title: strings.onboardingRecoveryTitle,
        body: strings.onboardingRecoveryBody,
        children: [
          for (final position in state.recoveryPositions)
            TextField(
              controller: _challenge.putIfAbsent(
                position,
                TextEditingController.new,
              ),
              enabled: !state.busy,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: strings.onboardingRecoveryChallenge(position),
              ),
            ),
          FilledButton(
            onPressed: state.busy ? null : _confirmRecovery,
            child: Text(strings.onboardingRecoveryConfirm),
          ),
          TextButton(
            onPressed: state.busy ? null : widget.controller.cancelRecovery,
            child: Text(strings.commonCancel),
          ),
        ],
      ),
      OnboardingStep.biometrics => _OnboardingSection(
        icon: Icons.fingerprint,
        title: strings.onboardingBiometricTitle,
        body: strings.onboardingBiometricBody,
        children: [
          FilledButton(
            onPressed: state.busy ? null : widget.controller.enableBiometric,
            child: Text(strings.onboardingBiometricEnable),
          ),
          TextButton(
            onPressed: state.busy ? null : widget.controller.skipBiometric,
            child: Text(strings.onboardingBiometricSkip),
          ),
        ],
      ),
      OnboardingStep.complete => _OnboardingSection(
        icon: Icons.verified_user_outlined,
        title: strings.onboardingCompleteTitle,
        body: state.recoverySkipped
            ? strings.onboardingRecoveryWarning
            : strings.homeSafetyReady,
        children: [
          FilledButton(
            onPressed: widget.onAddFirstRecord,
            child: Text(strings.onboardingAddFirst),
          ),
          OutlinedButton(
            onPressed: widget.onOpenVault,
            child: Text(strings.onboardingOpenVault),
          ),
        ],
      ),
    };
  }

  Future<void> _createVault() async {
    final passwordBytes = Uint8List.fromList(utf8.encode(_password.text));
    _password.clear();
    await widget.controller.createLocalVault(
      name: _name.text,
      masterPassword: passwordBytes,
      showNameWhileLocked: _showNameWhileLocked,
    );
  }

  Future<void> _confirmRecovery() async {
    final state = widget.controller.state;
    final words = <String>[];
    for (final position in state.recoveryPositions) {
      words.add(_challenge[position]?.text.trim() ?? '');
    }
    final bytes = encodeRecoveryChallenge(words);
    for (final controller in _challenge.values) {
      controller.clear();
    }
    await widget.controller.confirmRecovery(bytes);
  }
}

final class _OnboardingSection extends StatelessWidget {
  const _OnboardingSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(icon, size: 48, semanticLabel: ''),
      const SizedBox(height: LocalholdSpacing.lg),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: LocalholdSpacing.sm),
      Text(body, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: LocalholdSpacing.xl),
      ...children.expand(
        (child) => [child, const SizedBox(height: LocalholdSpacing.sm)],
      ),
    ],
  );
}

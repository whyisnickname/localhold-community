// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

import 'onboarding_controller.dart';

final class AccessIssueView extends StatelessWidget {
  const AccessIssueView({required this.issue, super.key});

  final VaultAccessIssue issue;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final message = switch (issue) {
      VaultAccessIssue.invalidInput => strings.accessInvalidInput,
      VaultAccessIssue.invalidCredentials => strings.accessInvalidCredentials,
      VaultAccessIssue.cooldown => strings.unlockCooldown,
      VaultAccessIssue.storageFull => strings.stateDiskFull,
      VaultAccessIssue.readOnly => strings.stateReadOnly,
      VaultAccessIssue.biometricUnavailable ||
      VaultAccessIssue.unavailable => strings.commonUnavailable,
      VaultAccessIssue.biometricInvalidated ||
      VaultAccessIssue.integrityFailure => strings.accessIntegrityFailure,
      VaultAccessIssue.unknown => strings.accessUnknownFailure,
    };
    return Semantics(
      liveRegion: true,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(LocalholdSpacing.md),
          child: Text(message),
        ),
      ),
    );
  }
}

// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'local_duplicate_controller.dart';
import 'template_field_localizations.dart';

final class LocalDuplicateScreen extends StatelessWidget {
  const LocalDuplicateScreen({required this.controller, super.key});

  final LocalDuplicateController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      final strings = LocalholdLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(strings.duplicatesTitle)),
        body: SafeArea(
          child: switch (state.status) {
            DuplicateStatus.locked => const SizedBox.shrink(),
            DuplicateStatus.loading || DuplicateStatus.merging => const Center(
              child: CircularProgressIndicator(),
            ),
            _ when state.merge != null => _MergeBody(
              controller: controller,
              merge: state.merge!,
              issue: state.issue,
            ),
            _ => _CandidateBody(controller: controller, state: state),
          },
        ),
      );
    },
  );
}

final class _CandidateBody extends StatelessWidget {
  const _CandidateBody({required this.controller, required this.state});

  final LocalDuplicateController controller;
  final LocalDuplicateState state;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(LocalholdSpacing.md),
      children: [
        Text(strings.duplicatesIntro),
        const SizedBox(height: LocalholdSpacing.md),
        FilledButton.icon(
          onPressed: controller.scan,
          icon: const Icon(Icons.find_in_page_outlined),
          label: Text(strings.duplicatesScan),
        ),
        const SizedBox(height: LocalholdSpacing.sm),
        OutlinedButton.icon(
          onPressed: controller.scanProtected,
          icon: const Icon(Icons.security_outlined),
          label: Text(strings.duplicatesProtectedScan),
        ),
        if (state.protectedComparison) ...[
          const SizedBox(height: LocalholdSpacing.sm),
          Semantics(
            label: strings.duplicatesProtectedBadge,
            child: Chip(
              avatar: const Icon(Icons.verified_user_outlined),
              label: Text(strings.duplicatesProtectedBadge),
            ),
          ),
        ],
        if (state.issue case final issue?) ...[
          const SizedBox(height: LocalholdSpacing.sm),
          _IssueBanner(issue: issue),
        ],
        const SizedBox(height: LocalholdSpacing.lg),
        if (state.status == DuplicateStatus.initial ||
            state.status == DuplicateStatus.empty)
          Text(strings.duplicatesEmpty)
        else
          for (final candidate in state.candidates) ...[
            _CandidateCard(candidate: candidate, controller: controller),
            const SizedBox(height: LocalholdSpacing.md),
          ],
      ],
    );
  }
}

final class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.controller});

  final LocalDuplicateCandidateView candidate;
  final LocalDuplicateController controller;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final conflict = candidate.confidence == DuplicateConfidence.conflictCopy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LocalholdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(switch (candidate.confidence) {
              DuplicateConfidence.possible => strings.duplicatesPossible,
              DuplicateConfidence.likely => strings.duplicatesLikely,
              DuplicateConfidence.conflictCopy => strings.duplicatesConflict,
            }, style: Theme.of(context).textTheme.titleMedium),
            if (conflict) ...[
              const SizedBox(height: LocalholdSpacing.xs),
              Text(strings.duplicatesConflictHint),
            ],
            const SizedBox(height: LocalholdSpacing.sm),
            _SafeRecordSummary(value: candidate.first),
            const Divider(),
            _SafeRecordSummary(value: candidate.second),
            const SizedBox(height: LocalholdSpacing.sm),
            Wrap(
              spacing: LocalholdSpacing.xs,
              runSpacing: LocalholdSpacing.xs,
              children: candidate.reasons
                  .map((reason) => Chip(label: Text(_reason(strings, reason))))
                  .toList(growable: false),
            ),
            const SizedBox(height: LocalholdSpacing.sm),
            OutlinedButton(
              onPressed: () => controller.prepareMerge(
                candidate.first.id,
                candidate.second.id,
                targetId: candidate.first.id,
              ),
              child: Text(strings.duplicatesUseFirst),
            ),
            const SizedBox(height: LocalholdSpacing.xs),
            OutlinedButton(
              onPressed: () => controller.prepareMerge(
                candidate.first.id,
                candidate.second.id,
                targetId: candidate.second.id,
              ),
              child: Text(strings.duplicatesUseSecond),
            ),
          ],
        ),
      ),
    );
  }

  String _reason(LocalholdLocalizations strings, DuplicateMatchReason reason) =>
      switch (reason) {
        DuplicateMatchReason.title => strings.duplicatesReasonTitle,
        DuplicateMatchReason.domain => strings.duplicatesReasonDomain,
        DuplicateMatchReason.username => strings.duplicatesReasonUsername,
        DuplicateMatchReason.email => strings.duplicatesReasonEmail,
        DuplicateMatchReason.identifier => strings.duplicatesReasonIdentifier,
        DuplicateMatchReason.protectedExactValue =>
          strings.duplicatesReasonProtected,
        DuplicateMatchReason.conflictCopy => strings.duplicatesReasonConflict,
      };
}

final class _SafeRecordSummary extends StatelessWidget {
  const _SafeRecordSummary({required this.value});

  final SafeRecordProjection value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.description_outlined),
    title: Text(value.displayName),
    subtitle: value.secondary == null ? null : Text(value.secondary!),
  );
}

final class _MergeBody extends StatelessWidget {
  const _MergeBody({
    required this.controller,
    required this.merge,
    required this.issue,
  });

  final LocalDuplicateController controller;
  final LocalMergeView merge;
  final DuplicateIssue? issue;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(LocalholdSpacing.md),
      children: [
        Text(
          strings.mergeTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LocalholdSpacing.sm),
        Text(strings.mergeChooseEach),
        const SizedBox(height: LocalholdSpacing.md),
        _RecordRole(
          label: strings.mergeTarget,
          record: merge.target,
          icon: Icons.save_outlined,
        ),
        const SizedBox(height: LocalholdSpacing.xs),
        _RecordRole(
          label: strings.mergeSource,
          record: merge.source,
          icon: Icons.delete_outline,
        ),
        if (issue != null) ...[
          const SizedBox(height: LocalholdSpacing.sm),
          _IssueBanner(issue: issue!),
        ],
        const SizedBox(height: LocalholdSpacing.md),
        for (final field in merge.fields) ...[
          _MergeFieldCard(
            field: field,
            typeId: merge.target.typeId,
            controller: controller,
          ),
          const SizedBox(height: LocalholdSpacing.sm),
        ],
        Text(
          strings.mergeResult(
            merge.target.displayName,
            merge.source.displayName,
          ),
        ),
        const SizedBox(height: LocalholdSpacing.md),
        FilledButton.icon(
          onPressed: controller.canCommitMerge
              ? () => _confirmMerge(context, controller)
              : null,
          icon: const Icon(Icons.merge_outlined),
          label: Text(strings.mergeAction),
        ),
        TextButton(
          onPressed: controller.cancelMerge,
          child: Text(strings.mergeCancel),
        ),
      ],
    );
  }
}

final class _RecordRole extends StatelessWidget {
  const _RecordRole({
    required this.label,
    required this.record,
    required this.icon,
  });

  final String label;
  final SafeRecordProjection record;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: ${record.displayName}',
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(record.displayName),
    ),
  );
}

final class _MergeFieldCard extends StatelessWidget {
  const _MergeFieldCard({
    required this.field,
    required this.typeId,
    required this.controller,
  });

  final LocalMergeFieldView field;
  final String typeId;
  final LocalDuplicateController controller;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(LocalholdSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizedTemplateFieldStableLabel(
                strings,
                typeId,
                field.definitionId,
                field.label,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: LocalholdSpacing.xs),
            if (field.targetAvailable)
              ChoiceChip(
                selected: field.choice == MergeFieldChoice.target,
                onSelected: (_) =>
                    controller.choose(field.id, MergeFieldChoice.target),
                label: Text('${strings.mergeFromTarget}: ${field.targetValue}'),
              ),
            if (field.sourceAvailable) ...[
              const SizedBox(height: LocalholdSpacing.xs),
              ChoiceChip(
                selected: field.choice == MergeFieldChoice.source,
                onSelected: (_) =>
                    controller.choose(field.id, MergeFieldChoice.source),
                label: Text('${strings.mergeFromSource}: ${field.sourceValue}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.issue});

  final DuplicateIssue issue;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return MaterialBanner(
      content: Text(
        issue == DuplicateIssue.authorizationDenied
            ? strings.duplicatesAuthorizationDenied
            : strings.mergeFailed,
      ),
      actions: const [SizedBox.shrink()],
    );
  }
}

Future<void> _confirmMerge(
  BuildContext context,
  LocalDuplicateController controller,
) async {
  final strings = LocalholdLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings.mergeConfirmTitle),
      content: Text(strings.mergeConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(strings.mergeAction),
        ),
      ],
    ),
  );
  if (accepted == true) {
    await controller.commitMerge(now: DateTime.now());
  }
}

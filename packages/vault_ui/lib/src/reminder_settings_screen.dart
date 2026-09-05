// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

import 'reminder_settings_controller.dart';

final class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({required this.controller, super.key});

  final ReminderSettingsController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.state;
      final strings = LocalholdLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(strings.reminderTitle)),
        body: SafeArea(
          child: state.status == ReminderSettingsStatus.locked
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.all(LocalholdSpacing.md),
                  children: [
                    if (state.status == ReminderSettingsStatus.explanation)
                      _PermissionExplanation(controller: controller)
                    else ...[
                      if (state.status != ReminderSettingsStatus.editing)
                        _StatusPanel(controller: controller, state: state),
                      _ScheduleEditor(controller: controller, state: state),
                    ],
                  ],
                ),
        ),
      );
    },
  );
}

final class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({required this.controller, required this.state});

  final ReminderSettingsController controller;
  final ReminderSettingsState state;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.reminderWhen, style: theme.textTheme.titleMedium),
        const SizedBox(height: LocalholdSpacing.sm),
        Wrap(
          spacing: LocalholdSpacing.xs,
          runSpacing: LocalholdSpacing.xs,
          children: [
            _OffsetChip(
              label: strings.reminderDayOf,
              days: 0,
              state: state,
              controller: controller,
            ),
            _OffsetChip(
              label: strings.reminderOneDay,
              days: 1,
              state: state,
              controller: controller,
            ),
            _OffsetChip(
              label: strings.reminderThreeDays,
              days: 3,
              state: state,
              controller: controller,
            ),
            _OffsetChip(
              label: strings.reminderSevenDays,
              days: 7,
              state: state,
              controller: controller,
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _chooseCustomOffset(context, controller),
            icon: const Icon(Icons.tune_outlined),
            label: Text(strings.reminderCustomOffset),
          ),
        ),
        const SizedBox(height: LocalholdSpacing.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(strings.reminderTime),
          subtitle: Text(_formatMinute(context, state.preferredMinute)),
          onTap: () => _chooseTime(context, controller, state.preferredMinute),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(strings.reminderQuietHours),
          subtitle: Text(
            '${_formatMinute(context, state.quietStartMinute)} – '
            '${_formatMinute(context, state.quietEndMinute)}',
          ),
          onTap: () => _chooseQuietHours(context, controller, state),
        ),
        const Divider(height: LocalholdSpacing.xl),
        Text(strings.reminderPrivacy, style: theme.textTheme.titleMedium),
        Text(strings.reminderPrivacyHint),
        RadioGroup<ReminderPrivacy>(
          groupValue: state.privacy,
          onChanged: (value) {
            if (value != null) controller.setPrivacy(value);
          },
          child: Column(
            children: [
              RadioListTile<ReminderPrivacy>(
                value: ReminderPrivacy.private,
                title: Text(strings.reminderPrivate),
                subtitle: Text(strings.reminderPrivateHint),
              ),
              RadioListTile<ReminderPrivacy>(
                value: ReminderPrivacy.safeName,
                title: Text(strings.reminderName),
              ),
              RadioListTile<ReminderPrivacy>(
                value: ReminderPrivacy.safeNameAndAmount,
                title: Text(strings.reminderNameAmount),
              ),
            ],
          ),
        ),
        const SizedBox(height: LocalholdSpacing.md),
        FilledButton.icon(
          onPressed: state.status == ReminderSettingsStatus.working
              ? null
              : controller.beginEnable,
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(strings.reminderEnable),
        ),
      ],
    );
  }
}

final class _OffsetChip extends StatelessWidget {
  const _OffsetChip({
    required this.label,
    required this.days,
    required this.state,
    required this.controller,
  });

  final String label;
  final int days;
  final ReminderSettingsState state;
  final ReminderSettingsController controller;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: state.offsetMinutes == days * 24 * 60,
    onSelected: (_) => controller.setOffset(ReminderOffset.days(days)),
  );
}

final class _PermissionExplanation extends StatelessWidget {
  const _PermissionExplanation({required this.controller});

  final ReminderSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.notifications_none_outlined, size: 48),
        const SizedBox(height: LocalholdSpacing.md),
        Text(
          strings.reminderPermissionTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LocalholdSpacing.sm),
        Text(strings.reminderPermissionBody),
        const SizedBox(height: LocalholdSpacing.lg),
        FilledButton(
          onPressed: controller.confirmEnable,
          child: Text(strings.reminderContinue),
        ),
        TextButton(
          onPressed: controller.returnToEditing,
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}

final class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.controller, required this.state});

  final ReminderSettingsController controller;
  final ReminderSettingsState state;

  @override
  Widget build(BuildContext context) {
    final strings = LocalholdLocalizations.of(context);
    final message = switch (state.status) {
      ReminderSettingsStatus.working => strings.reminderWorking,
      ReminderSettingsStatus.scheduled => strings.reminderScheduled,
      ReminderSettingsStatus.permissionDenied =>
        strings.reminderPermissionDenied,
      ReminderSettingsStatus.permissionRestricted =>
        strings.reminderPermissionRestricted,
      ReminderSettingsStatus.past => strings.reminderPast,
      ReminderSettingsStatus.recoverableFailure => strings.reminderFailed,
      _ => '',
    };
    if (message.isEmpty) return const SizedBox.shrink();
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(LocalholdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (state.status == ReminderSettingsStatus.permissionDenied ||
                state.status == ReminderSettingsStatus.permissionRestricted)
              TextButton(
                onPressed: controller.openSystemSettings,
                child: Text(strings.reminderOpenSettings),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatMinute(BuildContext context, int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

Future<void> _chooseTime(
  BuildContext context,
  ReminderSettingsController controller,
  int minute,
) async {
  final value = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
  );
  if (value != null)
    controller.setPreferredMinute(value.hour * 60 + value.minute);
}

Future<void> _chooseQuietHours(
  BuildContext context,
  ReminderSettingsController controller,
  ReminderSettingsState state,
) async {
  final start = await showTimePicker(
    context: context,
    helpText: LocalholdLocalizations.of(context).reminderQuietStart,
    initialTime: TimeOfDay(
      hour: state.quietStartMinute ~/ 60,
      minute: state.quietStartMinute % 60,
    ),
  );
  if (!context.mounted || start == null) return;
  final end = await showTimePicker(
    context: context,
    helpText: LocalholdLocalizations.of(context).reminderQuietEnd,
    initialTime: TimeOfDay(
      hour: state.quietEndMinute ~/ 60,
      minute: state.quietEndMinute % 60,
    ),
  );
  if (end != null) {
    controller.setQuietHours(
      ReminderQuietHours(
        startMinute: start.hour * 60 + start.minute,
        endMinute: end.hour * 60 + end.minute,
      ),
    );
  }
}

Future<void> _chooseCustomOffset(
  BuildContext context,
  ReminderSettingsController controller,
) async {
  final strings = LocalholdLocalizations.of(context);
  final input = TextEditingController();
  final days = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(strings.reminderCustomOffset),
      content: TextField(
        controller: input,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: strings.reminderDaysBefore,
          helperText: strings.reminderCustomRange,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(input.text)),
          child: Text(strings.commonConfirm),
        ),
      ],
    ),
  );
  input.dispose();
  if (days != null) controller.setOffset(ReminderOffset.days(days));
}

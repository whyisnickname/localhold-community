// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  test('ready state carries only the typed view model', () {
    const state = LocalholdViewState<String>.ready('safe display model');

    expect(state.status, LocalholdViewStatus.ready);
    expect(state.data, 'safe display model');
    expect(state.issue, isNull);
    expect(state.isFailure, isFalse);
  });

  test(
    'failure uses closed issue and recovery enums with optional safe data',
    () {
      const state = LocalholdViewState<int>.failure(
        status: LocalholdViewStatus.readOnly,
        issue: LocalholdIssueCode.storageFull,
        recoveryAction: LocalholdRecoveryAction.freeDeviceSpace,
        lastSafeData: 7,
      );

      expect(state.status, LocalholdViewStatus.readOnly);
      expect(state.issue, LocalholdIssueCode.storageFull);
      expect(state.recoveryAction, LocalholdRecoveryAction.freeDeviceSpace);
      expect(state.hasUsableData, isTrue);
    },
  );

  test('failure constructor rejects non-failure states', () {
    final invalidStatus = LocalholdViewStatus.ready;
    expect(
      () => LocalholdViewState<String>.failure(
        status: invalidStatus,
        issue: LocalholdIssueCode.invalidInput,
        recoveryAction: LocalholdRecoveryAction.editInput,
      ),
      throwsAssertionError,
    );
  });
}

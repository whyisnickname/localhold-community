// SPDX-License-Identifier: MPL-2.0

enum LocalholdViewStatus {
  initial,
  loading,
  ready,
  empty,
  permissionRequired,
  permissionDenied,
  offlineBlocked,
  unavailable,
  recoverableFailure,
  readOnly,
  corrupt,
  expiredCapability,
  locked,
}

enum LocalholdIssueCode {
  permissionDenied,
  networkBlocked,
  storageUnavailable,
  storageFull,
  writeFailed,
  dataCorrupt,
  capabilityUnavailable,
  entitlementExpired,
  sessionLocked,
  invalidInput,
}

enum LocalholdRecoveryAction {
  none,
  retry,
  openSettings,
  continueOffline,
  unlock,
  freeDeviceSpace,
  editInput,
  continueFree,
}

/// Presentation-safe asynchronous state.
///
/// It intentionally carries a closed issue code instead of exception text or
/// arbitrary metadata, preventing provider errors and secret values from being
/// rendered or persisted by generic UI components.
final class LocalholdViewState<T> {
  const LocalholdViewState._({
    required this.status,
    this.data,
    this.issue,
    this.recoveryAction = LocalholdRecoveryAction.none,
  });

  const LocalholdViewState.initial()
    : this._(status: LocalholdViewStatus.initial);

  const LocalholdViewState.loading()
    : this._(status: LocalholdViewStatus.loading);

  const LocalholdViewState.ready(T value)
    : this._(status: LocalholdViewStatus.ready, data: value);

  const LocalholdViewState.empty() : this._(status: LocalholdViewStatus.empty);

  const LocalholdViewState.failure({
    required LocalholdViewStatus status,
    required this.issue,
    required this.recoveryAction,
    T? lastSafeData,
  }) : assert(
         status != LocalholdViewStatus.initial &&
             status != LocalholdViewStatus.loading &&
             status != LocalholdViewStatus.ready &&
             status != LocalholdViewStatus.empty,
         'Use a dedicated non-failure constructor for this status.',
       ),
       status = status,
       data = lastSafeData;

  final LocalholdViewStatus status;
  final T? data;
  final LocalholdIssueCode? issue;
  final LocalholdRecoveryAction recoveryAction;

  bool get hasUsableData => data != null;
  bool get isFailure => issue != null;
}

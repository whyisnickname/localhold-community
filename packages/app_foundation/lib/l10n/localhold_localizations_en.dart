// SPDX-License-Identifier: MPL-2.0

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'localhold_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LocalholdLocalizationsEn extends LocalholdLocalizations {
  LocalholdLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Localhold';

  @override
  String get navVault => 'Vault';

  @override
  String get navSubscriptions => 'Subscriptions';

  @override
  String get navSecurity => 'Security';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionLock => 'Lock';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionContinueOffline => 'Continue offline';

  @override
  String get valueHidden => 'Hidden value';

  @override
  String get stateEmptyTitle => 'Nothing here yet';

  @override
  String get stateOfflineLocalAvailable =>
      'Offline — local features are available';

  @override
  String get stateDiskFull => 'Could not save: the device is out of space';

  @override
  String get stateReadOnly => 'The vault is read-only to protect your data';

  @override
  String get stateExpired => 'Free is active. Existing data remains available.';

  @override
  String get stateLocked => 'Unlock your local vault to continue';

  @override
  String get premiumTrialCta => 'Try Premium for 14 days';

  @override
  String get premiumContinueFree => 'Continue with Free';

  @override
  String get onboardingLocalVault => 'Create local vault';

  @override
  String get privacyStrictOffline => 'Strict offline mode';

  @override
  String get commonUnavailable =>
      'This feature is unavailable in the current build';

  @override
  String get onboardingTrustTitle => 'Your data stays on this device';

  @override
  String get onboardingTrustBody =>
      'Localhold cannot see your vault, master password, recovery words, or files.';

  @override
  String get onboardingImport => 'Import data';

  @override
  String get onboardingAccountSecondary => 'Use an account for Premium';

  @override
  String get onboardingMasterTitle => 'Create a master password';

  @override
  String get onboardingMasterBody =>
      'Use at least 15 characters. Localhold cannot recover this password.';

  @override
  String get onboardingVaultName => 'Vault name';

  @override
  String get onboardingMasterPassword => 'Master password';

  @override
  String get onboardingShowNameLocked => 'Show this name while locked';

  @override
  String get onboardingRecoveryTitle => 'Create recovery words';

  @override
  String get onboardingRecoveryBody =>
      'Store them somewhere safe. They are the only recovery option if you forget the master password.';

  @override
  String get onboardingRecoveryStart => 'Show recovery words';

  @override
  String get onboardingRecoverySkip => 'Skip for now';

  @override
  String get onboardingRecoveryWarning =>
      'Without recovery words, a forgotten master password means losing access to the vault.';

  @override
  String onboardingRecoveryChallenge(int position) {
    return 'Enter word $position';
  }

  @override
  String get onboardingRecoveryConfirm => 'Confirm recovery words';

  @override
  String get onboardingBiometricTitle => 'Use device unlock?';

  @override
  String get onboardingBiometricBody =>
      'Biometrics are optional. Your master password remains available.';

  @override
  String get onboardingBiometricEnable => 'Enable biometrics';

  @override
  String get onboardingBiometricSkip => 'Not now';

  @override
  String get onboardingCompleteTitle => 'Your local vault is ready';

  @override
  String get onboardingAddFirst => 'Add first record';

  @override
  String get onboardingOpenVault => 'Open vault';

  @override
  String get unlockTitle => 'Unlock vault';

  @override
  String get unlockPassword => 'Master password';

  @override
  String get unlockAction => 'Unlock';

  @override
  String get unlockBiometric => 'Use biometrics';

  @override
  String get unlockRecovery => 'Recover access';

  @override
  String get unlockChooseVault => 'Choose vault';

  @override
  String unlockNeutralVault(int ordinal) {
    return 'Vault $ordinal';
  }

  @override
  String get unlockCooldown => 'Too many attempts. Try again later.';

  @override
  String get homeSafetyTitle => 'Security status';

  @override
  String get homeSafetyReady => 'Recovery and device unlock are configured';

  @override
  String get homeSafetyRecoveryMissing =>
      'Create recovery words to protect access';

  @override
  String get homeQuickFilters => 'Quick filters';

  @override
  String get homeTypes => 'Record types';

  @override
  String get homeRecents => 'Recent records';

  @override
  String get homeNoRecents => 'Recent records will appear here';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get accessInvalidInput => 'Check the entered information';

  @override
  String get accessInvalidCredentials => 'The master password is not correct';

  @override
  String get accessIntegrityFailure => 'The vault cannot be opened safely';

  @override
  String get accessUnknownFailure =>
      'Something went wrong. Your existing data was not changed.';

  @override
  String get recoveryUnlockTitle => 'Recover vault access';

  @override
  String get recoveryUnlockBody =>
      'Enter your recovery words and choose a new master password.';

  @override
  String get recoveryUnlockPhrase => 'Recovery words';

  @override
  String get recoveryUnlockNewPassword => 'New master password';

  @override
  String get recoveryUnlockAction => 'Recover and unlock';

  @override
  String get typePickerTitle => 'Choose a record type';

  @override
  String get typePickerSearch => 'Search record types';

  @override
  String get typePickerRecent => 'Recently used';

  @override
  String get typePickerNoResults => 'No record types found';

  @override
  String get typePickerCustom => 'Create your own type';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get templateCategoryAccounts => 'Accounts';

  @override
  String get templateCategoryMoney => 'Money';

  @override
  String get templateCategoryPersonal => 'Personal';

  @override
  String get templateCategoryTechnical => 'Technical';

  @override
  String get templateAccount => 'Account';

  @override
  String get templateSocialProfile => 'Social network';

  @override
  String get templateEmailAccount => 'Email account';

  @override
  String get templateGamingAccount => 'Gaming account';

  @override
  String get templateSubscription => 'Subscription';

  @override
  String get templatePaymentCard => 'Bank card';

  @override
  String get templateBankDetails => 'Bank details';

  @override
  String get templateIdentity => 'Personal contact';

  @override
  String get templateIdentityDocument => 'Passport or document';

  @override
  String get templateSecureNote => 'Secure note';

  @override
  String get templateSoftwareLicense => 'Software license';

  @override
  String get templateWirelessNetwork => 'Wi-Fi network';

  @override
  String get templateRouter => 'Router';

  @override
  String get templateServer => 'Server or hosting';

  @override
  String get templateDatabase => 'Database';

  @override
  String get templateApiCredential => 'API key or token';

  @override
  String get templateSshCredential => 'SSH key or certificate';

  @override
  String get templateRecoveryCodes => 'Recovery codes';

  @override
  String get templateCryptoAccount => 'Cryptocurrency account';

  @override
  String get editorCreateTitle => 'New record';

  @override
  String get editorEditTitle => 'Edit record';

  @override
  String get editorAdvanced => 'More details';

  @override
  String get editorDraftSaving => 'Saving draft…';

  @override
  String get editorDraftSaved => 'Draft saved';

  @override
  String get editorDraftFailed => 'Draft was not saved. Try again.';

  @override
  String get editorDraftConflict =>
      'A separate draft was kept because this record changed elsewhere.';

  @override
  String get editorSaveRecord => 'Save record';

  @override
  String get editorSaveDraft => 'Save draft';

  @override
  String get editorContinueEditing => 'Continue editing';

  @override
  String get editorDeleteDraft => 'Delete draft';

  @override
  String get editorBackTitle => 'Keep your changes?';

  @override
  String get editorBackBody =>
      'Choose what to do with this encrypted local draft.';

  @override
  String get editorDeleteFieldTitle => 'Remove this field?';

  @override
  String get editorDeleteFieldBody =>
      'The field has a value. You can undo removal until the record is saved.';

  @override
  String get editorRemoveField => 'Remove field';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorOneValueRequired => 'Enter a value in at least one field.';

  @override
  String get editorAddTotp => 'Add one-time password';

  @override
  String get editorAddAttachment => 'Add file or image';

  @override
  String get editorAddCustomField => 'Add custom field';

  @override
  String get editorPremiumRequired => 'Premium is required to add this item.';

  @override
  String get recordViewEdit => 'Edit';

  @override
  String get recordViewReveal => 'Reveal';

  @override
  String get recordViewHide => 'Hide';

  @override
  String get recordViewCopy => 'Copy';

  @override
  String get recordViewDelete => 'Delete permanently';

  @override
  String get recordViewEmpty => 'This record has no visible values.';

  @override
  String get conversionTitle => 'Change record type';

  @override
  String get conversionMapped => 'Mapped';

  @override
  String get conversionUnmapped => 'Kept as an extra field';

  @override
  String get conversionIncompatible => 'Incompatible — kept as an extra field';

  @override
  String get conversionApply => 'Apply conversion';

  @override
  String get totpImportTitle => 'Add one-time password';

  @override
  String get totpUriOrSecret => 'TOTP link or Base32 secret';

  @override
  String get totpIssuer => 'Issuer';

  @override
  String get totpAccount => 'Account';

  @override
  String get totpReview => 'Review before adding';

  @override
  String get totpInvalid => 'This is not a valid TOTP value.';

  @override
  String get totpAdd => 'Add to draft';

  @override
  String get totpScanQr => 'Scan QR code';

  @override
  String get totpImportQrImage => 'Read QR from image';

  @override
  String get totpAlgorithm => 'Algorithm';

  @override
  String get totpDigits => 'Digits';

  @override
  String get totpPeriod => 'Period';

  @override
  String get actionReview => 'Review';

  @override
  String get attachmentFile => 'Choose file';

  @override
  String get attachmentPhoto => 'Choose photo';

  @override
  String get attachmentCamera => 'Take photo';

  @override
  String get attachmentPermissionDenied =>
      'Permission was denied. You can enable it in system settings.';

  @override
  String get attachmentUnavailable =>
      'This source is unavailable on this device.';

  @override
  String get attachmentImportFailed =>
      'The file was not added. No partial attachment was kept.';

  @override
  String get attachmentImporting => 'Encrypting on this device…';

  @override
  String get attachmentCancel => 'Cancel import';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get warningDoNotStoreCardPin =>
      'Avoid storing a card PIN unless you truly need it. Never share it.';

  @override
  String get warningLocalholdNotWallet =>
      'Localhold is not a cryptocurrency wallet. Storing recovery material here carries extra risk.';

  @override
  String get vaultAllRecords => 'All records';

  @override
  String get vaultSearch => 'Search records';

  @override
  String get vaultSearchProtected => 'Search protected fields';

  @override
  String get vaultSearchProtectedActive => 'Protected search is on';

  @override
  String get vaultSearchProtectedHint =>
      'After verification, this search can match passwords, tokens and other protected fields. Results stay masked.';

  @override
  String get vaultSearchAuthorizationDenied =>
      'Verification was not completed. Protected search stayed off.';

  @override
  String get vaultNoRecords => 'No records match this view.';

  @override
  String get vaultLoadFailed =>
      'Records could not be loaded. Your stored data was not changed.';

  @override
  String get vaultTryAgain => 'Try again';

  @override
  String get vaultLayoutCompact => 'Compact list';

  @override
  String get vaultLayoutComfortable => 'Comfortable list';

  @override
  String get vaultLayoutGrid => 'Grid';

  @override
  String get vaultSortNewest => 'Recently updated';

  @override
  String get vaultSortOldest => 'Least recently updated';

  @override
  String get vaultSortTitleAsc => 'Title A–Z';

  @override
  String get vaultSortTitleDesc => 'Title Z–A';

  @override
  String get vaultFilterAll => 'Active';

  @override
  String get vaultFilterFavorites => 'Favorites';

  @override
  String get vaultFilterPinned => 'Pinned';

  @override
  String get vaultFilterArchive => 'Archive';

  @override
  String get vaultFilterTrash => 'Trash';

  @override
  String get vaultFavorite => 'Favorite';

  @override
  String get vaultPinned => 'Pinned';

  @override
  String get vaultFolder => 'Folder';

  @override
  String get vaultAnyFolder => 'Any folder';

  @override
  String get vaultTags => 'Tags';

  @override
  String vaultSelected(int count) {
    return 'Selected: $count';
  }

  @override
  String get vaultBulkMove => 'Move';

  @override
  String get vaultBulkTags => 'Tags';

  @override
  String get vaultBulkFavorite => 'Favorite';

  @override
  String get vaultBulkArchive => 'Archive';

  @override
  String get vaultBulkTrash => 'Move to Trash';

  @override
  String get vaultBulkExport => 'Export selected';

  @override
  String get vaultRestore => 'Restore';

  @override
  String get vaultTrashRetention =>
      'Items stay in Trash for 30 days before they become eligible for permanent deletion.';

  @override
  String get vaultStorageActionFailed =>
      'The change was not saved. Existing records stayed safe.';

  @override
  String get vaultExportFailed =>
      'Export did not start. Records were not changed.';

  @override
  String get organizationTitle => 'Folders and tags';

  @override
  String get organizationFolders => 'Folders';

  @override
  String get organizationTags => 'Tags';

  @override
  String get organizationAddFolder => 'Add folder';

  @override
  String get organizationAddTag => 'Add tag';

  @override
  String get organizationName => 'Name';

  @override
  String get organizationRename => 'Rename';

  @override
  String get organizationMove => 'Move';

  @override
  String get organizationMerge => 'Merge into another tag';

  @override
  String get organizationDelete => 'Delete';

  @override
  String get organizationDeleteFolderHint =>
      'Subfolders and records move to the parent folder. No record is deleted.';

  @override
  String get organizationDeleteTagHint =>
      'The tag is removed from records. No record is deleted.';

  @override
  String get organizationEmpty => 'You have no folders or tags yet.';

  @override
  String get organizationSaveFailed =>
      'The change was not saved. The previous organization is still available.';

  @override
  String get duplicatesTitle => 'Possible duplicates';

  @override
  String get duplicatesScan => 'Scan records';

  @override
  String get duplicatesProtectedScan => 'Compare protected values';

  @override
  String get duplicatesProtectedBadge => 'Protected comparison is on';

  @override
  String get duplicatesEmpty => 'No possible duplicates found.';

  @override
  String get duplicatesIntro =>
      'Localhold compares records only on this device. A match is a suggestion, not proof.';

  @override
  String get duplicatesPossible => 'Possible match';

  @override
  String get duplicatesLikely => 'Likely match';

  @override
  String get duplicatesConflict => 'Conflict copy';

  @override
  String get duplicatesConflictHint =>
      'Both versions are kept. Compare them and choose the values you want; neither version is selected automatically.';

  @override
  String get duplicatesReasonTitle => 'same title';

  @override
  String get duplicatesReasonDomain => 'same website domain';

  @override
  String get duplicatesReasonUsername => 'same username';

  @override
  String get duplicatesReasonEmail => 'same email';

  @override
  String get duplicatesReasonIdentifier => 'same identifier';

  @override
  String get duplicatesReasonProtected => 'an exact protected value matches';

  @override
  String get duplicatesReasonConflict => 'saved as a conflict copy';

  @override
  String get duplicatesUseFirst => 'Use first as base';

  @override
  String get duplicatesUseSecond => 'Use second as base';

  @override
  String get mergeTitle => 'Compare and merge';

  @override
  String get mergeTarget => 'Keep record';

  @override
  String get mergeSource => 'Move to Trash';

  @override
  String get mergeChooseEach =>
      'Choose which value to keep for every field. Protected values stay masked.';

  @override
  String get mergeFromTarget => 'From kept record';

  @override
  String get mergeFromSource => 'From other record';

  @override
  String mergeResult(String target, String source) {
    return 'The selected values will be saved in $target. $source will move to Trash and can still be restored.';
  }

  @override
  String get mergeAction => 'Merge';

  @override
  String get mergeConfirmTitle => 'Merge these records?';

  @override
  String get mergeConfirmBody =>
      'This updates the kept record and moves the other record to Trash in one local operation.';

  @override
  String get mergeCancel => 'Back to candidates';

  @override
  String get mergeFailed =>
      'Nothing was changed. Both previous records are still available.';

  @override
  String get duplicatesAuthorizationDenied =>
      'Protected comparison was not enabled.';

  @override
  String get reminderTitle => 'Reminder';

  @override
  String get reminderWhen => 'When to remind';

  @override
  String get reminderDayOf => 'On the day';

  @override
  String get reminderOneDay => '1 day before';

  @override
  String get reminderThreeDays => '3 days before';

  @override
  String get reminderSevenDays => '7 days before';

  @override
  String get reminderCustomOffset => 'Custom time before';

  @override
  String get reminderDaysBefore => 'Days before';

  @override
  String get reminderCustomRange => 'From 0 to 365 days';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get reminderQuietHours => 'Quiet hours';

  @override
  String get reminderQuietStart => 'Quiet hours start';

  @override
  String get reminderQuietEnd => 'Quiet hours end';

  @override
  String get reminderPrivacy => 'Notification privacy';

  @override
  String get reminderPrivacyHint =>
      'Secrets and protected values are never shown in a notification.';

  @override
  String get reminderPrivate => 'Private';

  @override
  String get reminderPrivateHint => 'Shows only a generic Localhold reminder.';

  @override
  String get reminderName => 'Show record name';

  @override
  String get reminderNameAmount => 'Show record name and safe amount';

  @override
  String get reminderEnable => 'Enable reminder';

  @override
  String get reminderPermissionTitle => 'Notification permission';

  @override
  String get reminderPermissionBody =>
      'Localhold needs system permission to show this reminder. The default notification is generic and contains no record data. You can change this later.';

  @override
  String get reminderContinue => 'Continue to system permission';

  @override
  String get reminderWorking => 'Saving and scheduling this reminder…';

  @override
  String get reminderScheduled => 'Reminder scheduled on this device.';

  @override
  String get reminderPermissionDenied =>
      'The reminder is saved but disabled because notification permission was denied.';

  @override
  String get reminderPermissionRestricted =>
      'The reminder is saved but disabled because notifications are restricted on this device.';

  @override
  String get reminderPast =>
      'This time has already passed. Choose a future time.';

  @override
  String get reminderFailed =>
      'The reminder was not scheduled. Your record was not changed.';

  @override
  String get reminderOpenSettings => 'Open system settings';

  @override
  String get shareInboxTitle => 'Shared with Localhold';

  @override
  String get shareInboxEmpty => 'Nothing is waiting to be imported.';

  @override
  String get shareImportFailed =>
      'The item was not imported. No partial draft was kept.';

  @override
  String get shareKindText => 'Shared text';

  @override
  String get shareKindUrl => 'Shared link';

  @override
  String get shareKindFile => 'Shared file';

  @override
  String get shareKindImage => 'Shared image';

  @override
  String shareBytes(int count) {
    return '$count bytes';
  }

  @override
  String get shareProtectedHint =>
      'The content stays in protected device storage and becomes an encrypted draft only after import.';

  @override
  String get shareImport => 'Import as encrypted draft';

  @override
  String get shareDiscard => 'Discard';
}

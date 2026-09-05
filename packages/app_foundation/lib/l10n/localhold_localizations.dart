// SPDX-License-Identifier: MPL-2.0
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'localhold_localizations_en.dart';
import 'localhold_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LocalholdLocalizations
/// returned by `LocalholdLocalizations.of(context)`.
///
/// Applications need to include `LocalholdLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/localhold_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LocalholdLocalizations.localizationsDelegates,
///   supportedLocales: LocalholdLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the LocalholdLocalizations.supportedLocales
/// property.
abstract class LocalholdLocalizations {
  LocalholdLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LocalholdLocalizations of(BuildContext context) {
    return Localizations.of<LocalholdLocalizations>(
      context,
      LocalholdLocalizations,
    )!;
  }

  static const LocalizationsDelegate<LocalholdLocalizations> delegate =
      _LocalholdLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Localhold'**
  String get appTitle;

  /// No description provided for @navVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get navVault;

  /// No description provided for @navSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get navSubscriptions;

  /// No description provided for @navSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get navSecurity;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get actionLock;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionContinueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue offline'**
  String get actionContinueOffline;

  /// No description provided for @valueHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden value'**
  String get valueHidden;

  /// No description provided for @stateEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get stateEmptyTitle;

  /// No description provided for @stateOfflineLocalAvailable.
  ///
  /// In en, this message translates to:
  /// **'Offline — local features are available'**
  String get stateOfflineLocalAvailable;

  /// No description provided for @stateDiskFull.
  ///
  /// In en, this message translates to:
  /// **'Could not save: the device is out of space'**
  String get stateDiskFull;

  /// No description provided for @stateReadOnly.
  ///
  /// In en, this message translates to:
  /// **'The vault is read-only to protect your data'**
  String get stateReadOnly;

  /// No description provided for @stateExpired.
  ///
  /// In en, this message translates to:
  /// **'Free is active. Existing data remains available.'**
  String get stateExpired;

  /// No description provided for @stateLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock your local vault to continue'**
  String get stateLocked;

  /// No description provided for @premiumTrialCta.
  ///
  /// In en, this message translates to:
  /// **'Try Premium for 14 days'**
  String get premiumTrialCta;

  /// No description provided for @premiumContinueFree.
  ///
  /// In en, this message translates to:
  /// **'Continue with Free'**
  String get premiumContinueFree;

  /// No description provided for @onboardingLocalVault.
  ///
  /// In en, this message translates to:
  /// **'Create local vault'**
  String get onboardingLocalVault;

  /// No description provided for @privacyStrictOffline.
  ///
  /// In en, this message translates to:
  /// **'Strict offline mode'**
  String get privacyStrictOffline;

  /// No description provided for @commonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is unavailable in the current build'**
  String get commonUnavailable;

  /// No description provided for @onboardingTrustTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device'**
  String get onboardingTrustTitle;

  /// No description provided for @onboardingTrustBody.
  ///
  /// In en, this message translates to:
  /// **'Localhold cannot see your vault, master password, recovery words, or files.'**
  String get onboardingTrustBody;

  /// No description provided for @onboardingImport.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get onboardingImport;

  /// No description provided for @onboardingAccountSecondary.
  ///
  /// In en, this message translates to:
  /// **'Use an account for Premium'**
  String get onboardingAccountSecondary;

  /// No description provided for @onboardingMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a master password'**
  String get onboardingMasterTitle;

  /// No description provided for @onboardingMasterBody.
  ///
  /// In en, this message translates to:
  /// **'Use at least 15 characters. Localhold cannot recover this password.'**
  String get onboardingMasterBody;

  /// No description provided for @onboardingVaultName.
  ///
  /// In en, this message translates to:
  /// **'Vault name'**
  String get onboardingVaultName;

  /// No description provided for @onboardingMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get onboardingMasterPassword;

  /// No description provided for @onboardingShowNameLocked.
  ///
  /// In en, this message translates to:
  /// **'Show this name while locked'**
  String get onboardingShowNameLocked;

  /// No description provided for @onboardingRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Create recovery words'**
  String get onboardingRecoveryTitle;

  /// No description provided for @onboardingRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Store them somewhere safe. They are the only recovery option if you forget the master password.'**
  String get onboardingRecoveryBody;

  /// No description provided for @onboardingRecoveryStart.
  ///
  /// In en, this message translates to:
  /// **'Show recovery words'**
  String get onboardingRecoveryStart;

  /// No description provided for @onboardingRecoverySkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingRecoverySkip;

  /// No description provided for @onboardingRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Without recovery words, a forgotten master password means losing access to the vault.'**
  String get onboardingRecoveryWarning;

  /// No description provided for @onboardingRecoveryChallenge.
  ///
  /// In en, this message translates to:
  /// **'Enter word {position}'**
  String onboardingRecoveryChallenge(int position);

  /// No description provided for @onboardingRecoveryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm recovery words'**
  String get onboardingRecoveryConfirm;

  /// No description provided for @onboardingBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Use device unlock?'**
  String get onboardingBiometricTitle;

  /// No description provided for @onboardingBiometricBody.
  ///
  /// In en, this message translates to:
  /// **'Biometrics are optional. Your master password remains available.'**
  String get onboardingBiometricBody;

  /// No description provided for @onboardingBiometricEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable biometrics'**
  String get onboardingBiometricEnable;

  /// No description provided for @onboardingBiometricSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardingBiometricSkip;

  /// No description provided for @onboardingCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Your local vault is ready'**
  String get onboardingCompleteTitle;

  /// No description provided for @onboardingAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add first record'**
  String get onboardingAddFirst;

  /// No description provided for @onboardingOpenVault.
  ///
  /// In en, this message translates to:
  /// **'Open vault'**
  String get onboardingOpenVault;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock vault'**
  String get unlockTitle;

  /// No description provided for @unlockPassword.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get unlockPassword;

  /// No description provided for @unlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockAction;

  /// No description provided for @unlockBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get unlockBiometric;

  /// No description provided for @unlockRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recover access'**
  String get unlockRecovery;

  /// No description provided for @unlockChooseVault.
  ///
  /// In en, this message translates to:
  /// **'Choose vault'**
  String get unlockChooseVault;

  /// No description provided for @unlockNeutralVault.
  ///
  /// In en, this message translates to:
  /// **'Vault {ordinal}'**
  String unlockNeutralVault(int ordinal);

  /// No description provided for @unlockCooldown.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get unlockCooldown;

  /// No description provided for @homeSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Security status'**
  String get homeSafetyTitle;

  /// No description provided for @homeSafetyReady.
  ///
  /// In en, this message translates to:
  /// **'Recovery and device unlock are configured'**
  String get homeSafetyReady;

  /// No description provided for @homeSafetyRecoveryMissing.
  ///
  /// In en, this message translates to:
  /// **'Create recovery words to protect access'**
  String get homeSafetyRecoveryMissing;

  /// No description provided for @homeQuickFilters.
  ///
  /// In en, this message translates to:
  /// **'Quick filters'**
  String get homeQuickFilters;

  /// No description provided for @homeTypes.
  ///
  /// In en, this message translates to:
  /// **'Record types'**
  String get homeTypes;

  /// No description provided for @homeRecents.
  ///
  /// In en, this message translates to:
  /// **'Recent records'**
  String get homeRecents;

  /// No description provided for @homeNoRecents.
  ///
  /// In en, this message translates to:
  /// **'Recent records will appear here'**
  String get homeNoRecents;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @accessInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Check the entered information'**
  String get accessInvalidInput;

  /// No description provided for @accessInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The master password is not correct'**
  String get accessInvalidCredentials;

  /// No description provided for @accessIntegrityFailure.
  ///
  /// In en, this message translates to:
  /// **'The vault cannot be opened safely'**
  String get accessIntegrityFailure;

  /// No description provided for @accessUnknownFailure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your existing data was not changed.'**
  String get accessUnknownFailure;

  /// No description provided for @recoveryUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover vault access'**
  String get recoveryUnlockTitle;

  /// No description provided for @recoveryUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery words and choose a new master password.'**
  String get recoveryUnlockBody;

  /// No description provided for @recoveryUnlockPhrase.
  ///
  /// In en, this message translates to:
  /// **'Recovery words'**
  String get recoveryUnlockPhrase;

  /// No description provided for @recoveryUnlockNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New master password'**
  String get recoveryUnlockNewPassword;

  /// No description provided for @recoveryUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Recover and unlock'**
  String get recoveryUnlockAction;

  /// No description provided for @typePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a record type'**
  String get typePickerTitle;

  /// No description provided for @typePickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search record types'**
  String get typePickerSearch;

  /// No description provided for @typePickerRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get typePickerRecent;

  /// No description provided for @typePickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No record types found'**
  String get typePickerNoResults;

  /// No description provided for @typePickerCustom.
  ///
  /// In en, this message translates to:
  /// **'Create your own type'**
  String get typePickerCustom;

  /// No description provided for @premiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumBadge;

  /// No description provided for @templateCategoryAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get templateCategoryAccounts;

  /// No description provided for @templateCategoryMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get templateCategoryMoney;

  /// No description provided for @templateCategoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get templateCategoryPersonal;

  /// No description provided for @templateCategoryTechnical.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get templateCategoryTechnical;

  /// No description provided for @templateAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get templateAccount;

  /// No description provided for @templateSocialProfile.
  ///
  /// In en, this message translates to:
  /// **'Social network'**
  String get templateSocialProfile;

  /// No description provided for @templateEmailAccount.
  ///
  /// In en, this message translates to:
  /// **'Email account'**
  String get templateEmailAccount;

  /// No description provided for @templateGamingAccount.
  ///
  /// In en, this message translates to:
  /// **'Gaming account'**
  String get templateGamingAccount;

  /// No description provided for @templateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get templateSubscription;

  /// No description provided for @templatePaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Bank card'**
  String get templatePaymentCard;

  /// No description provided for @templateBankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get templateBankDetails;

  /// No description provided for @templateIdentity.
  ///
  /// In en, this message translates to:
  /// **'Personal contact'**
  String get templateIdentity;

  /// No description provided for @templateIdentityDocument.
  ///
  /// In en, this message translates to:
  /// **'Passport or document'**
  String get templateIdentityDocument;

  /// No description provided for @templateSecureNote.
  ///
  /// In en, this message translates to:
  /// **'Secure note'**
  String get templateSecureNote;

  /// No description provided for @templateSoftwareLicense.
  ///
  /// In en, this message translates to:
  /// **'Software license'**
  String get templateSoftwareLicense;

  /// No description provided for @templateWirelessNetwork.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi network'**
  String get templateWirelessNetwork;

  /// No description provided for @templateRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get templateRouter;

  /// No description provided for @templateServer.
  ///
  /// In en, this message translates to:
  /// **'Server or hosting'**
  String get templateServer;

  /// No description provided for @templateDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get templateDatabase;

  /// No description provided for @templateApiCredential.
  ///
  /// In en, this message translates to:
  /// **'API key or token'**
  String get templateApiCredential;

  /// No description provided for @templateSshCredential.
  ///
  /// In en, this message translates to:
  /// **'SSH key or certificate'**
  String get templateSshCredential;

  /// No description provided for @templateRecoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get templateRecoveryCodes;

  /// No description provided for @templateCryptoAccount.
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrency account'**
  String get templateCryptoAccount;

  /// No description provided for @editorCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get editorCreateTitle;

  /// No description provided for @editorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editorEditTitle;

  /// No description provided for @editorAdvanced.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get editorAdvanced;

  /// No description provided for @editorDraftSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving draft…'**
  String get editorDraftSaving;

  /// No description provided for @editorDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get editorDraftSaved;

  /// No description provided for @editorDraftFailed.
  ///
  /// In en, this message translates to:
  /// **'Draft was not saved. Try again.'**
  String get editorDraftFailed;

  /// No description provided for @editorDraftConflict.
  ///
  /// In en, this message translates to:
  /// **'A separate draft was kept because this record changed elsewhere.'**
  String get editorDraftConflict;

  /// No description provided for @editorSaveRecord.
  ///
  /// In en, this message translates to:
  /// **'Save record'**
  String get editorSaveRecord;

  /// No description provided for @editorSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get editorSaveDraft;

  /// No description provided for @editorContinueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing'**
  String get editorContinueEditing;

  /// No description provided for @editorDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get editorDeleteDraft;

  /// No description provided for @editorBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your changes?'**
  String get editorBackTitle;

  /// No description provided for @editorBackBody.
  ///
  /// In en, this message translates to:
  /// **'Choose what to do with this encrypted local draft.'**
  String get editorBackBody;

  /// No description provided for @editorDeleteFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this field?'**
  String get editorDeleteFieldTitle;

  /// No description provided for @editorDeleteFieldBody.
  ///
  /// In en, this message translates to:
  /// **'The field has a value. You can undo removal until the record is saved.'**
  String get editorDeleteFieldBody;

  /// No description provided for @editorRemoveField.
  ///
  /// In en, this message translates to:
  /// **'Remove field'**
  String get editorRemoveField;

  /// No description provided for @editorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editorUndo;

  /// No description provided for @editorOneValueRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a value in at least one field.'**
  String get editorOneValueRequired;

  /// No description provided for @editorAddTotp.
  ///
  /// In en, this message translates to:
  /// **'Add one-time password'**
  String get editorAddTotp;

  /// No description provided for @editorAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add file or image'**
  String get editorAddAttachment;

  /// No description provided for @editorAddCustomField.
  ///
  /// In en, this message translates to:
  /// **'Add custom field'**
  String get editorAddCustomField;

  /// No description provided for @editorPremiumRequired.
  ///
  /// In en, this message translates to:
  /// **'Premium is required to add this item.'**
  String get editorPremiumRequired;

  /// No description provided for @recordViewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get recordViewEdit;

  /// No description provided for @recordViewReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get recordViewReveal;

  /// No description provided for @recordViewHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get recordViewHide;

  /// No description provided for @recordViewCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get recordViewCopy;

  /// No description provided for @recordViewDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get recordViewDelete;

  /// No description provided for @recordViewEmpty.
  ///
  /// In en, this message translates to:
  /// **'This record has no visible values.'**
  String get recordViewEmpty;

  /// No description provided for @conversionTitle.
  ///
  /// In en, this message translates to:
  /// **'Change record type'**
  String get conversionTitle;

  /// No description provided for @conversionMapped.
  ///
  /// In en, this message translates to:
  /// **'Mapped'**
  String get conversionMapped;

  /// No description provided for @conversionUnmapped.
  ///
  /// In en, this message translates to:
  /// **'Kept as an extra field'**
  String get conversionUnmapped;

  /// No description provided for @conversionIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible — kept as an extra field'**
  String get conversionIncompatible;

  /// No description provided for @conversionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply conversion'**
  String get conversionApply;

  /// No description provided for @totpImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Add one-time password'**
  String get totpImportTitle;

  /// No description provided for @totpUriOrSecret.
  ///
  /// In en, this message translates to:
  /// **'TOTP link or Base32 secret'**
  String get totpUriOrSecret;

  /// No description provided for @totpIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issuer'**
  String get totpIssuer;

  /// No description provided for @totpAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get totpAccount;

  /// No description provided for @totpReview.
  ///
  /// In en, this message translates to:
  /// **'Review before adding'**
  String get totpReview;

  /// No description provided for @totpInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid TOTP value.'**
  String get totpInvalid;

  /// No description provided for @totpAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to draft'**
  String get totpAdd;

  /// No description provided for @totpScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get totpScanQr;

  /// No description provided for @totpImportQrImage.
  ///
  /// In en, this message translates to:
  /// **'Read QR from image'**
  String get totpImportQrImage;

  /// No description provided for @totpAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get totpAlgorithm;

  /// No description provided for @totpDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get totpDigits;

  /// No description provided for @totpPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get totpPeriod;

  /// No description provided for @actionReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get actionReview;

  /// No description provided for @attachmentFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get attachmentFile;

  /// No description provided for @attachmentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get attachmentPhoto;

  /// No description provided for @attachmentCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get attachmentCamera;

  /// No description provided for @attachmentPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission was denied. You can enable it in system settings.'**
  String get attachmentPermissionDenied;

  /// No description provided for @attachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This source is unavailable on this device.'**
  String get attachmentUnavailable;

  /// No description provided for @attachmentImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The file was not added. No partial attachment was kept.'**
  String get attachmentImportFailed;

  /// No description provided for @attachmentImporting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting on this device…'**
  String get attachmentImporting;

  /// No description provided for @attachmentCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel import'**
  String get attachmentCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @warningDoNotStoreCardPin.
  ///
  /// In en, this message translates to:
  /// **'Avoid storing a card PIN unless you truly need it. Never share it.'**
  String get warningDoNotStoreCardPin;

  /// No description provided for @warningLocalholdNotWallet.
  ///
  /// In en, this message translates to:
  /// **'Localhold is not a cryptocurrency wallet. Storing recovery material here carries extra risk.'**
  String get warningLocalholdNotWallet;

  /// No description provided for @vaultAllRecords.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get vaultAllRecords;

  /// No description provided for @vaultSearch.
  ///
  /// In en, this message translates to:
  /// **'Search records'**
  String get vaultSearch;

  /// No description provided for @vaultSearchProtected.
  ///
  /// In en, this message translates to:
  /// **'Search protected fields'**
  String get vaultSearchProtected;

  /// No description provided for @vaultSearchProtectedActive.
  ///
  /// In en, this message translates to:
  /// **'Protected search is on'**
  String get vaultSearchProtectedActive;

  /// No description provided for @vaultSearchProtectedHint.
  ///
  /// In en, this message translates to:
  /// **'After verification, this search can match passwords, tokens and other protected fields. Results stay masked.'**
  String get vaultSearchProtectedHint;

  /// No description provided for @vaultSearchAuthorizationDenied.
  ///
  /// In en, this message translates to:
  /// **'Verification was not completed. Protected search stayed off.'**
  String get vaultSearchAuthorizationDenied;

  /// No description provided for @vaultNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records match this view.'**
  String get vaultNoRecords;

  /// No description provided for @vaultLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Records could not be loaded. Your stored data was not changed.'**
  String get vaultLoadFailed;

  /// No description provided for @vaultTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get vaultTryAgain;

  /// No description provided for @vaultLayoutCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact list'**
  String get vaultLayoutCompact;

  /// No description provided for @vaultLayoutComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable list'**
  String get vaultLayoutComfortable;

  /// No description provided for @vaultLayoutGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get vaultLayoutGrid;

  /// No description provided for @vaultSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get vaultSortNewest;

  /// No description provided for @vaultSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Least recently updated'**
  String get vaultSortOldest;

  /// No description provided for @vaultSortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title A–Z'**
  String get vaultSortTitleAsc;

  /// No description provided for @vaultSortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title Z–A'**
  String get vaultSortTitleDesc;

  /// No description provided for @vaultFilterAll.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vaultFilterAll;

  /// No description provided for @vaultFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get vaultFilterFavorites;

  /// No description provided for @vaultFilterPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get vaultFilterPinned;

  /// No description provided for @vaultFilterArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vaultFilterArchive;

  /// No description provided for @vaultFilterTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get vaultFilterTrash;

  /// No description provided for @vaultFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get vaultFavorite;

  /// No description provided for @vaultPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get vaultPinned;

  /// No description provided for @vaultFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get vaultFolder;

  /// No description provided for @vaultAnyFolder.
  ///
  /// In en, this message translates to:
  /// **'Any folder'**
  String get vaultAnyFolder;

  /// No description provided for @vaultTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get vaultTags;

  /// No description provided for @vaultSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String vaultSelected(int count);

  /// No description provided for @vaultBulkMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get vaultBulkMove;

  /// No description provided for @vaultBulkTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get vaultBulkTags;

  /// No description provided for @vaultBulkFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get vaultBulkFavorite;

  /// No description provided for @vaultBulkArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vaultBulkArchive;

  /// No description provided for @vaultBulkTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get vaultBulkTrash;

  /// No description provided for @vaultBulkExport.
  ///
  /// In en, this message translates to:
  /// **'Export selected'**
  String get vaultBulkExport;

  /// No description provided for @vaultRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get vaultRestore;

  /// No description provided for @vaultTrashRetention.
  ///
  /// In en, this message translates to:
  /// **'Items stay in Trash for 30 days before they become eligible for permanent deletion.'**
  String get vaultTrashRetention;

  /// No description provided for @vaultStorageActionFailed.
  ///
  /// In en, this message translates to:
  /// **'The change was not saved. Existing records stayed safe.'**
  String get vaultStorageActionFailed;

  /// No description provided for @vaultExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export did not start. Records were not changed.'**
  String get vaultExportFailed;

  /// No description provided for @organizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Folders and tags'**
  String get organizationTitle;

  /// No description provided for @organizationFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get organizationFolders;

  /// No description provided for @organizationTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get organizationTags;

  /// No description provided for @organizationAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get organizationAddFolder;

  /// No description provided for @organizationAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get organizationAddTag;

  /// No description provided for @organizationName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get organizationName;

  /// No description provided for @organizationRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get organizationRename;

  /// No description provided for @organizationMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get organizationMove;

  /// No description provided for @organizationMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge into another tag'**
  String get organizationMerge;

  /// No description provided for @organizationDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get organizationDelete;

  /// No description provided for @organizationDeleteFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Subfolders and records move to the parent folder. No record is deleted.'**
  String get organizationDeleteFolderHint;

  /// No description provided for @organizationDeleteTagHint.
  ///
  /// In en, this message translates to:
  /// **'The tag is removed from records. No record is deleted.'**
  String get organizationDeleteTagHint;

  /// No description provided for @organizationEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no folders or tags yet.'**
  String get organizationEmpty;

  /// No description provided for @organizationSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The change was not saved. The previous organization is still available.'**
  String get organizationSaveFailed;

  /// No description provided for @duplicatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicates'**
  String get duplicatesTitle;

  /// No description provided for @duplicatesScan.
  ///
  /// In en, this message translates to:
  /// **'Scan records'**
  String get duplicatesScan;

  /// No description provided for @duplicatesProtectedScan.
  ///
  /// In en, this message translates to:
  /// **'Compare protected values'**
  String get duplicatesProtectedScan;

  /// No description provided for @duplicatesProtectedBadge.
  ///
  /// In en, this message translates to:
  /// **'Protected comparison is on'**
  String get duplicatesProtectedBadge;

  /// No description provided for @duplicatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No possible duplicates found.'**
  String get duplicatesEmpty;

  /// No description provided for @duplicatesIntro.
  ///
  /// In en, this message translates to:
  /// **'Localhold compares records only on this device. A match is a suggestion, not proof.'**
  String get duplicatesIntro;

  /// No description provided for @duplicatesPossible.
  ///
  /// In en, this message translates to:
  /// **'Possible match'**
  String get duplicatesPossible;

  /// No description provided for @duplicatesLikely.
  ///
  /// In en, this message translates to:
  /// **'Likely match'**
  String get duplicatesLikely;

  /// No description provided for @duplicatesConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict copy'**
  String get duplicatesConflict;

  /// No description provided for @duplicatesConflictHint.
  ///
  /// In en, this message translates to:
  /// **'Both versions are kept. Compare them and choose the values you want; neither version is selected automatically.'**
  String get duplicatesConflictHint;

  /// No description provided for @duplicatesReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'same title'**
  String get duplicatesReasonTitle;

  /// No description provided for @duplicatesReasonDomain.
  ///
  /// In en, this message translates to:
  /// **'same website domain'**
  String get duplicatesReasonDomain;

  /// No description provided for @duplicatesReasonUsername.
  ///
  /// In en, this message translates to:
  /// **'same username'**
  String get duplicatesReasonUsername;

  /// No description provided for @duplicatesReasonEmail.
  ///
  /// In en, this message translates to:
  /// **'same email'**
  String get duplicatesReasonEmail;

  /// No description provided for @duplicatesReasonIdentifier.
  ///
  /// In en, this message translates to:
  /// **'same identifier'**
  String get duplicatesReasonIdentifier;

  /// No description provided for @duplicatesReasonProtected.
  ///
  /// In en, this message translates to:
  /// **'an exact protected value matches'**
  String get duplicatesReasonProtected;

  /// No description provided for @duplicatesReasonConflict.
  ///
  /// In en, this message translates to:
  /// **'saved as a conflict copy'**
  String get duplicatesReasonConflict;

  /// No description provided for @duplicatesUseFirst.
  ///
  /// In en, this message translates to:
  /// **'Use first as base'**
  String get duplicatesUseFirst;

  /// No description provided for @duplicatesUseSecond.
  ///
  /// In en, this message translates to:
  /// **'Use second as base'**
  String get duplicatesUseSecond;

  /// No description provided for @mergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare and merge'**
  String get mergeTitle;

  /// No description provided for @mergeTarget.
  ///
  /// In en, this message translates to:
  /// **'Keep record'**
  String get mergeTarget;

  /// No description provided for @mergeSource.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get mergeSource;

  /// No description provided for @mergeChooseEach.
  ///
  /// In en, this message translates to:
  /// **'Choose which value to keep for every field. Protected values stay masked.'**
  String get mergeChooseEach;

  /// No description provided for @mergeFromTarget.
  ///
  /// In en, this message translates to:
  /// **'From kept record'**
  String get mergeFromTarget;

  /// No description provided for @mergeFromSource.
  ///
  /// In en, this message translates to:
  /// **'From other record'**
  String get mergeFromSource;

  /// No description provided for @mergeResult.
  ///
  /// In en, this message translates to:
  /// **'The selected values will be saved in {target}. {source} will move to Trash and can still be restored.'**
  String mergeResult(String target, String source);

  /// No description provided for @mergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeAction;

  /// No description provided for @mergeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge these records?'**
  String get mergeConfirmTitle;

  /// No description provided for @mergeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This updates the kept record and moves the other record to Trash in one local operation.'**
  String get mergeConfirmBody;

  /// No description provided for @mergeCancel.
  ///
  /// In en, this message translates to:
  /// **'Back to candidates'**
  String get mergeCancel;

  /// No description provided for @mergeFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed. Both previous records are still available.'**
  String get mergeFailed;

  /// No description provided for @duplicatesAuthorizationDenied.
  ///
  /// In en, this message translates to:
  /// **'Protected comparison was not enabled.'**
  String get duplicatesAuthorizationDenied;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderTitle;

  /// No description provided for @reminderWhen.
  ///
  /// In en, this message translates to:
  /// **'When to remind'**
  String get reminderWhen;

  /// No description provided for @reminderDayOf.
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get reminderDayOf;

  /// No description provided for @reminderOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get reminderOneDay;

  /// No description provided for @reminderThreeDays.
  ///
  /// In en, this message translates to:
  /// **'3 days before'**
  String get reminderThreeDays;

  /// No description provided for @reminderSevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 days before'**
  String get reminderSevenDays;

  /// No description provided for @reminderCustomOffset.
  ///
  /// In en, this message translates to:
  /// **'Custom time before'**
  String get reminderCustomOffset;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'Days before'**
  String get reminderDaysBefore;

  /// No description provided for @reminderCustomRange.
  ///
  /// In en, this message translates to:
  /// **'From 0 to 365 days'**
  String get reminderCustomRange;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @reminderQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get reminderQuietHours;

  /// No description provided for @reminderQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get reminderQuietStart;

  /// No description provided for @reminderQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get reminderQuietEnd;

  /// No description provided for @reminderPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Notification privacy'**
  String get reminderPrivacy;

  /// No description provided for @reminderPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Secrets and protected values are never shown in a notification.'**
  String get reminderPrivacyHint;

  /// No description provided for @reminderPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get reminderPrivate;

  /// No description provided for @reminderPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Shows only a generic Localhold reminder.'**
  String get reminderPrivateHint;

  /// No description provided for @reminderName.
  ///
  /// In en, this message translates to:
  /// **'Show record name'**
  String get reminderName;

  /// No description provided for @reminderNameAmount.
  ///
  /// In en, this message translates to:
  /// **'Show record name and safe amount'**
  String get reminderNameAmount;

  /// No description provided for @reminderEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable reminder'**
  String get reminderEnable;

  /// No description provided for @reminderPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get reminderPermissionTitle;

  /// No description provided for @reminderPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Localhold needs system permission to show this reminder. The default notification is generic and contains no record data. You can change this later.'**
  String get reminderPermissionBody;

  /// No description provided for @reminderContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to system permission'**
  String get reminderContinue;

  /// No description provided for @reminderWorking.
  ///
  /// In en, this message translates to:
  /// **'Saving and scheduling this reminder…'**
  String get reminderWorking;

  /// No description provided for @reminderScheduled.
  ///
  /// In en, this message translates to:
  /// **'Reminder scheduled on this device.'**
  String get reminderScheduled;

  /// No description provided for @reminderPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'The reminder is saved but disabled because notification permission was denied.'**
  String get reminderPermissionDenied;

  /// No description provided for @reminderPermissionRestricted.
  ///
  /// In en, this message translates to:
  /// **'The reminder is saved but disabled because notifications are restricted on this device.'**
  String get reminderPermissionRestricted;

  /// No description provided for @reminderPast.
  ///
  /// In en, this message translates to:
  /// **'This time has already passed. Choose a future time.'**
  String get reminderPast;

  /// No description provided for @reminderFailed.
  ///
  /// In en, this message translates to:
  /// **'The reminder was not scheduled. Your record was not changed.'**
  String get reminderFailed;

  /// No description provided for @reminderOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get reminderOpenSettings;

  /// No description provided for @shareInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared with Localhold'**
  String get shareInboxTitle;

  /// No description provided for @shareInboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting to be imported.'**
  String get shareInboxEmpty;

  /// No description provided for @shareImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The item was not imported. No partial draft was kept.'**
  String get shareImportFailed;

  /// No description provided for @shareKindText.
  ///
  /// In en, this message translates to:
  /// **'Shared text'**
  String get shareKindText;

  /// No description provided for @shareKindUrl.
  ///
  /// In en, this message translates to:
  /// **'Shared link'**
  String get shareKindUrl;

  /// No description provided for @shareKindFile.
  ///
  /// In en, this message translates to:
  /// **'Shared file'**
  String get shareKindFile;

  /// No description provided for @shareKindImage.
  ///
  /// In en, this message translates to:
  /// **'Shared image'**
  String get shareKindImage;

  /// No description provided for @shareBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String shareBytes(int count);

  /// No description provided for @shareProtectedHint.
  ///
  /// In en, this message translates to:
  /// **'The content stays in protected device storage and becomes an encrypted draft only after import.'**
  String get shareProtectedHint;

  /// No description provided for @shareImport.
  ///
  /// In en, this message translates to:
  /// **'Import as encrypted draft'**
  String get shareImport;

  /// No description provided for @shareDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get shareDiscard;
}

class _LocalholdLocalizationsDelegate
    extends LocalizationsDelegate<LocalholdLocalizations> {
  const _LocalholdLocalizationsDelegate();

  @override
  Future<LocalholdLocalizations> load(Locale locale) {
    return SynchronousFuture<LocalholdLocalizations>(
      lookupLocalholdLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_LocalholdLocalizationsDelegate old) => false;
}

LocalholdLocalizations lookupLocalholdLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LocalholdLocalizationsEn();
    case 'ru':
      return LocalholdLocalizationsRu();
  }

  throw FlutterError(
    'LocalholdLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

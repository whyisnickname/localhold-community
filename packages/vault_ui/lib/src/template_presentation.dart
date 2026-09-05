// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';
import 'package:localhold_vault_core/localhold_vault_core.dart';

String localizedTemplateName(LocalholdLocalizations strings, String stableId) =>
    switch (stableId) {
      BuiltInRecordTypes.account => strings.templateAccount,
      BuiltInRecordTypes.socialProfile => strings.templateSocialProfile,
      BuiltInRecordTypes.emailAccount => strings.templateEmailAccount,
      BuiltInRecordTypes.gamingAccount => strings.templateGamingAccount,
      BuiltInRecordTypes.subscription => strings.templateSubscription,
      BuiltInRecordTypes.paymentCard => strings.templatePaymentCard,
      BuiltInRecordTypes.bankDetails => strings.templateBankDetails,
      BuiltInRecordTypes.identity => strings.templateIdentity,
      BuiltInRecordTypes.identityDocument => strings.templateIdentityDocument,
      BuiltInRecordTypes.secureNote => strings.templateSecureNote,
      BuiltInRecordTypes.softwareLicense => strings.templateSoftwareLicense,
      BuiltInRecordTypes.wirelessNetwork => strings.templateWirelessNetwork,
      BuiltInRecordTypes.router => strings.templateRouter,
      BuiltInRecordTypes.server => strings.templateServer,
      BuiltInRecordTypes.database => strings.templateDatabase,
      BuiltInRecordTypes.apiCredential => strings.templateApiCredential,
      BuiltInRecordTypes.sshCredential => strings.templateSshCredential,
      BuiltInRecordTypes.recoveryCodes => strings.templateRecoveryCodes,
      BuiltInRecordTypes.cryptoAccount => strings.templateCryptoAccount,
      _ => stableId,
    };

String localizedTemplateCategory(
  LocalholdLocalizations strings,
  TemplateCategory category,
) => switch (category) {
  TemplateCategory.accounts => strings.templateCategoryAccounts,
  TemplateCategory.money => strings.templateCategoryMoney,
  TemplateCategory.personal => strings.templateCategoryPersonal,
  TemplateCategory.technical => strings.templateCategoryTechnical,
  TemplateCategory.custom => strings.typePickerCustom,
};

IconData templateIconData(TemplateIcon icon) => switch (icon) {
  TemplateIcon.account => Icons.person_outline,
  TemplateIcon.social => Icons.alternate_email,
  TemplateIcon.email => Icons.mail_outline,
  TemplateIcon.gaming => Icons.sports_esports_outlined,
  TemplateIcon.subscription => Icons.autorenew,
  TemplateIcon.paymentCard => Icons.credit_card_outlined,
  TemplateIcon.bank => Icons.account_balance_outlined,
  TemplateIcon.identity => Icons.contact_page_outlined,
  TemplateIcon.document => Icons.badge_outlined,
  TemplateIcon.secureNote => Icons.description_outlined,
  TemplateIcon.software => Icons.key_outlined,
  TemplateIcon.wifi => Icons.wifi,
  TemplateIcon.router => Icons.router_outlined,
  TemplateIcon.server => Icons.dns_outlined,
  TemplateIcon.database => Icons.storage_outlined,
  TemplateIcon.api => Icons.api_outlined,
  TemplateIcon.ssh => Icons.terminal_outlined,
  TemplateIcon.recovery => Icons.password_outlined,
  TemplateIcon.crypto => Icons.currency_bitcoin,
  TemplateIcon.custom => Icons.tune,
};

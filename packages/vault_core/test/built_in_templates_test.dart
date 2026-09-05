// SPDX-License-Identifier: MPL-2.0

import 'package:localhold_vault_core/localhold_vault_core.dart';
import 'package:test/test.dart';

void main() {
  group('built-in template catalog', () {
    test('contains the approved 19 templates in stable order', () {
      expect(BuiltInTemplateCatalog.all.map((template) => template.stableId), [
        BuiltInRecordTypes.account,
        BuiltInRecordTypes.socialProfile,
        BuiltInRecordTypes.emailAccount,
        BuiltInRecordTypes.gamingAccount,
        BuiltInRecordTypes.subscription,
        BuiltInRecordTypes.paymentCard,
        BuiltInRecordTypes.bankDetails,
        BuiltInRecordTypes.identity,
        BuiltInRecordTypes.identityDocument,
        BuiltInRecordTypes.secureNote,
        BuiltInRecordTypes.softwareLicense,
        BuiltInRecordTypes.wirelessNetwork,
        BuiltInRecordTypes.router,
        BuiltInRecordTypes.server,
        BuiltInRecordTypes.database,
        BuiltInRecordTypes.apiCredential,
        BuiltInRecordTypes.sshCredential,
        BuiltInRecordTypes.recoveryCodes,
        BuiltInRecordTypes.cryptoAccount,
      ]);
    });

    test('uses the approved category order and membership', () {
      final categories = BuiltInTemplateCatalog.all
          .map((template) => template.category)
          .toList();
      expect(
        categories,
        orderedEquals([
          ...List.filled(4, TemplateCategory.accounts),
          ...List.filled(3, TemplateCategory.money),
          ...List.filled(3, TemplateCategory.personal),
          ...List.filled(9, TemplateCategory.technical),
        ]),
      );
      expect(
        BuiltInTemplateCatalog.inCategory(TemplateCategory.accounts),
        hasLength(4),
      );
      expect(
        BuiltInTemplateCatalog.inCategory(TemplateCategory.money),
        hasLength(3),
      );
      expect(
        BuiltInTemplateCatalog.inCategory(TemplateCategory.personal),
        hasLength(3),
      );
      expect(
        BuiltInTemplateCatalog.inCategory(TemplateCategory.technical),
        hasLength(9),
      );
      expect(
        BuiltInTemplateCatalog.inCategory(TemplateCategory.custom),
        isEmpty,
      );
    });

    test('has unique stable IDs and a neutral bundled icon', () {
      final templates = BuiltInTemplateCatalog.all;
      expect(
        templates.map((template) => template.stableId).toSet(),
        hasLength(templates.length),
      );
      for (final template in templates) {
        expect(template.builtIn, isTrue);
        expect(template.icon, isNot(TemplateIcon.custom));
        expect(
          template.fields.map((field) => field.stableId).toSet(),
          hasLength(template.fields.length),
        );
      }
    });

    test('starts every template with an optional safe title candidate', () {
      for (final template in BuiltInTemplateCatalog.all) {
        final title = template.fields.first;
        expect(title.stableId, 'title');
        expect(title.kind, VaultFieldKind.text);
        expect(title.protected, isFalse);
        expect(title.displayCandidate, isTrue);
        expect(title.searchScope, FieldSearchScope.standard);
      }
    });

    test('never exposes protected data as a display candidate', () {
      for (final template in BuiltInTemplateCatalog.all) {
        for (final field in template.fields) {
          if (field.protected) {
            expect(field.displayCandidate, isFalse);
            expect(field.searchScope, isNot(FieldSearchScope.standard));
          } else {
            expect(field.searchScope, isNot(FieldSearchScope.protected));
          }
          if (field.kind == VaultFieldKind.secret) {
            expect(field.protected, isTrue);
            expect(field.displayCandidate, isFalse);
          }
        }
      }
    });

    test('does not ask users to store card verification codes', () {
      final fieldIds = BuiltInTemplateCatalog.all
          .expand((template) => template.fields)
          .map((field) => field.stableId.toLowerCase())
          .toSet();
      expect(fieldIds, isNot(contains('cvv')));
      expect(fieldIds, isNot(contains('cvc')));
      expect(fieldIds, isNot(contains('security_code')));
    });

    test('warns before unusually sensitive optional fields', () {
      final card = _template(BuiltInRecordTypes.paymentCard);
      expect(_field(card, 'pin').warningCode, 'do_not_store_card_pin');

      final crypto = _template(BuiltInRecordTypes.cryptoAccount);
      expect(
        _field(crypto, 'seed_phrase').warningCode,
        'localhold_is_not_a_wallet',
      );
      expect(
        _field(crypto, 'private_key').warningCode,
        'localhold_is_not_a_wallet',
      );
    });

    test('keeps key approved fields in representative templates', () {
      expect(
        _template(BuiltInRecordTypes.subscription).fields
            .map((field) => field.stableId),
        containsAll([
          'amount',
          'currency',
          'cadence',
          'next_payment',
          'auto_renew',
          'trial_end',
        ]),
      );
      expect(
        _template(BuiltInRecordTypes.emailAccount).fields
            .map((field) => field.stableId),
        containsAll([
          'email',
          'password',
          'app_password',
          'incoming_server',
          'outgoing_server',
        ]),
      );
      expect(
        _template(BuiltInRecordTypes.sshCredential).fields
            .map((field) => field.stableId),
        containsAll([
          'public_material',
          'fingerprint',
          'private_key',
          'passphrase',
        ]),
      );
    });
  });
}

RecordTypeDefinition _template(String stableId) => BuiltInTemplateCatalog.all
    .singleWhere((template) => template.stableId == stableId);

FieldDefinition _field(RecordTypeDefinition template, String stableId) =>
    template.fields.singleWhere((field) => field.stableId == stableId);

// SPDX-License-Identifier: MPL-2.0

import 'models.dart';

abstract final class BuiltInTemplateCatalog {
  static final List<RecordTypeDefinition> all = List.unmodifiable([
    _type(BuiltInRecordTypes.account, 'Account', [
      _field('title', VaultFieldKind.text, 'Title'),
      _field('username', VaultFieldKind.username, 'Username'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
      _field('website', VaultFieldKind.url, 'Website'),
      _field('notes', VaultFieldKind.note, 'Notes'),
    ]),
    _type(BuiltInRecordTypes.socialProfile, 'Social profile', [
      _field('network', VaultFieldKind.text, 'Network'),
      _field('profile', VaultFieldKind.url, 'Profile'),
      _field('username', VaultFieldKind.username, 'Username'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
    ]),
    _type(BuiltInRecordTypes.emailAccount, 'Email', [
      _field('email', VaultFieldKind.email, 'Email'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
      _field('recovery_email', VaultFieldKind.email, 'Recovery email'),
    ]),
    _type(BuiltInRecordTypes.subscription, 'Subscription', [
      _field('service', VaultFieldKind.text, 'Service'),
      _field('price', VaultFieldKind.money, 'Price'),
      _field('currency', VaultFieldKind.currency, 'Currency'),
      _field('first_payment', VaultFieldKind.date, 'First payment'),
      _field('billing_period', VaultFieldKind.period, 'Billing period'),
    ]),
    _type(BuiltInRecordTypes.secureNote, 'Secure note', [
      _field('title', VaultFieldKind.text, 'Title'),
      _field('note', VaultFieldKind.note, 'Note', protected: true),
    ]),
    _type(BuiltInRecordTypes.paymentCard, 'Payment card', [
      _field('holder', VaultFieldKind.text, 'Cardholder'),
      _field('number', VaultFieldKind.secret, 'Card number', protected: true),
      _field('expiry', VaultFieldKind.date, 'Expiry'),
      _field(
        'security_code',
        VaultFieldKind.secret,
        'Security code',
        protected: true,
      ),
    ]),
    _type(BuiltInRecordTypes.bankDetails, 'Bank details', [
      _field('bank', VaultFieldKind.text, 'Bank'),
      _field('account', VaultFieldKind.secret, 'Account', protected: true),
      _field('details', VaultFieldKind.note, 'Details'),
    ]),
    _type(BuiltInRecordTypes.identity, 'Identity', [
      _field('name', VaultFieldKind.text, 'Name'),
      _field('phone', VaultFieldKind.phone, 'Phone'),
      _field('email', VaultFieldKind.email, 'Email'),
      _field('address', VaultFieldKind.address, 'Address'),
    ]),
    _type(BuiltInRecordTypes.identityDocument, 'Document', [
      _field('document_type', VaultFieldKind.text, 'Document type'),
      _field('number', VaultFieldKind.secret, 'Number', protected: true),
      _field('issued', VaultFieldKind.date, 'Issued'),
      _field('expires', VaultFieldKind.date, 'Expires'),
    ]),
    _type(BuiltInRecordTypes.softwareLicense, 'Software license', [
      _field('product', VaultFieldKind.text, 'Product'),
      _field(
        'license_key',
        VaultFieldKind.secret,
        'License key',
        protected: true,
      ),
      _field('expires', VaultFieldKind.date, 'Expires'),
    ]),
    _type(BuiltInRecordTypes.wirelessNetwork, 'Wi-Fi', [
      _field('ssid', VaultFieldKind.text, 'Network name'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
    ]),
    _type(BuiltInRecordTypes.router, 'Router', [
      _field('address', VaultFieldKind.url, 'Address'),
      _field('username', VaultFieldKind.username, 'Username'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
    ]),
    _type(BuiltInRecordTypes.server, 'Server', _technicalFields()),
    _type(BuiltInRecordTypes.database, 'Database', _technicalFields()),
    _type(BuiltInRecordTypes.apiCredential, 'API credential', [
      _field('service', VaultFieldKind.text, 'Service'),
      _field('token', VaultFieldKind.secret, 'Token', protected: true),
      _field('expires', VaultFieldKind.date, 'Expires'),
    ]),
    _type(BuiltInRecordTypes.sshCredential, 'SSH credential', [
      _field('host', VaultFieldKind.text, 'Host'),
      _field('username', VaultFieldKind.username, 'Username'),
      _field(
        'private_key',
        VaultFieldKind.secret,
        'Private key',
        protected: true,
      ),
    ]),
    _type(BuiltInRecordTypes.gamingAccount, 'Gaming account', [
      _field('service', VaultFieldKind.text, 'Service'),
      _field('username', VaultFieldKind.username, 'Username'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
    ]),
    _type(BuiltInRecordTypes.cryptoAccount, 'Crypto account', [
      _field('service', VaultFieldKind.text, 'Service'),
      _field('login', VaultFieldKind.username, 'Login'),
      _field('password', VaultFieldKind.secret, 'Password', protected: true),
      _field('warning', VaultFieldKind.note, 'Localhold is not a wallet'),
    ]),
    _type(BuiltInRecordTypes.recoveryCodes, 'Recovery codes', [
      _field('service', VaultFieldKind.text, 'Service'),
      _field('codes', VaultFieldKind.secret, 'Recovery codes', protected: true),
    ]),
  ]);

  static RecordTypeDefinition? byStableId(String stableId) {
    for (final definition in all) {
      if (definition.stableId == stableId) return definition;
    }
    return null;
  }

  static RecordTypeDefinition _type(
    String id,
    String name,
    List<FieldDefinition> fields,
  ) => RecordTypeDefinition(stableId: id, defaultName: name, fields: fields);

  static FieldDefinition _field(
    String id,
    VaultFieldKind kind,
    String label, {
    bool protected = false,
  }) => FieldDefinition(
    stableId: id,
    kind: kind,
    defaultLabel: label,
    protected: protected,
  );

  static List<FieldDefinition> _technicalFields() => [
    _field('host', VaultFieldKind.text, 'Host'),
    _field('port', VaultFieldKind.number, 'Port'),
    _field('username', VaultFieldKind.username, 'Username'),
    _field('password', VaultFieldKind.secret, 'Password', protected: true),
    _field('notes', VaultFieldKind.note, 'Notes'),
  ];
}

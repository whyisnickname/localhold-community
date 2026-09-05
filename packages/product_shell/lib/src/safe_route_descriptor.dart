// SPDX-License-Identifier: MPL-2.0
import 'dart:convert';

import 'app_destination.dart';

enum LocalholdSafeLeaf {
  vaultHome(LocalholdDestination.vault),
  allRecords(LocalholdDestination.vault),
  archive(LocalholdDestination.vault),
  trash(LocalholdDestination.vault),
  subscriptionOverview(LocalholdDestination.subscriptions),
  securityOverview(LocalholdDestination.security),
  settingsOverview(LocalholdDestination.settings);

  const LocalholdSafeLeaf(this.destination);

  final LocalholdDestination destination;
}

final class LocalholdSafeRouteDescriptor {
  const LocalholdSafeRouteDescriptor({required this.leaf});

  const LocalholdSafeRouteDescriptor.home()
    : leaf = LocalholdSafeLeaf.vaultHome;

  final LocalholdSafeLeaf leaf;
  LocalholdDestination get destination => leaf.destination;
}

abstract final class LocalholdSafeRouteCodec {
  static const int schemaVersion = 1;

  static String encode(LocalholdSafeRouteDescriptor descriptor) =>
      jsonEncode(<String, Object>{
        'version': schemaVersion,
        'destination': descriptor.destination.name,
        'leaf': descriptor.leaf.name,
      });

  static LocalholdSafeRouteDescriptor decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return const LocalholdSafeRouteDescriptor.home();
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != schemaVersion) {
        return const LocalholdSafeRouteDescriptor.home();
      }
      final destination = LocalholdDestination.values.byName(
        decoded['destination'] as String,
      );
      final leaf = LocalholdSafeLeaf.values.byName(decoded['leaf'] as String);
      if (leaf.destination != destination) {
        return const LocalholdSafeRouteDescriptor.home();
      }
      return LocalholdSafeRouteDescriptor(leaf: leaf);
    } on Object {
      return const LocalholdSafeRouteDescriptor.home();
    }
  }
}

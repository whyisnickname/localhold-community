// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  test(
    'community identity needs no published source URL during development',
    () {
      const identity = BuildIdentity.community();
      expect(identity.isCommercialComposition, isFalse);
      expect(identity.hasImmutableCommercialSourceIdentity, isTrue);
    },
  );
}

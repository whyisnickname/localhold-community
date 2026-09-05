// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/widgets.dart';

abstract final class LocalholdMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);

  static Duration effective(BuildContext context, Duration requested) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : requested;
}

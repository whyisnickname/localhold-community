// SPDX-License-Identifier: MPL-2.0

abstract interface class BackupExclusionGateway {
  Future<void> excludeAbsolutePath(String absolutePath);
}

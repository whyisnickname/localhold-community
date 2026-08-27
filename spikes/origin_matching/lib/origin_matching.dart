// SPDX-License-Identifier: MPL-2.0
library;

sealed class CredentialOrigin {
  const CredentialOrigin();
}

final class AppOrigin extends CredentialOrigin {
  const AppOrigin({required this.applicationId, required this.signerId});
  final String applicationId;
  final String signerId;
}

final class WebOrigin extends CredentialOrigin {
  const WebOrigin({required this.host, this.port = 443});
  final String host;
  final int port;
}

bool exactOriginMatch(CredentialOrigin saved, CredentialOrigin requested) {
  if (saved case AppOrigin(:final applicationId, :final signerId)) {
    return requested is AppOrigin &&
        requested.applicationId == applicationId &&
        requested.signerId.toLowerCase() == signerId.toLowerCase();
  }
  if (saved case WebOrigin(:final host, :final port)) {
    return requested is WebOrigin &&
        _canonicalHost(requested.host) == _canonicalHost(host) &&
        requested.port == port;
  }
  return false;
}

String _canonicalHost(String value) {
  final host = value.trim().toLowerCase();
  if (host.isEmpty || host.startsWith('.') || host.endsWith('.') || host.contains('..')) {
    throw FormatException('Invalid host');
  }
  if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
    throw FormatException('Host must already be ASCII/IDNA normalized');
  }
  return host;
}

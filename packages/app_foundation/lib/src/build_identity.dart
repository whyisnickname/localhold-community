// SPDX-License-Identifier: MPL-2.0

/// Compile-time identity included in About and release notices.
final class BuildIdentity {
  const BuildIdentity._({
    required this.communityRevision,
    required this.communitySourceUrl,
    required this.isCommercialComposition,
  });

  const BuildIdentity.community()
    : this._(
        communityRevision: const String.fromEnvironment(
          'LOCALHOLD_COMMUNITY_REVISION',
          defaultValue: 'development',
        ),
        communitySourceUrl: const String.fromEnvironment(
          'LOCALHOLD_COMMUNITY_SOURCE_URL',
          defaultValue: 'https://github.com/whyisnickname/localhold-community',
        ),
        isCommercialComposition: false,
      );

  const BuildIdentity.commercial()
    : this._(
        communityRevision: const String.fromEnvironment(
          'LOCALHOLD_COMMUNITY_REVISION',
        ),
        communitySourceUrl: const String.fromEnvironment(
          'LOCALHOLD_COMMUNITY_SOURCE_URL',
        ),
        isCommercialComposition: true,
      );

  final String communityRevision;
  final String communitySourceUrl;
  final bool isCommercialComposition;

  String get communityRevisionLabel =>
      communityRevision.isEmpty ? 'missing revision' : communityRevision;

  bool get hasImmutableCommercialSourceIdentity =>
      !isCommercialComposition ||
      (RegExp(r'^[0-9a-f]{40}$').hasMatch(communityRevision) &&
          Uri.tryParse(communitySourceUrl)?.isScheme('https') == true);
}

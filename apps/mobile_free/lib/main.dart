// SPDX-License-Identifier: MPL-2.0
import 'package:flutter/material.dart';
import 'package:localhold_app_foundation/localhold_app_foundation.dart';

void main() {
  const identity = BuildIdentity.community();
  runApp(const LocalholdFreeApp(identity: identity));
}

class LocalholdFreeApp extends StatelessWidget {
  const LocalholdFreeApp({required this.identity, super.key});

  final BuildIdentity identity;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Localhold',
    debugShowCheckedModeBanner: false,
    theme: LocalholdTheme.light(),
    darkTheme: LocalholdTheme.dark(),
    themeMode: ThemeMode.system,
    home: _FoundationScreen(identity: identity),
  );
}

class _FoundationScreen extends StatelessWidget {
  const _FoundationScreen({required this.identity});

  final BuildIdentity identity;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Localhold')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your data stays here',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'This Free foundation has no Localhold account, payment, analytics, '
              'or backend dependency.',
            ),
            const Spacer(),
            Text(
              'Community source ${identity.communityRevisionLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

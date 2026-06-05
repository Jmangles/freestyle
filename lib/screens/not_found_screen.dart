import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../widgets/empty_state.dart';

/// Shown by GoRouter's [errorBuilder] when a URL matches no route (a 404).
/// Reachable mainly on web, where a user can type an arbitrary path.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        asset: 'assets/img/leashfall.svg',
        message: l10n.pageNotFound,
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.goHomeButton),
        ),
      ),
    );
  }
}

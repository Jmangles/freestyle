import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations_extension.dart';

/// AppBar leading widget with a back button and an optional home button.
class BackHomeLeading extends StatelessWidget {
  final bool showHome;

  const BackHomeLeading({super.key, this.showHome = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.backTooltip,
          onPressed: () => context.pop(),
        ),
        if (showHome)
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: context.l10n.homeTooltip,
            onPressed: () => context.go('/'),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  static const _breakpoint = 800.0;

  const MainShell({super.key, required this.navigationShell});

  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _breakpoint) {
          return _buildWideLayout(context);
        }
        return _buildNarrowLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTabTapped,
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt),
                label: Text(l10n.tricksNavLabel),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.tips_and_updates_outlined),
                selectedIcon: const Icon(Icons.tips_and_updates),
                label: Text(l10n.tipsNavLabel),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n.tricksNavLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tips_and_updates_outlined),
            selectedIcon: const Icon(Icons.tips_and_updates),
            label: l10n.tipsNavLabel,
          ),
        ],
      ),
    );
  }
}

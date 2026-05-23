import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  static const _breakpoint = 800.0;

  const MainShell({super.key, required this.navigationShell});

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
    return Scaffold(body: navigationShell);
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Scaffold(body: navigationShell);
  }
}

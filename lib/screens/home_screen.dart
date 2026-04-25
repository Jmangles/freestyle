import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../widgets/trick_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Trick>, Profile?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Trick>, Profile?)> _load() async {
    final tricks = await TricksService.getApprovedTricks();
    final profile = await AuthService.getCurrentProfile();
    return (tricks, profile);
  }

  void _refresh() => setState(() => _future = _load());

  Map<String, List<Trick>> _groupByTier(List<Trick> tricks) {
    final map = <String, List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(t.difficultyTier, () => []).add(t);
    }
    return map;
  }

  List<String> _sortedTiers(Set<String> tiers) {
    final ordered = kDifficultyTiers.where(tiers.contains).toList();
    final extras = tiers.where((t) => !kDifficultyTiers.contains(t)).toList()
      ..sort();
    return [...ordered, ...extras];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Trick>, Profile?)>(
      future: _future,
      builder: (context, snap) {
        final profile = snap.data?.$2;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Freestyle Highline'),
            actions: [
              if (profile?.isAdmin == true)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  tooltip: 'Admin',
                  onPressed: () => context.push('/admin'),
                ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Profile',
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/submit'),
            icon: const Icon(Icons.add),
            label: const Text('Submit Trick'),
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<(List<Trick>, Profile?)> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load tricks',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final tricks = snap.data!.$1;
    if (tricks.isEmpty) {
      return const Center(child: Text('No tricks yet. Be the first to submit one!'));
    }

    final grouped = _groupByTier(tricks);
    final tiers = _sortedTiers(grouped.keys.toSet());

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          for (final tier in tiers) ...[
            _TierHeader(tier: tier),
            ...grouped[tier]!.map((t) => TrickCard(trick: t)),
          ],
        ],
      ),
    );
  }
}

class _TierHeader extends StatelessWidget {
  final String tier;
  const _TierHeader({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        tier,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

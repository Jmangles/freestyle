import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/profile.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/trick_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Trick>, Profile?, Map<String, Consistency>)> _future;
  int _gridSize = 2;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Trick>, Profile?, Map<String, Consistency>)> _load() async {
    final tricksFuture = TricksService.getApprovedTricks();
    final profileFuture = AuthService.getCurrentProfile();
    final userTricksFuture = UserTricksService.getUserTricks();
    final tricks = await tricksFuture;
    final profile = await profileFuture;
    final userTricks = await userTricksFuture;
    final consistencyMap = {
      for (final ut in userTricks) ut.trickId: ut.consistency,
    };
    return (tricks, profile, consistencyMap);
  }

  void _refresh() => setState(() { _future = _load(); });

  int _crossAxisCount(double width) {
    const counts = {1: [4, 6, 8], 2: [3, 4, 5], 3: [2, 3, 4]};
    final bp = width >= 900 ? 2 : width >= 600 ? 1 : 0;
    return counts[_gridSize]![bp];
  }

  Widget _buildSizeSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.view_list, size: 20),
          Expanded(
            child: Slider(
              value: _gridSize.toDouble(),
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (v) => setState(() => _gridSize = v.round()),
            ),
          ),
          const Icon(Icons.view_module, size: 20),
        ],
      ),
    );
  }

  Map<String, List<Trick>> _groupByTier(List<Trick> tricks) {
    final map = <String, List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(t.difficultyTier, () => []).add(t);
    }
    return map;
  }

  List<String> _sortedTiers(Set<String> tiers) {
    final list = tiers.toList();
    list.sort((a, b) {
      final na = double.tryParse(a);
      final nb = double.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.compareTo(b);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Trick>, Profile?, Map<String, Consistency>)>(
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

  Widget _buildBody(AsyncSnapshot<(List<Trick>, Profile?, Map<String, Consistency>)> snap) {
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

    final consistencyMap = snap.data!.$3;
    final grouped = _groupByTier(tricks);
    final tiers = _sortedTiers(grouped.keys.toSet());

    return Column(
      children: [
        _buildSizeSlider(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isListMode = _gridSize == 0;
              final crossAxisCount = isListMode ? 1 : _crossAxisCount(constraints.maxWidth);
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  slivers: [
                    for (final tier in tiers) ...[
                      SliverToBoxAdapter(child: _TierHeader(tier: tier)),
                      if (isListMode)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final trick = grouped[tier]![i];
                              return TrickCard(
                                trick: trick,
                                consistency: consistencyMap[trick.id],
                                onReturn: _refresh,
                                listMode: true,
                              );
                            },
                            childCount: grouped[tier]!.length,
                          ),
                        )
                      else
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.4,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final trick = grouped[tier]![i];
                              return TrickCard(
                                trick: trick,
                                consistency: consistencyMap[trick.id],
                                onReturn: _refresh,
                              );
                            },
                            childCount: grouped[tier]!.length,
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TierHeader extends StatelessWidget {
  final String tier;
  const _TierHeader({required this.tier});

  @override
  Widget build(BuildContext context) {
    final label = tier == 'TBD' ? 'To Be Determined' : 'Difficulty $tier';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

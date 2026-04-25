import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/profile.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/trick_card.dart';

class _TrickFilter {
  final Set<int> tiers;
  final Set<String> startPositions;
  final Set<String> endPositions;
  final Set<Consistency?> consistencies; // null in set = not tracked
  final bool? hasVideo; // null = any

  const _TrickFilter({
    this.tiers = const {},
    this.startPositions = const {},
    this.endPositions = const {},
    this.consistencies = const {},
    this.hasVideo,
  });

  bool get isActive =>
      tiers.isNotEmpty ||
      startPositions.isNotEmpty ||
      endPositions.isNotEmpty ||
      consistencies.isNotEmpty ||
      hasVideo != null;

  int get activeCount =>
      (tiers.isNotEmpty ? 1 : 0) +
      (startPositions.isNotEmpty ? 1 : 0) +
      (endPositions.isNotEmpty ? 1 : 0) +
      (consistencies.isNotEmpty ? 1 : 0) +
      (hasVideo != null ? 1 : 0);

  List<Trick> apply(List<Trick> tricks, Map<int, Consistency> consistencyMap) {
    return tricks.where((t) {
      if (tiers.isNotEmpty && !tiers.contains(t.difficultyTier)) return false;
      if (startPositions.isNotEmpty) {
        if (t.startPositionName == null) return false;
        if (!startPositions.contains(t.startPositionName)) return false;
      }
      if (endPositions.isNotEmpty) {
        if (t.endPositionName == null) return false;
        if (!endPositions.contains(t.endPositionName)) return false;
      }
      if (consistencies.isNotEmpty && !consistencies.contains(consistencyMap[t.id])) return false;
      if (hasVideo == true && t.videoLink == null) return false;
      if (hasVideo == false && t.videoLink != null) return false;
      return true;
    }).toList();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Trick>, Profile?, Map<int, Consistency>)> _future;
  int _gridSize = 2;
  _TrickFilter _filter = const _TrickFilter();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Trick>, Profile?, Map<int, Consistency>)> _load() async {
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

  Map<int, List<Trick>> _groupByTier(List<Trick> tricks) {
    final map = <int, List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(t.difficultyTier, () => []).add(t);
    }
    return map;
  }

  List<int> _sortedTiers(Set<int> tiers) {
    final list = tiers.toList();
    // -1 (TBD) sorts last
    list.sort((a, b) => a == -1 ? 1 : b == -1 ? -1 : a.compareTo(b));
    return list;
  }

  void _showFilterSheet(List<Trick> tricks, Map<int, Consistency> consistencyMap) async {
    final result = await showModalBottomSheet<_TrickFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        tricks: tricks,
        consistencyMap: consistencyMap,
        current: _filter,
      ),
    );
    if (result != null) {
      setState(() => _filter = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Trick>, Profile?, Map<int, Consistency>)>(
      future: _future,
      builder: (context, snap) {
        final profile = snap.data?.$2;
        final tricks = snap.data?.$1 ?? [];
        final consistencyMap = snap.data?.$3 ?? {};
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
              Badge(
                isLabelVisible: _filter.isActive,
                label: Text(_filter.activeCount.toString()),
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onPressed: snap.hasData
                      ? () => _showFilterSheet(tricks, consistencyMap)
                      : null,
                ),
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

  Widget _buildBody(AsyncSnapshot<(List<Trick>, Profile?, Map<int, Consistency>)> snap) {
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

    final allTricks = snap.data!.$1;
    if (allTricks.isEmpty) {
      return const Center(child: Text('No tricks yet. Be the first to submit one!'));
    }

    final consistencyMap = snap.data!.$3;
    final tricks = _filter.apply(allTricks, consistencyMap);

    if (tricks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48),
            const SizedBox(height: 12),
            Text('No tricks match your filters',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _filter = const _TrickFilter()),
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

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
  final int tier;
  const _TierHeader({required this.tier});

  @override
  Widget build(BuildContext context) {
    final label = tier == -1 ? 'To Be Determined' : 'Difficulty $tier';
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

class _FilterSheet extends StatefulWidget {
  final List<Trick> tricks;
  final Map<int, Consistency> consistencyMap;
  final _TrickFilter current;

  const _FilterSheet({
    required this.tricks,
    required this.consistencyMap,
    required this.current,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _tiers;
  late Set<String> _startPositions;
  late Set<String> _endPositions;
  late Set<Consistency?> _consistencies;
  late bool? _hasVideo;

  @override
  void initState() {
    super.initState();
    _tiers = Set.from(widget.current.tiers);
    _startPositions = Set.from(widget.current.startPositions);
    _endPositions = Set.from(widget.current.endPositions);
    _consistencies = Set.from(widget.current.consistencies);
    _hasVideo = widget.current.hasVideo;
  }

  List<int> get _availableTiers {
    final tiers = widget.tricks.map((t) => t.difficultyTier).toSet().toList();
    tiers.sort((a, b) => a == -1 ? 1 : b == -1 ? -1 : a.compareTo(b));
    return tiers;
  }

  List<String> get _availableStartPositions =>
      widget.tricks.map((t) => t.startPositionName).whereType<String>().toSet().toList()..sort();

  List<String> get _availableEndPositions =>
      widget.tricks.map((t) => t.endPositionName).whereType<String>().toSet().toList()..sort();

  bool get _hasAnyConsistencyData => widget.consistencyMap.isNotEmpty ||
      widget.tricks.any((t) => widget.consistencyMap.containsKey(t.id));

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableTiers = _availableTiers;
    final availableStartPositions = _availableStartPositions;
    final availableEndPositions = _availableEndPositions;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Filter Tricks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _tiers = {};
                      _startPositions = {};
                      _endPositions = {};
                      _consistencies = {};
                      _hasVideo = null;
                    }),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  if (availableTiers.length > 1) ...[
                    _sectionLabel('Difficulty Tier'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tier in availableTiers)
                          FilterChip(
                            label: Text(tier == -1 ? 'TBD' : 'Tier $tier'),
                            selected: _tiers.contains(tier),
                            onSelected: (v) => setState(() {
                              if (v) _tiers.add(tier); else _tiers.remove(tier);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (availableStartPositions.isNotEmpty) ...[
                    _sectionLabel('Start Position'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final pos in availableStartPositions)
                          FilterChip(
                            label: Text(pos),
                            selected: _startPositions.contains(pos),
                            onSelected: (v) => setState(() {
                              if (v) _startPositions.add(pos); else _startPositions.remove(pos);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (availableEndPositions.isNotEmpty) ...[
                    _sectionLabel('End Position'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final pos in availableEndPositions)
                          FilterChip(
                            label: Text(pos),
                            selected: _endPositions.contains(pos),
                            onSelected: (v) => setState(() {
                              if (v) _endPositions.add(pos); else _endPositions.remove(pos);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  _sectionLabel('My Consistency'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Not Tracked'),
                        selected: _consistencies.contains(null),
                        onSelected: (v) => setState(() {
                          if (v) _consistencies.add(null); else _consistencies.remove(null);
                        }),
                      ),
                      for (final c in Consistency.values)
                        FilterChip(
                          label: Text(c.label),
                          selected: _consistencies.contains(c),
                          selectedColor: c.cardColor,
                          onSelected: (v) => setState(() {
                            if (v) _consistencies.add(c); else _consistencies.remove(c);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Video'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Has Video'),
                        selected: _hasVideo == true,
                        onSelected: (v) => setState(() => _hasVideo = v ? true : null),
                      ),
                      FilterChip(
                        label: const Text('No Video'),
                        selected: _hasVideo == false,
                        onSelected: (v) => setState(() => _hasVideo = v ? false : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _TrickFilter(
                        tiers: Set.unmodifiable(_tiers),
                        startPositions: Set.unmodifiable(_startPositions),
                        endPositions: Set.unmodifiable(_endPositions),
                        consistencies: Set.unmodifiable(_consistencies),
                        hasVideo: _hasVideo,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

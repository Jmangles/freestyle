import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/profile.dart';
import '../models/trick.dart';
import '../models/trick_filter.dart';
import '../models/trick_sort.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/trick_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(List<Trick>, Profile?, Map<int, Consistency>)> _future;
  int _gridSize = 2;
  TrickFilter _filter = const TrickFilter();
  TrickSorter _sorter = const TrickSorter();
  late TextEditingController _nameSearchController;
  String _nameQuery = '';

  @override
  void initState() {
    super.initState();
    _nameSearchController = TextEditingController();
    _future = _load();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  Future<(List<Trick>, Profile?, Map<int, Consistency>)> _load() async {
    final tricksFuture = TricksService.getApprovedTricks();
    final profileFuture = AuthService.getCurrentProfile();
    final userTricksFuture = UserTricksService.getUserTricks();
    final tricks = await tricksFuture;
    final profile = await profileFuture;
    final userTricks = await userTricksFuture;
    final consistencyMap = {
      for (final ut in userTricks) ut.trickId: ut.consistency
    };
    return (tricks, profile, consistencyMap);
  }

  void _refresh() => setState(() => _future = _load());

  int _crossAxisCount(double width) {
    const counts = {
      1: [4, 6, 8],
      2: [3, 4, 5],
      3: [2, 3, 4]
    };
    final bp = width >= 900
        ? 2
        : width >= 600
            ? 1
            : 0;
    return counts[_gridSize]![bp];
  }

  void _showFilterSheet(
      List<Trick> tricks, Map<int, Consistency> consistencyMap) async {
    final result = await showModalBottomSheet<TrickFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(
        tricks: tricks,
        consistencyMap: consistencyMap,
        current: _filter,
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  void _showSortSheet() async {
    final result = await showModalBottomSheet<TrickSorter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SortSheet(current: _sorter),
    );
    if (result != null) setState(() => _sorter = result);
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

  Widget _buildBody(
      AsyncSnapshot<(List<Trick>, Profile?, Map<int, Consistency>)> snap) {
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
      return const Center(
          child: Text('No tricks yet. Be the first to submit one!'));
    }

    final consistencyMap = snap.data!.$3;
    final filtered = _filter.apply(allTricks, consistencyMap);
    final nameQ = _nameQuery.toLowerCase();
    final tricks = nameQ.isEmpty
        ? filtered
        : filtered
            .where((t) =>
                t.givenName.toLowerCase().contains(nameQ) ||
                (t.technicalName?.toLowerCase().contains(nameQ) ?? false))
            .toList();

    final groups = _sorter.buildGroups(tricks, consistencyMap);
    final showDifficulty = _sorter.primary != PrimarySort.difficulty;

    return Column(
      children: [
        _ControlBar(
          sorter: _sorter,
          gridSize: _gridSize,
          onSortTap: _showSortSheet,
          onGridSizeChanged: (v) => setState(() => _gridSize = v),
          nameSearchController: _nameSearchController,
          onNameChanged: (v) => setState(() => _nameQuery = v),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isListMode = _gridSize == 0;
              final crossAxisCount =
                  isListMode ? 1 : _crossAxisCount(constraints.maxWidth);
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  slivers: [
                    for (final (label, groupTricks) in groups) ...[
                      SliverToBoxAdapter(child: _GroupHeader(label: label)),
                      if (isListMode)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => TrickCard(
                              trick: groupTricks[i],
                              consistency: consistencyMap[groupTricks[i].id],
                              onReturn: _refresh,
                              listMode: true,
                              showDifficulty: showDifficulty,
                            ),
                            childCount: groupTricks.length,
                          ),
                        )
                      else
                        SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.4,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => TrickCard(
                              trick: groupTricks[i],
                              consistency: consistencyMap[groupTricks[i].id],
                              onReturn: _refresh,
                              showDifficulty: showDifficulty,
                            ),
                            childCount: groupTricks.length,
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

class _ControlBar extends StatelessWidget {
  final TrickSorter sorter;
  final int gridSize;
  final VoidCallback onSortTap;
  final ValueChanged<int> onGridSizeChanged;
  final TextEditingController nameSearchController;
  final ValueChanged<String> onNameChanged;

  const _ControlBar({
    required this.sorter,
    required this.gridSize,
    required this.onSortTap,
    required this.onGridSizeChanged,
    required this.nameSearchController,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 250,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    sorter.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                  ),
                  label: Text(
                    '${sorter.primary.label}  ·  ${sorter.secondary.label}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onPressed: onSortTap,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: nameSearchController,
                  onChanged: onNameChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
              Padding(padding:EdgeInsetsGeometry.all(20)),
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    const Icon(Icons.view_list, size: 18),
                    Expanded(
                      child: Slider(
                        value: gridSize.toDouble(),
                        min: 0,
                        max: 3,
                        divisions: 3,
                        onChanged: (v) => onGridSizeChanged(v.round()),
                      ),
                    ),
                    const Icon(Icons.view_module, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
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

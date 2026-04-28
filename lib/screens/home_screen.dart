import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  List<Trick> _tricks = [];
  Profile? _profile;
  Map<int, Consistency> _consistencyMap = {};
  bool _initialLoading = true;
  bool _hasError = false;
  int _gridSize = 2;
  TrickFilter _filter = const TrickFilter();
  TrickSorter _sorter = const TrickSorter();
  late TextEditingController _nameSearchController;
  String _nameQuery = '';
  List<(String, List<Trick>)> _groups = [];
  late final StreamSubscription _authSub;

  @override
  void initState() {
    super.initState();
    _nameSearchController = TextEditingController();
    _load(initial: true);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _nameSearchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial)
      setState(() {
        _initialLoading = true;
        _hasError = false;
      });
    try {
      final tricksFuture = TricksService.getApprovedTricks();
      final profileFuture = AuthService.getCurrentProfile();
      final userTricksFuture = UserTricksService.getUserTricks();
      final tricks = await tricksFuture;
      final profile = await profileFuture;
      final userTricks = await userTricksFuture;
      final consistencyMap = {
        for (final ut in userTricks) ut.trickId: ut.consistency
      };
      if (mounted) {
        setState(() {
          _tricks = tricks;
          _profile = profile;
          _consistencyMap = consistencyMap;
          _initialLoading = false;
          _hasError = false;
          _recompute();
        });
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _initialLoading = false;
          _hasError = true;
        });
    }
  }

  void _recompute() {
    final nameQ = _nameQuery.toLowerCase();
    final filtered = _filter.apply(_tricks, _consistencyMap);
    final tricks = nameQ.isEmpty
        ? filtered
        : filtered
            .where((t) =>
                t.givenName.toLowerCase().contains(nameQ) ||
                (t.technicalName?.toLowerCase().contains(nameQ) ?? false))
            .toList();
    _groups = _sorter.buildGroups(tricks, _consistencyMap);

  }

  void _refresh() => _load();

  int _crossAxisCount(double width) {
    const sizes = {1: 225, 2: 275, 3: 325};
    const minCols = {1: 3, 2: 2, 3: 1};
    final calculated = (width / sizes[_gridSize]!).floor();
    return calculated.clamp(minCols[_gridSize]!, 20);
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet<TrickFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(
        tricks: _tricks,
        consistencyMap: _consistencyMap,
        current: _filter,
      ),
    );
    if (result != null) setState(() { _filter = result; _recompute(); });
  }

  void _showSortSheet() async {
    final result = await showModalBottomSheet<TrickSorter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SortSheet(current: _sorter),
    );
    if (result != null) setState(() { _sorter = result; _recompute(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freestyle Highline'),
        actions: [
          if (_profile?.isAdmin == true)
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
              onPressed: _initialLoading ? null : _showFilterSheet,
            ),
          ),
          IconButton(
            icon: Icon(AuthService.isLoggedIn ? Icons.person_outline : Icons.login),
            tooltip: AuthService.isLoggedIn ? 'Profile' : 'Sign In',
            onPressed: () => context.push(AuthService.isLoggedIn ? '/profile' : '/login'),
          ),
        ],
      ),
      floatingActionButton: AuthService.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/submit'),
              icon: const Icon(Icons.add),
              label: const Text('Submit Trick'),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
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

    if (_tricks.isEmpty) {
      return const Center(
          child: Text('No tricks yet. Be the first to submit one!'));
    }

    final consistencyMap = _consistencyMap;

    return Column(
      children: [
        _ControlBar(
          sorter: _sorter,
          gridSize: _gridSize,
          onSortTap: _showSortSheet,
          onGridSizeChanged: (v) => setState(() => _gridSize = v),
          nameSearchController: _nameSearchController,
          onNameChanged: (v) => setState(() { _nameQuery = v; _recompute(); }),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isListMode = _gridSize == 0;
              final crossAxisCount =
                  isListMode ? 1 : _crossAxisCount(constraints.maxWidth);
              final compact = _gridSize <= 1;
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  slivers: [
                    for (final (label, groupTricks) in _groups) ...[
                      SliverToBoxAdapter(child: _GroupHeader(label: label)),
                      if (isListMode)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => RepaintBoundary(
                              key: ValueKey(groupTricks[i].id),
                              child: TrickCard(
                                trick: groupTricks[i],
                                consistency: consistencyMap[groupTricks[i].id],
                                onReturn: _refresh,
                                listMode: true,
                                showDifficulty: true,
                                difficultyModifierOnly: _sorter.primary == PrimarySort.difficulty,
                              ),
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
                            mainAxisExtent: _gridSize <= 1 ? 64.0 : 100.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => RepaintBoundary(
                              key: ValueKey(groupTricks[i].id),
                              child: TrickCard(
                                trick: groupTricks[i],
                                consistency: consistencyMap[groupTricks[i].id],
                                onReturn: _refresh,
                                showDifficulty: true,
                                difficultyModifierOnly: _sorter.primary == PrimarySort.difficulty,
                                compact: compact,
                              ),
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
              TextButton.icon(
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
              Flexible(
                flex: 6,
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
              const SizedBox(width: 4),
              Flexible(
                flex: 2,
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

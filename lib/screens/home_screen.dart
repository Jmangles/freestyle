import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../constants/layout_constants.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
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
  bool _editorMode = false;
  int _gridSize = 2;
  TrickFilter _filter = const TrickFilter();
  TrickSorter _sorter = const TrickSorter();
  late TextEditingController _nameSearchController;
  List<(String, List<Trick>)> _groups = [];
  late final StreamSubscription _authSub;
  late final RealtimeChannel _tricksChannel;
  bool _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    _nameSearchController = TextEditingController();
    _load(initial: true);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _load(); // guard inside _load() prevents concurrent runs
    });
    _tricksChannel = Supabase.instance.client
        .channel('public:tricks')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tricks',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _authSub.cancel();
    Supabase.instance.client.removeChannel(_tricksChannel);
    _nameSearchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (initial) {
      setState(() {
        _initialLoading = true;
        _hasError = false;
      });
    }
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
    } catch (e, st) {
      debugPrint('HomeScreen._load error: $e\n$st');
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _loadInProgress = false;
    }
  }

  void _recompute() {
    final nameQ = _nameSearchController.text.toLowerCase();
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

  Widget _buildTrickCard(Trick trick, {bool listMode = false, bool compact = false}) {
    return RepaintBoundary(
      key: ValueKey(trick.id),
      child: TrickCard(
        trick: trick,
        consistency: _consistencyMap[trick.id],
        onReturn: _refresh,
        listMode: listMode,
        showDifficulty: true,
        difficultyModifierOnly: _sorter.primary == PrimarySort.difficulty,
        compact: compact,
        editorMode: _editorMode,
      ),
    );
  }

  int _crossAxisCount(double width) {
    final calculated = (width / kGridCellWidth[_gridSize]!).floor();
    return calculated.clamp(kGridMinColumns[_gridSize]!, 20);
  }

  void _showFilterSheet() async {
    final result = await showModalBottomSheet<(TrickFilter, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterSheet(
        tricks: _tricks,
        consistencyMap: _consistencyMap,
        current: _filter,
        isEditor: _profile?.canEditTricks == true,
        editorMode: _editorMode,
      ),
    );
    if (result != null) {
      setState(() {
        _filter = result.$1;
        _editorMode = result.$2;
        _recompute();
      });
    }
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (_profile?.canEditTricks == true)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: l10n.adminLabel,
              onPressed: () => context.push('/admin'),
            ),
          Badge(
            isLabelVisible: _filter.isActive,
            label: Text(_filter.activeCount.toString()),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: l10n.filterTooltip,
              onPressed: _initialLoading ? null : _showFilterSheet,
            ),
          ),
          IconButton(
            icon: Icon(AuthService.isLoggedIn ? Icons.person_outline : Icons.login),
            tooltip: AuthService.isLoggedIn ? l10n.profileTooltip : l10n.signInTooltip,
            onPressed: () => context.push(AuthService.isLoggedIn ? '/profile' : '/login'),
          ),
        ],
      ),
      floatingActionButton: AuthService.isLoggedIn
          ? FloatingActionButton.extended(
              heroTag: 'home_fab',
              onPressed: () => context.push('/submit'),
              icon: const Icon(Icons.add),
              label: Text(l10n.submitTrickButton),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.failedToLoadTricks,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton(onPressed: _refresh, child: Text(l10n.retryButton)),
          ],
        ),
      );
    }

    if (_tricks.isEmpty) {
      return Center(child: Text(l10n.noTricksYet));
    }

    return Column(
      children: [
        _ControlBar(
          sorter: _sorter,
          gridSize: _gridSize,
          onSortTap: _showSortSheet,
          onGridSizeChanged: (v) => setState(() => _gridSize = v),
          nameSearchController: _nameSearchController,
          onNameChanged: () => setState(() => _recompute()),
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
                      SliverToBoxAdapter(
                        child: _GroupHeader(
                          label: translateGroupLabel(label, l10n),
                          totalCount: groupTricks.length,
                          landedCount: AuthService.isLoggedIn &&
                                  (_filter.statuses.isEmpty ||
                                      (_filter.statuses
                                              .contains(TrickStatus.landed) &&
                                          _filter.statuses.any(
                                              (s) => s != TrickStatus.landed)))
                              ? groupTricks
                                  .where((t) =>
                                      _consistencyMap[t.id]?.isLanded == true)
                                  .length
                              : null,
                        ),
                      ),
                      if (isListMode)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildTrickCard(groupTricks[i], listMode: true),
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
                            mainAxisExtent: compact ? kGridCompactExtent : kGridNormalExtent,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _buildTrickCard(groupTricks[i], compact: compact),
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
  final VoidCallback onNameChanged;

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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const fixedWidth = 250.0 + 40.0 + 140.0;
          final searchFits = constraints.maxWidth - fixedWidth >= 300;

          final sortButton = SizedBox(
            width: 250,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                sorter.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
              label: Text(
                '${sorter.primary.localizedLabel(l10n)}  ·  ${sorter.secondary.localizedLabel(l10n)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onPressed: onSortTap,
            ),
          );

          final searchField = TextField(
            controller: nameSearchController,
            onChanged: (_) => onNameChanged(),
            decoration: InputDecoration(
              hintText: l10n.searchByNameHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            textInputAction: TextInputAction.search,
          );

          final gridSlider = SizedBox(
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
          );

          if (searchFits) {
            return Row(
              children: [
                sortButton,
                Expanded(child: searchField),
                const SizedBox(width: 40),
                gridSlider,
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [sortButton, const Spacer(), gridSlider],
                ),
                const SizedBox(height: 4),
                searchField,
              ],
            );
          }
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int totalCount;
  final int? landedCount;

  const _GroupHeader({
    required this.label,
    required this.totalCount,
    this.landedCount,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        );
    final countText = landedCount != null
        ? '$landedCount / $totalCount'
        : '$totalCount';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 8),
          Text(
            countText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

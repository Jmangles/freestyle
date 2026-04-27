import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/profile.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/trick_card.dart';

enum _TrickStatus {
  neverAttempted('Never Attempted'),
  attempting('Attempting'),
  landed('Landed at least once');

  const _TrickStatus(this.label);
  final String label;
}

class _TrickFilter {
  final int? tierMin;
  final int? tierMax;
  final bool includeTbd;
  final String? startPosition;
  final String? endPosition;
  final Set<_TrickStatus> statuses;
  final int? yearLanded;
  final String performerQuery;
  final String nameQuery;

  const _TrickFilter({
    this.tierMin,
    this.tierMax,
    this.includeTbd = true,
    this.startPosition,
    this.endPosition,
    this.statuses = const {},
    this.yearLanded,
    this.performerQuery = '',
    this.nameQuery = '',
  });

  bool get isActive =>
      tierMin != null ||
      tierMax != null ||
      !includeTbd ||
      startPosition != null ||
      endPosition != null ||
      statuses.isNotEmpty ||
      yearLanded != null ||
      performerQuery.isNotEmpty ||
      nameQuery.isNotEmpty;

  int get activeCount =>
      ((tierMin != null || tierMax != null) ? 1 : 0) +
      (!includeTbd ? 1 : 0) +
      (startPosition != null ? 1 : 0) +
      (endPosition != null ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (yearLanded != null ? 1 : 0) +
      (performerQuery.isNotEmpty ? 1 : 0) +
      (nameQuery.isNotEmpty ? 1 : 0);

  _TrickStatus _statusFor(int trickId, Map<int, Consistency> consistencyMap) {
    final c = consistencyMap[trickId];
    if (c == null) return _TrickStatus.neverAttempted;
    if (c == Consistency.never) return _TrickStatus.attempting;
    return _TrickStatus.landed;
  }

  List<Trick> apply(List<Trick> tricks, Map<int, Consistency> consistencyMap) {
    return tricks.where((t) {
      if (t.difficultyTier == -1) {
        if (!includeTbd) return false;
      } else {
        if (tierMin != null && t.difficultyTier < tierMin!) return false;
        if (tierMax != null && t.difficultyTier > tierMax!) return false;
      }
      if (startPosition != null && t.startPositionName != startPosition) return false;
      if (endPosition != null && t.endPositionName != endPosition) return false;
      if (statuses.isNotEmpty && !statuses.contains(_statusFor(t.id, consistencyMap))) return false;
      if (yearLanded != null && t.datePerformed?.year != yearLanded) return false;
      if (performerQuery.isNotEmpty) {
        final q = performerQuery.toLowerCase();
        if (!(t.originalPerformer?.toLowerCase().contains(q) ?? false)) return false;
      }
      if (nameQuery.isNotEmpty) {
        final q = nameQuery.toLowerCase();
        final matchesGiven = t.givenName.toLowerCase().contains(q);
        final matchesTechnical = t.technicalName?.toLowerCase().contains(q) ?? false;
        if (!matchesGiven && !matchesTechnical) return false;
      }
      return true;
    }).toList();
  }
}

enum _PrimarySort {
  difficulty('Difficulty Tier'),
  startPosition('Start Position'),
  yearLanded('Year Landed'),
  consistency('Consistency');

  const _PrimarySort(this.label);
  final String label;
}

enum _SecondarySort {
  difficulty('Difficulty Tier'),
  startPosition('Start Position'),
  endPosition('End Position'),
  consistency('Consistency'),
  alphabetical('Alphabetical');

  const _SecondarySort(this.label);
  final String label;
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
  _PrimarySort _primarySort = _PrimarySort.difficulty;
  _SecondarySort _secondarySort = _SecondarySort.alphabetical;
  bool _sortAscending = true;

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

  String _primaryLabel(Trick t, Map<int, Consistency> consistencyMap) {
    switch (_primarySort) {
      case _PrimarySort.difficulty:
        return t.difficultyTier == -1 ? 'To Be Determined' : 'Difficulty ${t.difficultyTier}';
      case _PrimarySort.startPosition:
        return t.startPositionName ?? 'Unknown';
      case _PrimarySort.yearLanded:
        return t.datePerformed?.year.toString() ?? 'Unknown';
      case _PrimarySort.consistency:
        final c = consistencyMap[t.id];
        if (c == null) return 'Never Attempted';
        if (c == Consistency.never) return 'Attempting';
        return 'Landed';
    }
  }

  int _compareGroupLabels(String a, String b) {
    switch (_primarySort) {
      case _PrimarySort.difficulty:
        if (a == 'To Be Determined') return 1;
        if (b == 'To Be Determined') return -1;
        final ta = int.tryParse(a.replaceFirst('Difficulty ', '')) ?? 0;
        final tb = int.tryParse(b.replaceFirst('Difficulty ', '')) ?? 0;
        return ta.compareTo(tb);
      case _PrimarySort.startPosition:
      case _PrimarySort.yearLanded:
        if (a == 'Unknown') return 1;
        if (b == 'Unknown') return -1;
        return a.compareTo(b);
      case _PrimarySort.consistency:
        const order = {'Never Attempted': 0, 'Attempting': 1, 'Landed': 2};
        return (order[a] ?? 0).compareTo(order[b] ?? 0);
    }
  }

  int _compareSecondary(Trick a, Trick b, Map<int, Consistency> consistencyMap) {
    switch (_secondarySort) {
      case _SecondarySort.difficulty:
        if (a.difficultyTier == b.difficultyTier) return 0;
        if (a.difficultyTier == -1) return 1;
        if (b.difficultyTier == -1) return -1;
        return a.difficultyTier.compareTo(b.difficultyTier);
      case _SecondarySort.startPosition:
        return (a.startPositionName ?? 'zzz').toLowerCase()
            .compareTo((b.startPositionName ?? 'zzz').toLowerCase());
      case _SecondarySort.endPosition:
        return (a.endPositionName ?? 'zzz').toLowerCase()
            .compareTo((b.endPositionName ?? 'zzz').toLowerCase());
      case _SecondarySort.consistency:
        int rank(int id) {
          final c = consistencyMap[id];
          if (c == null) return 0;
          if (c == Consistency.never) return 1;
          return 2;
        }
        return rank(a.id).compareTo(rank(b.id));
      case _SecondarySort.alphabetical:
        return a.givenName.toLowerCase().compareTo(b.givenName.toLowerCase());
    }
  }

  List<(String, List<Trick>)> _buildSortedGroups(
    List<Trick> tricks,
    Map<int, Consistency> consistencyMap,
  ) {
    final map = <String, List<Trick>>{};
    for (final t in tricks) {
      map.putIfAbsent(_primaryLabel(t, consistencyMap), () => []).add(t);
    }

    final entries = map.entries.toList()
      ..sort((a, b) {
        final cmp = _compareGroupLabels(a.key, b.key);
        return _sortAscending ? cmp : -cmp;
      });

    for (final e in entries) {
      e.value.sort((a, b) {
        final cmp = _compareSecondary(a, b, consistencyMap);
        return _sortAscending ? cmp : -cmp;
      });
    }

    return [for (final e in entries) (e.key, e.value)];
  }

  void _showSortSheet() async {
    final result = await showModalBottomSheet<(_PrimarySort, _SecondarySort, bool)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SortSheet(
        primarySort: _primarySort,
        secondarySort: _secondarySort,
        ascending: _sortAscending,
      ),
    );
    if (result != null) {
      setState(() {
        _primarySort = result.$1;
        _secondarySort = result.$2;
        _sortAscending = result.$3;
      });
    }
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
              label: Text(
                '${_primarySort.label}  ·  ${_secondarySort.label}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onPressed: _showSortSheet,
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                const Icon(Icons.view_list, size: 18),
                Expanded(
                  child: Slider(
                    value: _gridSize.toDouble(),
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: (v) => setState(() => _gridSize = v.round()),
                  ),
                ),
                const Icon(Icons.view_module, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
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

    final groups = _buildSortedGroups(tricks, consistencyMap);

    return Column(
      children: [
        _buildControlBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isListMode = _gridSize == 0;
              final crossAxisCount = isListMode ? 1 : _crossAxisCount(constraints.maxWidth);
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  slivers: [
                    for (final (label, groupTricks) in groups) ...[
                      SliverToBoxAdapter(child: _GroupHeader(label: label)),
                      if (isListMode)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final trick = groupTricks[i];
                              return TrickCard(
                                trick: trick,
                                consistency: consistencyMap[trick.id],
                                onReturn: _refresh,
                                listMode: true,
                              );
                            },
                            childCount: groupTricks.length,
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
                              final trick = groupTricks[i];
                              return TrickCard(
                                trick: trick,
                                consistency: consistencyMap[trick.id],
                                onReturn: _refresh,
                              );
                            },
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

class _SortSheet extends StatefulWidget {
  final _PrimarySort primarySort;
  final _SecondarySort secondarySort;
  final bool ascending;

  const _SortSheet({
    required this.primarySort,
    required this.secondarySort,
    required this.ascending,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late _PrimarySort _primarySort;
  late _SecondarySort _secondarySort;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _primarySort = widget.primarySort;
    _secondarySort = widget.secondarySort;
    _ascending = widget.ascending;
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort Tricks',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _sectionLabel('Order'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Ascending'),
                        icon: Icon(Icons.arrow_upward, size: 16),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Descending'),
                        icon: Icon(Icons.arrow_downward, size: 16),
                      ),
                    ],
                    selected: {_ascending},
                    onSelectionChanged: (v) => setState(() => _ascending = v.first),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Group By'),
                  RadioGroup<_PrimarySort>(
                    groupValue: _primarySort,
                    onChanged: (v) { if (v != null) setState(() => _primarySort = v); },
                    child: Column(
                      children: [
                        for (final sort in _PrimarySort.values)
                          RadioListTile<_PrimarySort>(
                            value: sort,
                            title: Text(sort.label),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Sort Within Group By'),
                  RadioGroup<_SecondarySort>(
                    groupValue: _secondarySort,
                    onChanged: (v) { if (v != null) setState(() => _secondarySort = v); },
                    child: Column(
                      children: [
                        for (final sort in _SecondarySort.values)
                          RadioListTile<_SecondarySort>(
                            value: sort,
                            title: Text(sort.label),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context)
                        .pop((_primarySort, _secondarySort, _ascending)),
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
  late int _tierMin;
  late int _tierMax;
  late bool _includeTbd;
  late String? _startPosition;
  late String? _endPosition;
  late Set<_TrickStatus> _statuses;
  late int? _yearLanded;
  late TextEditingController _performerController;
  late TextEditingController _nameController;

  late int _dataMinTier;
  late int _dataMaxTier;
  late bool _hasTbd;
  late bool _hasMultipleNumericTiers;
  int _dropdownResetKey = 0;

  @override
  void initState() {
    super.initState();
    final numericTiers = widget.tricks
        .map((t) => t.difficultyTier)
        .where((t) => t != -1)
        .toSet()
        .toList()
      ..sort();
    _hasTbd = widget.tricks.any((t) => t.difficultyTier == -1);
    _dataMinTier = numericTiers.isEmpty ? 1 : numericTiers.first;
    _dataMaxTier = numericTiers.isEmpty ? 1 : numericTiers.last;
    _hasMultipleNumericTiers = numericTiers.length > 1;

    _tierMin = widget.current.tierMin ?? _dataMinTier;
    _tierMax = widget.current.tierMax ?? _dataMaxTier;
    _includeTbd = widget.current.includeTbd;
    _startPosition = widget.current.startPosition;
    _endPosition = widget.current.endPosition;
    _statuses = Set.from(widget.current.statuses);
    _yearLanded = widget.current.yearLanded;
    _performerController = TextEditingController(text: widget.current.performerQuery);
    _nameController = TextEditingController(text: widget.current.nameQuery);
  }

  @override
  void dispose() {
    _performerController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  List<String> get _availableStartPositions =>
      widget.tricks.map((t) => t.startPositionName).whereType<String>().toSet().toList()..sort();

  List<String> get _availableEndPositions =>
      widget.tricks.map((t) => t.endPositionName).whereType<String>().toSet().toList()..sort();

  List<int> get _availableYears =>
      widget.tricks.map((t) => t.datePerformed?.year).whereType<int>().toSet().toList()
        ..sort((a, b) => b.compareTo(a));

  void _clearAll() => setState(() {
        _tierMin = _dataMinTier;
        _tierMax = _dataMaxTier;
        _includeTbd = true;
        _startPosition = null;
        _endPosition = null;
        _statuses = {};
        _yearLanded = null;
        _performerController.clear();
        _nameController.clear();
        _dropdownResetKey++;
      });

  _TrickFilter _buildResult() => _TrickFilter(
        tierMin: _tierMin == _dataMinTier ? null : _tierMin,
        tierMax: _tierMax == _dataMaxTier ? null : _tierMax,
        includeTbd: _includeTbd,
        startPosition: _startPosition,
        endPosition: _endPosition,
        statuses: Set.unmodifiable(_statuses),
        yearLanded: _yearLanded,
        performerQuery: _performerController.text.trim(),
        nameQuery: _nameController.text.trim(),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final availableStartPositions = _availableStartPositions;
    final availableEndPositions = _availableEndPositions;
    final availableYears = _availableYears;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  // ── Difficulty Tier ──────────────────────────────────
                  if (_hasMultipleNumericTiers || _hasTbd) ...[
                    _sectionLabel('Difficulty Tier'),
                    if (_hasMultipleNumericTiers) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tier $_tierMin',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text('Tier $_tierMax',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(
                          _tierMin.toDouble(),
                          _tierMax.toDouble(),
                        ),
                        min: _dataMinTier.toDouble(),
                        max: _dataMaxTier.toDouble(),
                        divisions: _dataMaxTier - _dataMinTier,
                        labels: RangeLabels(
                          'Tier $_tierMin',
                          'Tier $_tierMax',
                        ),
                        onChanged: (v) => setState(() {
                          _tierMin = v.start.round();
                          _tierMax = v.end.round();
                        }),
                      ),
                    ],
                    if (_hasTbd)
                      FilterChip(
                        label: const Text('Include TBD'),
                        selected: _includeTbd,
                        onSelected: (v) => setState(() => _includeTbd = v),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // ── Position ─────────────────────────────────────────
                  if (availableStartPositions.isNotEmpty ||
                      availableEndPositions.isNotEmpty) ...[
                    _sectionLabel('Position'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('start_$_dropdownResetKey'),
                            initialValue: _startPosition,
                            decoration: const InputDecoration(
                              labelText: 'Start',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Any')),
                              for (final pos in availableStartPositions)
                                DropdownMenuItem(
                                    value: pos, child: Text(pos)),
                            ],
                            onChanged: (v) =>
                                setState(() => _startPosition = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('end_$_dropdownResetKey'),
                            initialValue: _endPosition,
                            decoration: const InputDecoration(
                              labelText: 'End',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('Any')),
                              for (final pos in availableEndPositions)
                                DropdownMenuItem(
                                    value: pos, child: Text(pos)),
                            ],
                            onChanged: (v) =>
                                setState(() => _endPosition = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Status ───────────────────────────────────────────
                  _sectionLabel('Status'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final status in _TrickStatus.values)
                        FilterChip(
                          label: Text(status.label),
                          selected: _statuses.contains(status),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _statuses.add(status);
                            } else {
                              _statuses.remove(status);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Year Landed ──────────────────────────────────────
                  if (availableYears.isNotEmpty) ...[
                    _sectionLabel('Year Landed'),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('year_$_dropdownResetKey'),
                      initialValue: _yearLanded,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Any')),
                        for (final year in availableYears)
                          DropdownMenuItem(
                              value: year, child: Text(year.toString())),
                      ],
                      onChanged: (v) => setState(() => _yearLanded = v),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Name ────────────────────────────────────────────
                  _sectionLabel('Name'),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // ── Original Performer ───────────────────────────────
                  _sectionLabel('Original Performer'),
                  TextField(
                    controller: _performerController,
                    decoration: const InputDecoration(
                      hintText: 'Search by performer...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
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
                    onPressed: () =>
                        Navigator.of(context).pop(_buildResult()),
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

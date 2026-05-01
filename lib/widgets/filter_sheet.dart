import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/trick.dart';
import '../models/trick_filter.dart';
import '../models/user_trick.dart';

class FilterSheet extends StatefulWidget {
  final List<Trick> tricks;
  final Map<int, Consistency> consistencyMap;
  final TrickFilter current;

  const FilterSheet({
    super.key,
    required this.tricks,
    required this.consistencyMap,
    required this.current,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late int _tierMin;
  late int _tierMax;
  late bool _includeTbd;
  late String? _startPosition;
  late String? _endPosition;
  late Set<TrickStatus> _statuses;
  late int? _yearLanded;
  late TextEditingController _performerController;

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
  }

  @override
  void dispose() {
    _performerController.dispose();
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
        _dropdownResetKey++;
      });

  TrickFilter _buildResult() => TrickFilter(
        tierMin: _tierMin == _dataMinTier ? null : _tierMin,
        tierMax: _tierMax == _dataMaxTier ? null : _tierMax,
        includeTbd: _includeTbd,
        startPosition: _startPosition,
        endPosition: _endPosition,
        statuses: Set.unmodifiable(_statuses),
        yearLanded: _yearLanded,
        performerQuery: _performerController.text.trim(),
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
    final l10n = context.l10n;
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
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Text(
                    l10n.filterTricksTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(l10n.clearAllButton),
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
                  if (_hasMultipleNumericTiers || _hasTbd) ...[
                    _sectionLabel(l10n.difficultyTierSection),
                    if (_hasMultipleNumericTiers) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.tierRangeLabel(Trick.tierLabel(_tierMin)),
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(l10n.tierRangeLabel(Trick.tierLabel(_tierMax)),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(_tierMin.toDouble(), _tierMax.toDouble()),
                        min: _dataMinTier.toDouble(),
                        max: _dataMaxTier.toDouble(),
                        divisions: _dataMaxTier - _dataMinTier,
                        labels: RangeLabels(
                          l10n.tierRangeLabel(Trick.tierLabel(_tierMin)),
                          l10n.tierRangeLabel(Trick.tierLabel(_tierMax)),
                        ),
                        onChanged: (v) => setState(() {
                          _tierMin = v.start.round();
                          _tierMax = v.end.round();
                        }),
                      ),
                    ],
                    if (_hasTbd)
                      FilterChip(
                        label: Text(l10n.includeTbdChip),
                        selected: _includeTbd,
                        onSelected: (v) => setState(() => _includeTbd = v),
                      ),
                    const SizedBox(height: 20),
                  ],
                  if (availableStartPositions.isNotEmpty ||
                      availableEndPositions.isNotEmpty) ...[
                    _sectionLabel(l10n.positionSection),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('start_$_dropdownResetKey'),
                            initialValue: _startPosition,
                            decoration: InputDecoration(
                              labelText: l10n.startLabel,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: null, child: Text(l10n.anyOption)),
                              for (final pos in availableStartPositions)
                                DropdownMenuItem(value: pos, child: Text(pos)),
                            ],
                            onChanged: (v) => setState(() => _startPosition = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('end_$_dropdownResetKey'),
                            initialValue: _endPosition,
                            decoration: InputDecoration(
                              labelText: l10n.endLabel,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value: null, child: Text(l10n.anyOption)),
                              for (final pos in availableEndPositions)
                                DropdownMenuItem(value: pos, child: Text(pos)),
                            ],
                            onChanged: (v) => setState(() => _endPosition = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionLabel(l10n.statusSection),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final status in TrickStatus.values)
                        FilterChip(
                          label: Text(status.localizedLabel(l10n)),
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
                  if (availableYears.isNotEmpty) ...[
                    _sectionLabel(l10n.yearLandedSection),
                    DropdownButtonFormField<int?>(
                      key: ValueKey('year_$_dropdownResetKey'),
                      initialValue: _yearLanded,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.anyOption)),
                        for (final year in availableYears)
                          DropdownMenuItem(value: year, child: Text(year.toString())),
                      ],
                      onChanged: (v) => setState(() => _yearLanded = v),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionLabel(l10n.originalPerformerLabel),
                  TextField(
                    controller: _performerController,
                    decoration: InputDecoration(
                      hintText: l10n.searchByPerformerHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
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
                    onPressed: () => Navigator.of(context).pop(_buildResult()),
                    child: Text(l10n.applyButton),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

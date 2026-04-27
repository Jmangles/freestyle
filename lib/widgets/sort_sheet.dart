import 'package:flutter/material.dart';
import '../models/trick_sort.dart';

class SortSheet extends StatefulWidget {
  final TrickSorter current;

  const SortSheet({super.key, required this.current});

  @override
  State<SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<SortSheet> {
  late PrimarySort _primary;
  late SecondarySort _secondary;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _primary = widget.current.primary;
    _secondary = widget.current.secondary;
    _ascending = widget.current.ascending;
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
            const _SheetHandle(),
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
                  RadioGroup<PrimarySort>(
                    groupValue: _primary,
                    onChanged: (v) { if (v != null) setState(() => _primary = v); },
                    child: Column(
                      children: [
                        for (final sort in PrimarySort.values)
                          RadioListTile<PrimarySort>(
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
                  RadioGroup<SecondarySort>(
                    groupValue: _secondary,
                    onChanged: (v) { if (v != null) setState(() => _secondary = v); },
                    child: Column(
                      children: [
                        for (final sort in SecondarySort.values)
                          RadioListTile<SecondarySort>(
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
                    onPressed: () => Navigator.of(context).pop(
                      TrickSorter(
                        primary: _primary,
                        secondary: _secondary,
                        ascending: _ascending,
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

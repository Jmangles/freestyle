import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/user_trick.dart';

class ConsistencySelector extends StatelessWidget {
  final Consistency? selected;
  final ValueChanged<Consistency> onChanged;

  const ConsistencySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Consistency.values.map((c) {
        final isSelected = c == selected;
        return ChoiceChip(
          label: Text(c.localizedLabel(context.l10n)),
          selected: isSelected,
          onSelected: (_) => onChanged(c),
          selectedColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}

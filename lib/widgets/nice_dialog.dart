import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/user_trick.dart';
import 'consistency_selector.dart';

/// "Nice!" popup shown when a not-yet-landed trick is checked off. Returns the
/// chosen stick frequency (default [Consistency.once]) or null if dismissed.
Future<Consistency?> showNiceDialog(BuildContext context) {
  return showDialog<Consistency>(
    context: context,
    builder: (ctx) {
      var selected = Consistency.once;
      final l10n = ctx.l10n;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.niceTitle),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.niceSubtitle),
                const SizedBox(height: 16),
                ConsistencySelector(
                  selected: selected,
                  onChanged: (c) => setState(() => selected = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(l10n.confirmButton),
            ),
          ],
        ),
      );
    },
  );
}

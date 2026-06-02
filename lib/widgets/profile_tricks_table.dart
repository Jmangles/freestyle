import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/screen_data.dart';
import '../models/user_trick.dart';
import 'consistency_selector.dart';

/// Scrollable table of a user's tracked tricks with tap-to-change-consistency.
class ProfileTricksTable extends StatelessWidget {
  final List<UserTrickEntry> entries;
  final void Function(int trickId, Consistency consistency) onConsistencyChanged;

  const ProfileTricksTable({
    super.key,
    required this.entries,
    required this.onConsistencyChanged,
  });

  void _showConsistencySheet(BuildContext context, UserTrickEntry entry) {
    final trick = entry.trick!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trick.givenName,
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              trick.difficultyLabel,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            ConsistencySelector(
              selected: entry.userTrick.consistency,
              onChanged: (c) {
                Navigator.pop(ctx);
                onConsistencyChanged(trick.id, c);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final brightness = theme.brightness;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(child: Text(l10n.columnTrick, style: labelStyle)),
              SizedBox(
                  width: 56,
                  child: Text(l10n.columnTier,
                      textAlign: TextAlign.center, style: labelStyle)),
              SizedBox(
                  width: 88,
                  child: Text(l10n.columnConsistency,
                      textAlign: TextAlign.right, style: labelStyle)),
            ],
          ),
        ),
        const Divider(height: 1),
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          Builder(builder: (context) {
            final entry = entries[i];
            final trick = entry.trick;
            if (trick == null) return const SizedBox.shrink();
            final userTrick = entry.userTrick;
            final consistencyColor = userTrick.consistency.borderColor(brightness);
            return InkWell(
              onTap: () => _showConsistencySheet(context, entry),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trick.givenName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        trick.difficultyLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Text(
                        userTrick.consistency.localizedLabel(l10n),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: consistencyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

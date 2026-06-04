import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';
import 'profile_tricks_table.dart';

/// Tabbed card showing "My Tricks" and "What's Next" progression tabs.
class ProfileMainCard extends StatefulWidget {
  final List<UserTrickEntry> entries;
  final WhatsNextData whatsNext;
  final void Function(int trickId, Consistency consistency) onConsistencyChanged;

  const ProfileMainCard({
    super.key,
    required this.entries,
    required this.whatsNext,
    required this.onConsistencyChanged,
  });

  @override
  State<ProfileMainCard> createState() => _ProfileMainCardState();
}

class _ProfileMainCardState extends State<ProfileMainCard> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entries = widget.entries;
    final whatsNext = widget.whatsNext;

    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    var idx = 0;
    final myTricksTab = idx++;
    final unlockedTab = whatsNext.unlocked.isNotEmpty ? idx++ : -1;
    final partialTab = whatsNext.partiallyUnlocked.isNotEmpty ? idx++ : -1;
    final highValueTab = whatsNext.highValue.isNotEmpty ? idx++ : -1;
    final tabCount = idx;
    final tab = _activeTab.clamp(0, tabCount - 1);

    final landedCount =
        entries.where((e) => e.userTrick.consistency.isLanded).length;
    final attemptingCount =
        entries.where((e) => !e.userTrick.consistency.isLanded).length;

    final descriptions = {
      myTricksTab: entries.isEmpty
          ? l10n.noTricksTracked
          : l10n.tricksProgress(landedCount, attemptingCount),
      unlockedTab: l10n.tabReadyToStartDesc,
      partialTab: l10n.tabMakingProgressDesc,
      highValueTab: l10n.tabHighValueDesc,
    };

    Widget tabBtn(String label, IconData icon, Color color, int index,
        {bool iconsOnly = false}) {
      final selected = tab == index;
      final iconColor =
          selected ? color : theme.colorScheme.onSurfaceVariant;
      return Tooltip(
        message: iconsOnly ? label : '',
        child: InkWell(
          onTap: () => setState(() => _activeTab = index),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: iconsOnly ? 16 : 14, vertical: 14),
            child: iconsOnly
                ? Icon(icon, size: 22, color: iconColor)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? color
                                : theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final iconsOnly = constraints.maxWidth < 500;
            return Row(
              children: [
                tabBtn(l10n.tabMyTricks, Icons.list,
                    theme.colorScheme.primary, myTricksTab,
                    iconsOnly: iconsOnly),
                if (unlockedTab >= 0)
                  tabBtn(l10n.tabReadyToStart, Icons.lock_open,
                      theme.colorScheme.primary, unlockedTab,
                      iconsOnly: iconsOnly),
                if (partialTab >= 0)
                  tabBtn(l10n.tabMakingProgress, Icons.trending_up,
                      theme.colorScheme.primary, partialTab,
                      iconsOnly: iconsOnly),
                if (highValueTab >= 0)
                  tabBtn(l10n.tabHighValue, Icons.star,
                      theme.colorScheme.primary, highValueTab,
                      iconsOnly: iconsOnly),
              ],
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Text(
              descriptions[tab] ?? '',
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),

          if (tab == myTricksTab) ...[
            if (entries.isNotEmpty)
              ProfileTricksTable(
                entries: entries,
                onConsistencyChanged: widget.onConsistencyChanged,
              ),
          ],

          if (tab != myTricksTab) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.columnTrick, style: labelStyle)),
                  SizedBox(
                      width: 56,
                      child: Text(l10n.columnTier,
                          textAlign: TextAlign.right, style: labelStyle)),
                  if (tab == highValueTab)
                    SizedBox(
                        width: 72,
                        child: Text(l10n.columnUnlocks,
                            textAlign: TextAlign.right, style: labelStyle)),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tab == unlockedTab)
              _TrickRowList(
                tricks: whatsNext.unlocked
                    .map((t) => (trick: t, trailing: null))
                    .toList(),
                theme: theme,
              ),
            if (tab == partialTab)
              _TrickRowList(
                tricks: whatsNext.partiallyUnlocked
                    .map((t) => (trick: t, trailing: null))
                    .toList(),
                theme: theme,
              ),
            if (tab == highValueTab)
              _TrickRowList(
                tricks: whatsNext.highValue
                    .map((h) => (trick: h.trick, trailing: '${h.unlockCount}'))
                    .toList(),
                theme: theme,
                trailingColor: theme.colorScheme.tertiary,
              ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TrickRowList extends StatelessWidget {
  final List<({Trick trick, String? trailing})> tricks;
  final ThemeData theme;
  final Color? trailingColor;

  const _TrickRowList(
      {required this.tricks, required this.theme, this.trailingColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < tricks.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          InkWell(
            onTap: () => context.push('/trick/${tricks[i].trick.id}'),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tricks[i].trick.givenName,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(tricks[i].trick.difficultyLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  if (tricks[i].trailing != null)
                    SizedBox(
                      width: 72,
                      child: Text(tricks[i].trailing!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: trailingColor)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

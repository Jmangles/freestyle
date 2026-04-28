import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';
import '../utils/difficulty_tier.dart';

class TrickCard extends StatelessWidget {
  final Trick trick;
  final Consistency? consistency;
  final VoidCallback? onReturn;
  final bool listMode;
  final bool showDifficulty;
  final bool compact;
  final bool difficultyModifierOnly;

  const TrickCard({super.key, required this.trick, this.consistency, this.onReturn, this.listMode = false, this.showDifficulty = false, this.compact = false, this.difficultyModifierOnly = false});

  @override
  Widget build(BuildContext context) {
    if (listMode) return _buildListTile(context);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: consistency?.cardColor(theme.brightness),
      child: InkWell(
        onTap: () async {
          await context.push('/trick/${trick.id}');
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trick.givenName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!compact &&
                  trick.technicalName != null &&
                  trick.technicalName!.isNotEmpty &&
                  trick.technicalName != trick.givenName) ...[
                const SizedBox(height: 2),
                Text(
                  trick.technicalName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  if (trick.startPositionName != null ||
                      trick.endPositionName != null)
                    Expanded(
                      child: Text(
                        _positionText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (showDifficulty)
                    _DifficultyBadge(trick: trick, modifierOnly: difficultyModifierOnly),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = trick.technicalName != null &&
        trick.technicalName!.isNotEmpty &&
        trick.technicalName != trick.givenName;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      clipBehavior: Clip.antiAlias,
      color: consistency?.cardColor(theme.brightness),
      child: ListTile(
        dense: true,
        title: Text(
          trick.givenName,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: hasSubtitle
            ? Text(trick.technicalName!,
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))
            : null,
        trailing: _buildListTrailing(theme),
        onTap: () async {
          await context.push('/trick/${trick.id}');
          onReturn?.call();
        },
      ),
    );
  }

  Widget? _buildListTrailing(ThemeData theme) {
    final hasPosition = trick.startPositionName != null || trick.endPositionName != null;
    if (!hasPosition && !showDifficulty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasPosition)
          Text(
            _positionText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (hasPosition && showDifficulty) const SizedBox(width: 8),
        if (showDifficulty) _DifficultyBadge(trick: trick, modifierOnly: difficultyModifierOnly),
      ],
    );
  }

  String _positionText() {
    if (trick.startPositionName != null && trick.endPositionName != null) {
      return '${trick.startPositionName} → ${trick.endPositionName}';
    }
    if (trick.startPositionName != null) return trick.startPositionName!;
    return trick.endPositionName ?? '';
  }
}

class _DifficultyBadge extends StatelessWidget {
  final Trick trick;
  final bool modifierOnly;
  const _DifficultyBadge({required this.trick, this.modifierOnly = false});

  static (Color, Color)? _colorsForTier(int rawValue) =>
      DifficultyTier.badgeColors(rawValue);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = trick.difficultyTier;

    if (modifierOnly) {
      if (v == -1) return const SizedBox.shrink();
      final mod = (v - 1) % 3; // 0 = minus, 1 = base, 2 = plus
      if (mod == 1) return const SizedBox.shrink();
      final isMinus = mod == 0;
      return _badge(
        label: isMinus ? '−' : '+',
        bg: isMinus ? const Color(0xFF90CAF9) : const Color(0xFFFFB300),
        fg: Colors.black,
        theme: theme,
      );
    }

    final colors = _colorsForTier(v);
    return _badge(
      label: trick.difficultyLabel,
      bg: colors?.$1 ?? theme.colorScheme.secondaryContainer,
      fg: colors?.$2 ?? theme.colorScheme.onSecondaryContainer,
      theme: theme,
    );
  }

  Widget _badge({required String label, required Color bg, required Color fg, required ThemeData theme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

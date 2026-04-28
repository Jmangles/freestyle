import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';

class TrickCard extends StatelessWidget {
  final Trick trick;
  final Consistency? consistency;
  final VoidCallback? onReturn;
  final bool listMode;
  final bool showDifficulty;
  final bool compact;

  const TrickCard({super.key, required this.trick, this.consistency, this.onReturn, this.listMode = false, this.showDifficulty = false, this.compact = false});

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
                    _DifficultyBadge(trick: trick),
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
        if (hasPosition) const SizedBox(width: 8),
        _DifficultyBadge(trick: trick),
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
  const _DifficultyBadge({required this.trick});

  static (Color, Color)? _colorsForTier(int rawValue) {
    if (rawValue == -1) return null;
    return switch ((rawValue - 1) ~/ 3 + 1) {
      1  => (const Color(0xFF4CAF50), Colors.white),
      2  => (const Color(0xFF8BC34A), Colors.black),
      3  => (const Color(0xFFCDDC39), Colors.black),
      4  => (const Color(0xFFFFCA28), Colors.black),
      5  => (const Color(0xFFFFA726), Colors.black),
      6  => (const Color(0xFFFF7043), Colors.white),
      7  => (const Color(0xFFEF5350), Colors.white),
      8  => (const Color(0xFFE53935), Colors.white),
      9  => (const Color(0xFFC62828), Colors.white),
      10 => (const Color(0xFF7B0000), Colors.white),
      _  => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colorsForTier(trick.difficultyTier);
    final bgColor = colors?.$1 ?? theme.colorScheme.secondaryContainer;
    final fgColor = colors?.$2 ?? theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        trick.difficultyLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

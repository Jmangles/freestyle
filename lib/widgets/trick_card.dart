import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
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
  final bool editorMode;

  const TrickCard({
    super.key,
    required this.trick,
    this.consistency,
    this.onReturn,
    this.listMode = false,
    this.showDifficulty = false,
    this.compact = false,
    this.difficultyModifierOnly = false,
    this.editorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (listMode) return _buildListTile(context);
    final theme = Theme.of(context);

    final card = Card(
      clipBehavior: Clip.antiAlias,
      margin: consistency == Consistency.never ? EdgeInsets.zero : null,
      color: consistency?.cardColor(theme.brightness),
      elevation: consistency?.hasGlow == true ? 8 : null,
      shadowColor: consistency?.hasGlow == true
          ? consistency!.borderColor(theme.brightness).withValues(alpha: 0.7)
          : null,
      shape: _cardShape(theme),
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
              if (editorMode) ...[
                const SizedBox(height: 2),
                _EditorFieldsRow(trick: trick),
              ],
            ],
          ),
        ),
      ),
    );

    if (consistency == Consistency.never) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            card,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: consistency!.borderColor(theme.brightness),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return card;
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = trick.technicalName != null &&
        trick.technicalName!.isNotEmpty &&
        trick.technicalName != trick.givenName;

    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: consistency?.cardColor(theme.brightness),
      elevation: consistency?.hasGlow == true ? 8 : null,
      shadowColor: consistency?.hasGlow == true
          ? consistency!.borderColor(theme.brightness).withValues(alpha: 0.7)
          : null,
      shape: _cardShape(theme),
      child: ListTile(
        dense: true,
        title: Text(
          trick.givenName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: hasSubtitle
            ? Text(trick.technicalName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ))
            : null,
        trailing: _buildListTrailing(theme),
        onTap: () async {
          await context.push('/trick/${trick.id}');
          onReturn?.call();
        },
      ),
    );

    Widget result = card;
    if (consistency == Consistency.never) {
      result = Stack(
        children: [
          card,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: consistency!.borderColor(theme.brightness),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: result,
    );
  }

  ShapeBorder? _cardShape(ThemeData theme) {
    if (consistency == null || consistency == Consistency.never) return null;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: consistency!.borderColor(theme.brightness),
        width: consistency!.borderWidth,
      ),
    );
  }

  Widget? _buildListTrailing(ThemeData theme) {
    final hasPosition = trick.startPositionName != null || trick.endPositionName != null;
    if (!hasPosition && !showDifficulty && !editorMode) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editorMode) ...[
          _EditorFieldsRow(trick: trick),
          const SizedBox(width: 6),
        ],
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

    final colors = DifficultyTier.badgeColors(v);
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

class _EditorFieldsRow extends StatelessWidget {
  final Trick trick;
  const _EditorFieldsRow({required this.trick});

  List<(IconData, String)> _missingFields(AppLocalizations l10n) => [
        if (trick.description == null || trick.description!.trim().isEmpty)
          (Icons.description_outlined, l10n.descriptionLabel),
        if (trick.videoLink == null)
          (Icons.videocam_outlined, l10n.videoLabel),
        if (trick.prerequisiteTrickIds.isEmpty)
          (Icons.account_tree_outlined, l10n.prerequisitesLabel),
        if (trick.tips == null || trick.tips!.trim().isEmpty)
          (Icons.tips_and_updates_outlined, l10n.tipsLabel),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final missing = _missingFields(l10n);

    final String tooltipMessage;
    if (missing.isEmpty) {
      tooltipMessage = l10n.editorAllPresent;
    } else {
      final bullets = missing.map((f) => '  • ${f.$2}').join('\n');
      tooltipMessage = '${l10n.editorMissingPrefix}\n$bullets';
    }

    final indicator = missing.isEmpty
        ? Icon(Icons.check_circle_outline, size: 11, color: Colors.green.shade600)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (icon, _) in missing)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(icon, size: 11, color: Colors.amber.shade700),
                ),
            ],
          );

    return Tooltip(
      message: tooltipMessage,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      textStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      preferBelow: false,
      child: indicator,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dashLength = 6.0;
    const gapLength = 4.0;
    const radius = 12.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool drawing = true;
      while (distance < metric.length) {
        final segLen = drawing ? dashLength : gapLength;
        final end = (distance + segLen).clamp(0.0, metric.length);
        if (drawing) canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end;
        drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

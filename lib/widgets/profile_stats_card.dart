import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/screen_data.dart';
import '../utils/level_calculator.dart';

/// Displays the tier bar chart and level/XP progress for a user's trick list.
class ProfileStatsCard extends StatelessWidget {
  final List<UserTrickEntry> entries;

  const ProfileStatsCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final totalPoints = computeTotalPoints(entries);

    final counts = <int, int>{};
    final tierConsistencies = <int, List<int>>{};
    for (final entry in entries) {
      final tier = entry.trick?.difficultyLogicalTier ?? -1;
      if (tier < 1) continue;
      counts[tier] = (counts[tier] ?? 0) + 1;
      tierConsistencies
          .putIfAbsent(tier, () => [])
          .add(entry.userTrick.consistency.index);
    }

    if (counts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          if (isWide) {
            final levelWidth = (constraints.maxWidth * 0.45).clamp(350.0, 650.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: levelWidth,
                  child: _LevelProgress(totalPoints: totalPoints, asColumn: true),
                ),
                const SizedBox(width: 16),
                Container(
                    width: 1,
                    height: 80,
                    color: Theme.of(context).dividerColor),
                const SizedBox(width: 16),
                Expanded(
                  child: _TierBarChart(
                      counts: counts, tierConsistencies: tierConsistencies),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierBarChart(counts: counts, tierConsistencies: tierConsistencies),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _LevelProgress(totalPoints: totalPoints, asNarrowRow: true),
            ],
          );
        },
      ),
    );
  }
}

class _TierBarChart extends StatelessWidget {
  final Map<int, int> counts;
  final Map<int, List<int>> tierConsistencies;

  const _TierBarChart({required this.counts, required this.tierConsistencies});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final tiers = counts.keys.toList()..sort();
    const barAreaHeight = 64.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.tricksByTierTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.coloredByConsistency,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tiers.map((tier) {
            final count = counts[tier]!;
            final fraction = count / maxCount;
            final median = computeMedian(tierConsistencies[tier]!);
            final barColor = interpolateConsistencyColor(median, brightness);
            final barHeight =
                (barAreaHeight * fraction).clamp(3.0, barAreaHeight);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: barAreaHeight + 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const Spacer(),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tier',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LevelProgress extends StatelessWidget {
  final num totalPoints;
  final bool asColumn;
  final bool asNarrowRow;

  const _LevelProgress({
    required this.totalPoints,
    this.asColumn = false,
    this.asNarrowRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = computeLevel(totalPoints);
    final currentLevelXp = xpRequiredForLevel(level);
    final nextLevelXp = xpRequiredForLevel(level + 1);
    final progress =
        ((totalPoints - currentLevelXp) / (nextLevelXp - currentLevelXp))
            .clamp(0.0, 1.0);
    final ptsToNext = (nextLevelXp - totalPoints).ceil();

    final levelLabel = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Level',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$level',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: levelColor(level),
          ),
        ),
      ],
    );

    final pointsLabel = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          totalPoints.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.pointScoreLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    final progressBar = Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 24,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(levelColor(level)),
          ),
        ),
        Stack(
          children: [
            Text(
              context.l10n.ptsToNextLevel(ptsToNext, level + 1),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = theme.colorScheme.surface,
              ),
            ),
            Text(
              context.l10n.ptsToNextLevel(ptsToNext, level + 1),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.inverseSurface,
              ),
            ),
          ],
        ),
      ],
    );

    if (asNarrowRow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [levelLabel, pointsLabel],
          ),
          const SizedBox(height: 8),
          progressBar,
        ],
      );
    }

    if (asColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          levelLabel,
          const SizedBox(height: 8),
          progressBar,
          const SizedBox(height: 8),
          pointsLabel,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        levelLabel,
        const SizedBox(width: 24),
        Expanded(child: progressBar),
        const SizedBox(width: 24),
        pointsLabel,
      ],
    );
  }
}

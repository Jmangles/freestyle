import 'dart:math' as math;
import 'package:flutter/material.dart';

class VoteEntry {
  final String label;
  final int count;
  final Color? color;

  const VoteEntry({required this.label, required this.count, this.color});
}

/// Pie chart + legend for community vote breakdowns (difficulty, leash position).
class VotePieChart extends StatelessWidget {
  final List<VoteEntry> entries;

  const VotePieChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);
    final colors =
        entries.map((e) => e.color ?? theme.colorScheme.primary).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: VotePieChartPainter(
                entries: entries,
                colors: colors,
                total: total,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...entries.asMap().entries.map((e) {
          final entry = e.value;
          final color = colors[e.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${entry.label} (${entry.count})',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class VotePieChartPainter extends CustomPainter {
  final List<VoteEntry> entries;
  final List<Color> colors;
  final int total;

  const VotePieChartPainter({
    required this.entries,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final sweep = 2 * math.pi * entries[i].count / total;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..color = colors[i].withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(VotePieChartPainter old) =>
      entries != old.entries || total != old.total;
}

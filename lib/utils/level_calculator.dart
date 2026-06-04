import 'dart:math';
import 'package:flutter/material.dart';
import '../models/screen_data.dart';
import '../models/user_trick.dart';

Color levelColor(int level) => switch (level) {
      0 => const Color(0xFF9E9E9E),
      <= 3 => const Color(0xFF4CAF50),
      <= 6 => const Color(0xFF8BC34A),
      <= 10 => const Color(0xFFFFCA28),
      <= 15 => const Color(0xFFFFA726),
      <= 20 => const Color(0xFFFF7043),
      <= 30 => const Color(0xFFEF5350),
      _ => const Color(0xFF7B0000),
    };

double xpRequiredForLevel(int level) {
  if (level <= 0) return 0;
  return 12 * pow(level, 1.4).toDouble();
}

int computeLevel(num totalPoints) {
  int level = 0;
  while (xpRequiredForLevel(level + 1) <= totalPoints) {
    level++;
  }
  return level;
}

num getPointScoreByDifficulty(int rawDifficulty) {
  if (rawDifficulty < 0) return 0;
  const tierModifier = 0.1;
  final modifier = rawDifficulty % 3 - 1;
  final tier = rawDifficulty ~/ 3 + tierModifier * modifier;
  return pow(1.5, tier - 1);
}

num computeTotalPoints(List<UserTrickEntry> entries) {
  return entries
      .where((e) => e.userTrick.consistency.isLanded)
      .fold(0, (sum, e) => sum + getPointScoreByDifficulty(e.trick!.difficultyTier));
}

double computeMedian(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  final n = sorted.length;
  return n.isOdd
      ? sorted[n ~/ 2].toDouble()
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
}

Color interpolateConsistencyColor(double value, Brightness brightness) {
  final colors = Consistency.values.map((c) => c.borderColor(brightness)).toList();
  final lower = value.floor().clamp(0, colors.length - 2);
  final t = (value - lower).clamp(0.0, 1.0);
  return Color.lerp(colors[lower], colors[lower + 1], t)!;
}

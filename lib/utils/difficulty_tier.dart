import 'package:flutter/material.dart';

class DifficultyTier {
  DifficultyTier._();

  // Maps a raw difficulty value (1–30) to a display label like "1-", "1", "1+".
  // Every 3 consecutive values map to one logical tier: 1–3 → Tier 1, 4–6 → Tier 2, etc.
  static String label(int value) {
    if (value == -1) return 'TBD';
    final tier = logicalTier(value);
    const suffixes = ['-', '', '+'];
    return '$tier${suffixes[(value - 1) % 3]}';
  }

  // Returns the integer tier number (1–10) for a raw value, or -1 for TBD.
  static int logicalTier(int value) {
    if (value == -1) return -1;
    return (value - 1) ~/ 3 + 1;
  }

  // Returns (backgroundColor, foregroundColor) for a difficulty badge, or null for TBD.
  static (Color, Color)? badgeColors(int rawValue) {
    if (rawValue == -1) return null;
    return switch (logicalTier(rawValue)) {
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
}

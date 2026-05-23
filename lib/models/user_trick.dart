import 'package:flutter/material.dart';

enum Consistency {
  never('Attempting'),
  once('Once'),
  sometimes('Sometimes'),
  often('Often'),
  generally('Generally'),
  always('Always');

  const Consistency(this.label);
  final String label;

  bool get isLanded => this != Consistency.never;

  double get borderWidth => switch (this) {
    Consistency.never => 1.5,
    Consistency.once => 1.5,
    Consistency.sometimes => 2.0,
    Consistency.often => 2.0,
    Consistency.generally => 2.0,
    Consistency.always => 2.0,
  };

  bool get hasGlow => this == Consistency.always;

  Color borderColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        Consistency.never =>   const Color(0xFF9E9E9E),   // gray
        Consistency.once =>    const Color(0xFFFF7043),   // deep-orange-400
        Consistency.sometimes => const Color(0xFFFFD54F), // amber-300
        Consistency.often =>   const Color(0xFF8BC34A),   // light-green-500
        Consistency.generally => const Color(0xFF4DB6AC), // teal-300
        Consistency.always =>  const Color(0xFF64B5F6),   // blue-300
      };
    }
    return switch (this) {
      Consistency.never =>   const Color(0xFF9E9E9E),   // gray
      Consistency.once =>    const Color(0xFFE65100),   // orange
      Consistency.sometimes => const Color(0xFFF9A825), // yellow/amber
      Consistency.often =>   const Color(0xFF558B2F),   // green
      Consistency.generally => const Color(0xFF00796B), // teal
      Consistency.always =>  const Color(0xFF1565C0),   // blue
    };
  }

  Color cardColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        Consistency.never =>   const Color(0xFF1C1C1C),   // dark gray
        Consistency.once =>    const Color(0xFF221508),   // dark orange tint
        Consistency.sometimes => const Color(0xFF22200A), // dark yellow tint
        Consistency.often =>   const Color(0xFF131E08),   // dark green tint
        Consistency.generally => const Color(0xFF08201E), // dark teal tint
        Consistency.always =>  const Color(0xFF081626),   // dark blue tint
      };
    }
    return switch (this) {
      Consistency.never =>   const Color(0xFFEEEEEE),   // light gray
      Consistency.once =>    const Color(0xFFFFF3E0),   // light orange
      Consistency.sometimes => const Color(0xFFFFFDE7), // light yellow
      Consistency.often =>   const Color(0xFFF1F8E9),   // light green
      Consistency.generally => const Color(0xFFE0F2F1), // light teal
      Consistency.always =>  const Color(0xFFE3F2FD),   // light blue
    };
  }

  // Returns null in light mode (use theme default) or when no override is needed.
  Color? textColor(Brightness brightness) {
    if (brightness == Brightness.light) return null;
    return switch (this) {
      Consistency.never =>   null,
      Consistency.once =>    const Color(0xFF94A3B8), // slate-400
      Consistency.sometimes => const Color(0xFF94A3B8), // slate-400
      Consistency.often =>   const Color(0xFFE2E8F0), // slate-200
      Consistency.generally => const Color(0xFFFFFFFF),
      Consistency.always =>  const Color(0xFFFFFFFF),
    };
  }

  static Consistency fromString(String value) => Consistency.values.firstWhere(
        (e) => e.name == value,
        orElse: () => Consistency.never,
      );
}

enum LeashPosition {
  frontside('Frontside'),
  backside('Backside'),
  center('Center');

  const LeashPosition(this.label);
  final String label;
}

class UserTrick {
  final int id;
  final int userId;
  final int trickId;
  final Consistency consistency;
  final int? difficultyVote;
  final LeashPosition? leashPosition;
  final String? videoLink;
  final int? videoStart;
  final int? videoEnd;

  const UserTrick({
    required this.id,
    required this.userId,
    required this.trickId,
    required this.consistency,
    this.difficultyVote,
    this.leashPosition,
    this.videoLink,
    this.videoStart,
    this.videoEnd,
  });

  factory UserTrick.fromJson(Map<String, dynamic> json) => UserTrick(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        trickId: json['trick_id'] as int,
        consistency: Consistency.values[json['consistency'] as int],
        difficultyVote: json['difficulty_vote'] as int?,
        leashPosition: json['leash_position'] != null
            ? LeashPosition.values[json['leash_position'] as int]
            : null,
        videoLink: json['video_link'] as String?,
        videoStart: json['video_start'] as int?,
        videoEnd: json['video_end'] as int?,
      );
}

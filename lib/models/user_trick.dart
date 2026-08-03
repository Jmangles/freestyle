import 'package:flutter/material.dart';

enum Consistency {
  // Stored in the DB as the enum index (0..7). Changing the order or adding
  // values anywhere but the end requires a server + local-cache migration —
  // see supabase/migrations/20260803120000_consistency_rarely.sql.
  neverTried('Never tried'),
  attempting('Attempting'),
  once('Once'),
  rarely('Rarely'),
  sometimes('Sometimes'),
  often('Often'),
  generally('Generally'),
  always('Always');

  const Consistency(this.label);
  final String label;

  bool get isLanded => index >= Consistency.once.index;

  double get borderWidth => switch (this) {
    Consistency.neverTried => 1.5,
    Consistency.attempting => 1.5,
    Consistency.once => 1.5,
    Consistency.rarely => 1.5,
    Consistency.sometimes => 2.0,
    Consistency.often => 2.0,
    Consistency.generally => 2.0,
    Consistency.always => 2.0,
  };

  bool get hasGlow => this == Consistency.always;

  Color borderColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        Consistency.neverTried => const Color(0xFF757575), // grey-600
        Consistency.attempting =>   const Color(0xFF9E9E9E),   // gray
        Consistency.once =>    const Color(0xFFEF5350),   // red-400
        Consistency.rarely =>  const Color(0xFFFF9800),   // orange-500
        Consistency.sometimes => const Color(0xFFFFEB3B), // yellow-500
        Consistency.often =>   const Color(0xFF8BC34A),   // light-green-500
        Consistency.generally => const Color(0xFF4DB6AC), // teal-300
        Consistency.always =>  const Color(0xFF64B5F6),   // blue-300
      };
    }
    return switch (this) {
      Consistency.neverTried => const Color(0xFFBDBDBD), // grey-400
      Consistency.attempting =>   const Color(0xFF9E9E9E),   // gray
      Consistency.once =>    const Color(0xFFC62828),   // red-800
      Consistency.rarely =>  const Color(0xFFEF6C00),   // orange-800
      Consistency.sometimes => const Color(0xFFF9A825), // yellow/amber
      Consistency.often =>   const Color(0xFF558B2F),   // green
      Consistency.generally => const Color(0xFF00796B), // teal
      Consistency.always =>  const Color(0xFF1565C0),   // blue
    };
  }

  // Null means no override: the card keeps the theme's default surface color.
  Color? cardColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        Consistency.neverTried => null,
        Consistency.attempting =>   const Color(0xFF1C1C1C),   // dark gray
        Consistency.once =>    const Color(0xFF1F1718),   // subtle red tint
        Consistency.rarely =>  const Color(0xFF201A14),   // subtle orange tint
        Consistency.sometimes => const Color(0xFF1F1E15), // subtle yellow tint
        Consistency.often =>   const Color(0xFF191D16),   // subtle green tint
        Consistency.generally => const Color(0xFF161D1D), // subtle teal tint
        Consistency.always =>  const Color(0xFF161A1F),   // subtle blue tint
      };
    }
    return switch (this) {
      Consistency.neverTried => null,
      Consistency.attempting =>   const Color(0xFFEEEEEE),   // light gray
      Consistency.once =>    const Color(0xFFFFEBEE),   // light red
      Consistency.rarely =>  const Color(0xFFFFF0DC),   // light orange
      Consistency.sometimes => const Color(0xFFFDFBD4), // light yellow
      Consistency.often =>   const Color(0xFFF1F8E9),   // light green
      Consistency.generally => const Color(0xFFE0F2F1), // light teal
      Consistency.always =>  const Color(0xFFE3F2FD),   // light blue
    };
  }

  // Returns null in light mode (use theme default) or when no override is needed.
  Color? textColor(Brightness brightness) {
    if (brightness == Brightness.light) return null;
    return switch (this) {
      Consistency.neverTried => null,
      Consistency.attempting =>   null,
      Consistency.once =>    const Color(0xFF94A3B8), // slate-400
      Consistency.rarely =>  const Color(0xFF94A3B8), // slate-400
      Consistency.sometimes => const Color(0xFF94A3B8), // slate-400
      Consistency.often =>   const Color(0xFFE2E8F0), // slate-200
      Consistency.generally => const Color(0xFFFFFFFF),
      Consistency.always =>  const Color(0xFFFFFFFF),
    };
  }
}

// Absence of a user_tricks row means the trick was never tried; these helpers
// make that rule total so callers never handle a nullable Consistency.
extension ConsistencyMapLookup on Map<int, Consistency> {
  Consistency forTrick(int trickId) => this[trickId] ?? Consistency.neverTried;
}

extension UserTrickConsistency on UserTrick? {
  Consistency get effectiveConsistency =>
      this?.consistency ?? Consistency.neverTried;
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
  final DateTime updatedAt;

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
    required this.updatedAt,
  });

  UserTrick withConsistency(Consistency c) => UserTrick(
        id: id,
        userId: userId,
        trickId: trickId,
        consistency: c,
        difficultyVote: difficultyVote,
        leashPosition: leashPosition,
        videoLink: videoLink,
        videoStart: videoStart,
        videoEnd: videoEnd,
        updatedAt: updatedAt,
      );

  factory UserTrick.fromJson(Map<String, dynamic> json) => UserTrick(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        trickId: json['trick_id'] as int,
        consistency: Consistency.values
                .elementAtOrNull(json['consistency'] as int) ??
            Consistency.neverTried,
        difficultyVote: json['difficulty_vote'] as int?,
        leashPosition: json['leash_position'] != null
            ? LeashPosition.values.elementAtOrNull(
                json['leash_position'] as int)
            : null,
        videoLink: json['video_link'] as String?,
        videoStart: json['video_start'] as int?,
        videoEnd: json['video_end'] as int?,
        // Epoch signals "no prior server write" to conflict resolution: a real
        // server timestamp will always be after epoch, so the server row wins.
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

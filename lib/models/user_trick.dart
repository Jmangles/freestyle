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

  Color cardColor(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return switch (this) {
        Consistency.never => const Color(0xFF0D2744),
        Consistency.once => const Color(0xFF332D00),
        Consistency.sometimes => const Color(0xFF331F00),
        Consistency.often => const Color(0xFF1A2D10),
        Consistency.generally => const Color(0xFF123B12),
        Consistency.always => const Color(0xFF0A3D1A),
      };
    }
    return switch (this) {
      Consistency.never => const Color(0xFFE3F2FD),
      Consistency.once => const Color(0xFFFFF9C4),
      Consistency.sometimes => const Color(0xFFFFECB3),
      Consistency.often => const Color(0xFFDCEDC8),
      Consistency.generally => const Color(0xFFC8E6C9),
      Consistency.always => const Color(0xFFA5D6A7),
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

  const UserTrick({
    required this.id,
    required this.userId,
    required this.trickId,
    required this.consistency,
    this.difficultyVote,
    this.leashPosition,
    this.videoLink,
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
      );
}

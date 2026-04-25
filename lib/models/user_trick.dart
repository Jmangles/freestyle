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

  Color get cardColor => switch (this) {
    Consistency.never => const Color(0xFFE3F2FD),
    Consistency.once => const Color(0xFFFFF9C4),
    Consistency.sometimes => const Color(0xFFFFECB3),
    Consistency.often => const Color(0xFFDCEDC8),
    Consistency.generally => const Color(0xFFC8E6C9),
    Consistency.always => const Color(0xFFA5D6A7),
  };

  static Consistency fromString(String value) => Consistency.values.firstWhere(
        (e) => e.name == value,
        orElse: () => Consistency.never,
      );
}

class UserTrick {
  final int id;
  final String userId;
  final int trickId;
  final Consistency consistency;

  const UserTrick({
    required this.id,
    required this.userId,
    required this.trickId,
    required this.consistency,
  });

  factory UserTrick.fromJson(Map<String, dynamic> json) => UserTrick(
        id: json['id'] as int,
        userId: json['user_id'] as String,
        trickId: json['trick_id'] as int,
        consistency: Consistency.values[json['consistency'] as int],
      );
}

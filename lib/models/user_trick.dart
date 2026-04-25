enum Consistency {
  never('Never'),
  once('Once'),
  sometimes('Sometimes'),
  often('Often'),
  generally('Generally'),
  always('Always');

  const Consistency(this.label);
  final String label;

  static Consistency fromString(String value) => Consistency.values.firstWhere(
        (e) => e.name == value,
        orElse: () => Consistency.never,
      );
}

class UserTrick {
  final String id;
  final String userId;
  final String trickId;
  final Consistency consistency;

  const UserTrick({
    required this.id,
    required this.userId,
    required this.trickId,
    required this.consistency,
  });

  factory UserTrick.fromJson(Map<String, dynamic> json) => UserTrick(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        trickId: json['trick_id'] as String,
        consistency: Consistency.fromString(json['consistency'] as String),
      );
}

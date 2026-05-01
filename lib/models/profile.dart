class Profile {
  final String id;
  final int intId;
  final String? username;
  final int flags;

  bool get canEditTricks => (flags & 1) != 0;

  const Profile({required this.id, required this.intId, this.username, required this.flags});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        intId: json['int_id'] as int,
        username: json['username'] as String?,
        flags: json['flags'] as int? ?? 0,
      );
}

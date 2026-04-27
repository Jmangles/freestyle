class Profile {
  final String id;
  final int intId;
  final String? username;
  final bool isAdmin;

  const Profile({required this.id, required this.intId, this.username, required this.isAdmin});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        intId: json['int_id'] as int,
        username: json['username'] as String?,
        isAdmin: json['is_admin'] as bool? ?? false,
      );
}

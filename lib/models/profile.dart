class Profile {
  final String id;
  final String? username;
  final bool isAdmin;

  const Profile({required this.id, this.username, required this.isAdmin});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String?,
        isAdmin: json['is_admin'] as bool? ?? false,
      );
}

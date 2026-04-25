class Position {
  final String id;
  final String name;

  const Position({required this.id, required this.name});

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

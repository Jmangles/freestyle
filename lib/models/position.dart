class Position {
  final int id;
  final String name;

  const Position({required this.id, required this.name});

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

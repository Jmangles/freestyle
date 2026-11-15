enum ListSortMode {
  custom,
  difficulty,
  checked,
  dateAdded;

  // Stored in the DB as the enum index; append new values at the end only.
  static ListSortMode fromIndex(int? i) =>
      ListSortMode.values.elementAtOrNull(i ?? 0) ?? ListSortMode.custom;
}

class TrickList {
  final int id;
  final String name;
  final ListSortMode sortMode;
  final bool sortDescending;
  final int itemCount;
  final Set<int> trickIds;

  const TrickList({
    required this.id,
    required this.name,
    required this.sortMode,
    required this.sortDescending,
    this.itemCount = 0,
    this.trickIds = const {},
  });

  factory TrickList.fromJson(Map<String, dynamic> json) {
    final items = (json['trick_list_items'] as List?) ?? const [];
    return TrickList(
      id: json['id'] as int,
      name: json['name'] as String,
      sortMode: ListSortMode.fromIndex(json['sort_mode'] as int?),
      sortDescending: json['sort_descending'] as bool? ?? false,
      itemCount: items.length,
      trickIds: {for (final i in items) (i as Map)['trick_id'] as int},
    );
  }
}

class TrickListItem {
  final int id;
  final int listId;
  final int trickId;
  final bool checked;
  final int position;
  final DateTime addedAt;

  const TrickListItem({
    required this.id,
    required this.listId,
    required this.trickId,
    required this.checked,
    required this.position,
    required this.addedAt,
  });

  TrickListItem copyWith({bool? checked, int? position}) => TrickListItem(
        id: id,
        listId: listId,
        trickId: trickId,
        checked: checked ?? this.checked,
        position: position ?? this.position,
        addedAt: addedAt,
      );

  factory TrickListItem.fromJson(Map<String, dynamic> json) => TrickListItem(
        id: json['id'] as int,
        listId: json['list_id'] as int,
        trickId: json['trick_id'] as int,
        checked: json['checked'] as bool? ?? false,
        position: json['position'] as int? ?? 0,
        addedAt: DateTime.parse(json['added_at'] as String),
      );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick.dart';
import '../models/trick_list.dart';
import '../models/user_trick.dart';
import '../services/trick_lists_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../utils/safe_state.dart';
import '../widgets/add_to_list_dialog.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/nice_dialog.dart';

class TrickListScreen extends StatefulWidget {
  final int listId;
  const TrickListScreen({super.key, required this.listId});

  @override
  State<TrickListScreen> createState() => _TrickListScreenState();
}

class _TrickListScreenState extends State<TrickListScreen> with SafeStateMixin {
  TrickList? _list;
  // Always kept in custom (position) order; display order is derived.
  List<TrickListItem> _items = [];
  Map<int, Trick> _tricks = {};
  Map<int, UserTrick> _userTricks = {};
  ListSortMode _sortMode = ListSortMode.custom;
  bool _descending = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await TrickListsService.getLists();
      final list = lists.where((l) => l.id == widget.listId).firstOrNull;
      if (list == null) {
        if (mounted) context.pop();
        return;
      }
      final items = await TrickListsService.getItems(widget.listId);
      final ids = items.map((i) => i.trickId).toList();
      final (tricks, userTricks) = await (
        TricksService.getTricksByIds(ids),
        UserTricksService.getUserTricksForTrickIds(ids),
      ).wait;
      safeSetState(() {
        _list = list;
        _items = items;
        _tricks = {for (final t in tricks) t.id: t};
        _userTricks = userTricks;
        if (_loading) {
          _sortMode = list.sortMode;
          _descending = list.sortDescending;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      safeSetState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Consistency _consistencyOf(int trickId) =>
      _userTricks[trickId].effectiveConsistency;

  List<TrickListItem> get _displayed {
    if (_sortMode == ListSortMode.custom) return _items;
    final items = [..._items];
    int byName(TrickListItem a, TrickListItem b) =>
        (_tricks[a.trickId]?.givenName ?? '')
            .toLowerCase()
            .compareTo((_tricks[b.trickId]?.givenName ?? '').toLowerCase());
    items.sort((a, b) {
      switch (_sortMode) {
        case ListSortMode.difficulty:
          final ta = _tricks[a.trickId]?.difficultyTier ?? -1;
          final tb = _tricks[b.trickId]?.difficultyTier ?? -1;
          // Unknown difficulty (-1) always sorts after known tiers.
          if (ta != tb) {
            if (ta == -1) return 1;
            if (tb == -1) return -1;
            return ta.compareTo(tb);
          }
          return byName(a, b);
        case ListSortMode.checked:
          if (a.checked != b.checked) return a.checked ? 1 : -1;
          return a.position.compareTo(b.position);
        case ListSortMode.dateAdded:
          final c = a.addedAt.compareTo(b.addedAt);
          return c != 0 ? c : a.position.compareTo(b.position);
        case ListSortMode.custom:
          return a.position.compareTo(b.position);
      }
    });
    return _descending ? items.reversed.toList() : items;
  }

  Future<void> _setSort(ListSortMode mode, bool descending) async {
    final l10n = context.l10n;
    setState(() {
      _sortMode = mode;
      _descending = descending;
    });
    try {
      await TrickListsService.setSort(widget.listId, mode, descending);
    } catch (e) {
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  Future<void> _toggleChecked(TrickListItem item, bool value) async {
    final l10n = context.l10n;
    if (value) {
      final current = _consistencyOf(item.trickId);
      if (!current.isLanded) {
        final chosen = await showNiceDialog(context);
        if (chosen == null || !mounted) return;
        try {
          await UserTricksService.setConsistency(item.trickId, chosen);
        } catch (e) {
          showErrorSnackBar(l10n.errorWithDetail('$e'));
          return;
        }
        final existing = _userTricks[item.trickId];
        setState(() {
          _userTricks = {
            ..._userTricks,
            item.trickId: existing?.withConsistency(chosen) ??
                UserTrick(
                  id: -1,
                  userId: -1,
                  trickId: item.trickId,
                  consistency: chosen,
                  updatedAt: DateTime.now(),
                ),
          };
        });
      }
    }
    _replaceItem(item.copyWith(checked: value));
    try {
      await TrickListsService.setChecked(item.id, value);
    } catch (e) {
      _replaceItem(item);
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  void _replaceItem(TrickListItem updated) {
    safeSetState(() {
      _items = [for (final i in _items) i.id == updated.id ? updated : i];
    });
  }

  Future<void> _removeItem(TrickListItem item) async {
    final l10n = context.l10n;
    final trick = _tricks[item.trickId];
    final ok = await AppDialogs.confirm(
      context,
      title: l10n.removeFromListTitle,
      content:
          l10n.removeFromListConfirm(trick?.givenName ?? '', _list?.name ?? ''),
      confirmLabel: l10n.yesButton,
      cancelLabel: l10n.noButton,
    );
    if (ok != true || !mounted) return;
    try {
      await TrickListsService.removeTrick(widget.listId, item.trickId);
      safeSetState(
          () => _items = _items.where((i) => i.id != item.id).toList());
    } catch (e) {
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final l10n = context.l10n;
    final items = [..._items];
    items.insert(newIndex, items.removeAt(oldIndex));
    setState(() => _items = [
          for (var i = 0; i < items.length; i++) items[i].copyWith(position: i)
        ]);
    try {
      await TrickListsService.saveCustomOrder(_items);
    } catch (e) {
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  Future<void> _rename() async {
    final l10n = context.l10n;
    final name = await promptListName(context,
        initial: _list?.name,
        title: l10n.renameListTitle,
        confirmLabel: l10n.saveButton);
    if (name == null || name == _list?.name || !mounted) return;
    try {
      await TrickListsService.renameList(widget.listId, name);
      await _load();
    } catch (e) {
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await AppDialogs.confirmDestructive(
      context,
      title: l10n.deleteListTitle,
      content: l10n.deleteListConfirm(_list?.name ?? ''),
      confirmLabel: l10n.deleteButton,
      cancelLabel: l10n.cancelButton,
    );
    if (ok != true || !mounted) return;
    try {
      await TrickListsService.deleteList(widget.listId);
      if (mounted) context.pop();
    } catch (e) {
      showErrorSnackBar(l10n.errorWithDetail('$e'));
    }
  }

  String _sortLabel(ListSortMode m) {
    final l10n = context.l10n;
    return switch (m) {
      ListSortMode.custom => l10n.sortCustom,
      ListSortMode.difficulty => l10n.sortDifficulty,
      ListSortMode.checked => l10n.sortChecked,
      ListSortMode.dateAdded => l10n.sortDateAdded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_list?.name ?? ''),
        actions: [
          if (_list != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.renameListTitle,
              onPressed: _rename,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteListTitle,
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(l10n.errorWithDetail('$_error')));
    }
    final custom = _sortMode == ListSortMode.custom;
    final displayed = _displayed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final m in ListSortMode.values)
                        ChoiceChip(
                          label: Text(_sortLabel(m)),
                          selected: _sortMode == m,
                          onSelected: (_) => _setSort(m, _descending),
                        ),
                    ],
                  ),
                ),
              ),
              if (!custom)
                IconButton(
                  tooltip: l10n.sortReverseTooltip,
                  isSelected: _descending,
                  icon: const Icon(Icons.swap_vert),
                  onPressed: () => _setSort(_sortMode, !_descending),
                ),
            ],
          ),
        ),
        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.listEmptyMessage,
                        textAlign: TextAlign.center),
                  ),
                )
              : custom
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.all(12),
                      buildDefaultDragHandles: false,
                      itemCount: displayed.length,
                      onReorderItem: _reorder,
                      itemBuilder: (_, i) => _row(displayed[i], i, true),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayed.length,
                      itemBuilder: (_, i) => _row(displayed[i], i, false),
                    ),
        ),
      ],
    );
  }

  Widget _row(TrickListItem item, int index, bool draggable) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final trick = _tricks[item.trickId];
    final consistency = _consistencyOf(item.trickId);
    final textColor = consistency.textColor(theme.brightness);
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: textColor,
      decoration: item.checked ? TextDecoration.lineThrough : null,
    );

    return Card(
      key: ValueKey(item.id),
      color: consistency.cardColor(theme.brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: consistency.borderColor(theme.brightness),
          width: consistency.borderWidth,
        ),
      ),
      child: ListTile(
        onTap: () async {
          await context.push('/trick/${item.trickId}');
          if (mounted) _load();
        },
        leading: Checkbox(
          value: item.checked,
          onChanged: (v) => _toggleChecked(item, v ?? false),
        ),
        title: Text(trick?.givenName ?? '…', style: nameStyle),
        subtitle: trick == null
            ? null
            : Text(trick.difficultyLabel,
                style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.removeFromListTooltip,
              onPressed: () => _removeItem(item),
            ),
            if (draggable)
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

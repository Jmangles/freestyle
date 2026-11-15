import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick.dart';
import '../models/trick_list.dart';
import '../services/trick_lists_service.dart';
import 'app_dialogs.dart';

/// Popup listing all of the user's lists with a checkbox that is ticked when
/// [trick] is already in the list. Ticking adds, unticking removes (after a
/// confirmation). Also offers creating a new list that contains the trick.
Future<void> showAddToListDialog(BuildContext context, Trick trick) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AddToListDialog(trick: trick),
  );
}

/// Asks for a list name; returns the trimmed name or null if cancelled.
Future<String?> promptListName(BuildContext context,
    {String? initial, required String title, required String confirmLabel}) {
  final l10n = context.l10n;
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: l10n.listNameLabel),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancelButton),
        ),
        TextButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

class _AddToListDialog extends StatefulWidget {
  final Trick trick;
  const _AddToListDialog({required this.trick});

  @override
  State<_AddToListDialog> createState() => _AddToListDialogState();
}

class _AddToListDialogState extends State<_AddToListDialog> {
  List<TrickList>? _lists;
  Object? _error;
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await TrickListsService.getLists();
      if (mounted) setState(() => _lists = lists);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithDetail('$e'))));
  }

  Future<void> _toggle(TrickList list, bool value) async {
    final l10n = context.l10n;
    if (_busy.contains(list.id)) return;
    if (!value) {
      final ok = await AppDialogs.confirm(
        context,
        title: l10n.removeFromListTitle,
        content: l10n.removeFromListConfirm(widget.trick.givenName, list.name),
        confirmLabel: l10n.yesButton,
        cancelLabel: l10n.noButton,
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy.add(list.id));
    try {
      if (value) {
        await TrickListsService.addTrick(list.id, widget.trick.id);
      } else {
        await TrickListsService.removeTrick(list.id, widget.trick.id);
      }
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(list.id));
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptListName(context,
        title: l10n.newListButton, confirmLabel: l10n.createButton);
    if (name == null || !mounted) return;
    try {
      await TrickListsService.createList(name, trickId: widget.trick.id);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lists = _lists;
    Widget body;
    if (_error != null) {
      body = Text(l10n.errorWithDetail('$_error'));
    } else if (lists == null) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lists.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.noListsYet),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final list in lists)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(list.name),
                      value: list.trickIds.contains(widget.trick.id),
                      onChanged: _busy.contains(list.id)
                          ? null
                          : (v) => _toggle(list, v ?? false),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: Text(l10n.newListButton),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.addToListTitle),
      content: SizedBox(width: 400, child: body),
      actions: [
        TextButton(
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.pop(context);
            router.push('/profile');
          },
          child: Text(l10n.toListsButton),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.closeButton),
        ),
      ],
    );
  }
}

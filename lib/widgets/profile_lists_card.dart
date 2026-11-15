import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick_list.dart';
import '../services/trick_lists_service.dart';
import 'add_to_list_dialog.dart';

/// "My lists" card for the profile screen: shows the user's lists and lets
/// them create a new one.
class ProfileListsCard extends StatefulWidget {
  const ProfileListsCard({super.key});

  @override
  State<ProfileListsCard> createState() => _ProfileListsCardState();
}

class _ProfileListsCardState extends State<ProfileListsCard> {
  late Future<List<TrickList>> _future = TrickListsService.getLists();

  void _reload() => setState(() => _future = TrickListsService.getLists());

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptListName(context,
        title: l10n.newListButton, confirmLabel: l10n.createButton);
    if (name == null || !mounted) return;
    try {
      final list = await TrickListsService.createList(name);
      if (!mounted) return;
      _reload();
      await context.push('/lists/${list.id}');
      if (mounted) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.errorWithDetail('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.myListsTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.newListButton,
                    onPressed: _create,
                  ),
                ],
              ),
            ),
            FutureBuilder<List<TrickList>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l10n.errorWithDetail('${snap.error}')),
                  );
                }
                final lists = snap.data!;
                if (lists.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(l10n.noListsYet),
                  );
                }
                return Column(
                  children: [
                    for (final list in lists)
                      ListTile(
                        leading: const Icon(Icons.list_alt_outlined),
                        title: Text(list.name),
                        subtitle: Text(l10n.listTrickCount(list.itemCount)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await context.push('/lists/${list.id}');
                          if (mounted) _reload();
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

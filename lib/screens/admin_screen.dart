import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/approval_status.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/trick_suggestion.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../utils/date_formatters.dart';
import 'submit_trick_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<AdminData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminData> _load() async {
    final profile = await AuthService.getCurrentProfile(forceRefresh: true);
    if (profile?.canEditTricks != true) {
      return AdminData(pendingTricks: [], pendingSuggestions: [], originalTricks: {}, profile: profile);
    }
    final tricks = await TricksService.getPendingTricks();
    final suggestions = await TricksService.getPendingSuggestions();
    final trickIds = suggestions.map((s) => s.trickId).toSet().toList();
    final origList = await TricksService.getTricksByIds(trickIds);
    final originalTricks = {for (final t in origList) t.id: t};
    return AdminData(pendingTricks: tricks, pendingSuggestions: suggestions, originalTricks: originalTricks, profile: profile);
  }

  void _refresh() => setState(() { _future = _load(); });

  Future<void> _updateStatus(int id, ApprovalStatus status) async {
    await TricksService.updateTrickStatus(id, status);
    _refresh();
  }

  Future<void> _approveSuggestion(TrickSuggestion suggestion) async {
    await TricksService.approveSuggestion(suggestion);
    _refresh();
  }

  Future<void> _rejectSuggestion(int id) async {
    await TricksService.deleteSuggestion(id);
    _refresh();
  }

  Future<void> _addPosition(BuildContext context) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.addPositionDialogTitle),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: l10n.addPositionHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelButton)),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(l10n.addButton)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await TricksService.addPosition(name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.positionAdded(name))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()),
                backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<AdminData>(
      future: _future,
      builder: (context, snap) {
        final canEditTricks = snap.data?.profile?.canEditTricks ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.adminTitle),
            actions: [
              if (canEditTricks)
                IconButton(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  tooltip: l10n.addPositionTooltip,
                  onPressed: () => _addPosition(context),
                ),
            ],
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<AdminData> snap) {
    final l10n = context.l10n;
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(child: Text(l10n.errorWithDetail(snap.error.toString())));
    }

    final profile = snap.data?.profile;
    if (profile?.canEditTricks != true) {
      return Center(child: Text(l10n.noAdminAccess));
    }

    final tricks = snap.data!.pendingTricks;
    final suggestions = snap.data!.pendingSuggestions;

    if (tricks.isEmpty && suggestions.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(child: Text(l10n.noPendingTricks)),
            const SizedBox(height: 8),
            Center(child: Text(l10n.noPendingSuggestions)),
          ],
        ),
      );
    }

    final items = <Widget>[
      if (tricks.isNotEmpty) ...[
        for (int i = 0; i < tricks.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PendingTrickCard(
            trick: tricks[i],
            onApprove: () => _updateStatus(tricks[i].id, ApprovalStatus.approved),
            onReject: () => _updateStatus(tricks[i].id, ApprovalStatus.rejected),
            onEdit: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SubmitTrickScreen(existingTrick: tricks[i]),
                ),
              );
              _refresh();
            },
          ),
        ],
      ],
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(l10n.pendingSuggestionsSection,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (int i = 0; i < suggestions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PendingSuggestionCard(
            suggestion: suggestions[i],
            originalTrick: snap.data!.originalTricks[suggestions[i].trickId],
            onApprove: () => _approveSuggestion(suggestions[i]),
            onReject: () => _rejectSuggestion(suggestions[i].id),
          ),
        ],
      ],
    ];

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: items,
      ),
    );
  }
}

class _PendingTrickCard extends StatelessWidget {
  final Trick trick;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const _PendingTrickCard({
    required this.trick,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: ExpansionTile(
        title: Text(trick.givenName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${trick.difficultyLabel} · ${l10n.submittedDate(formatShortDate(trick.dateSubmitted))}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trick.technicalName != null)
                  _row(l10n.technicalNameLabel, trick.technicalName!),
                if (trick.originalPerformer != null)
                  _row(l10n.performerLabel, trick.originalPerformer!),
                if (trick.description != null)
                  _row(l10n.descriptionLabel, trick.description!),
                if (trick.tips != null) _row(l10n.tipsLabel, trick.tips!),
                if (trick.videoLink != null) _row(l10n.videoLabel, trick.videoLink!),
                const SizedBox(height: 12),
                OverflowBar(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.editButton),
                    ),
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.approveButton),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brightness == Brightness.dark
                            ? Colors.green.shade400
                            : Colors.green.shade700,
                        foregroundColor: theme.brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.rejectButton),
                      style: FilledButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

class _PendingSuggestionCard extends StatelessWidget {
  final TrickSuggestion suggestion;
  final Trick? originalTrick;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingSuggestionCard({
    required this.suggestion,
    required this.originalTrick,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final orig = originalTrick;
    final deltaRows = _buildDeltaRows(l10n, orig);

    return Card(
      child: ExpansionTile(
        title: Text(orig?.givenName ?? '?',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(l10n.submittedDate(formatShortDate(suggestion.dateSubmitted))),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...deltaRows,
                const SizedBox(height: 12),
                OverflowBar(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.approveButton),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brightness == Brightness.dark
                            ? Colors.green.shade400
                            : Colors.green.shade700,
                        foregroundColor: theme.brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.rejectButton),
                      style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDeltaRows(AppLocalizations l10n, Trick? orig) {
    final s = suggestion;
    final rows = <Widget>[];

    // Each non-null field in the suggestion IS a proposed change.
    if (s.givenName != null) {
      rows.add(_diffRow(l10n.givenNameLabel, orig?.givenName, s.givenName));
    }
    if (s.technicalName != null) {
      rows.add(_diffRow(l10n.technicalNameLabel, orig?.technicalName, s.technicalName));
    }
    if (s.difficultyTier != null) {
      rows.add(_diffRow(l10n.difficultyLabel, orig?.difficultyLabel, s.difficultyLabel));
    }
    if (s.datePerformed != null) {
      rows.add(_diffRow(
        l10n.dateFirstPerformedLabel,
        orig?.datePerformed != null ? formatDisplayDate(orig!.datePerformed!) : null,
        formatDisplayDate(s.datePerformed!),
      ));
    }
    if (s.originalPerformer != null) {
      rows.add(_diffRow(l10n.performerLabel, orig?.originalPerformer, s.originalPerformer));
    }
    if (s.description != null) {
      rows.add(_diffRow(l10n.descriptionLabel, orig?.description, s.description));
    }
    if (s.tips != null) {
      rows.add(_diffRow(l10n.tipsLabel, orig?.tips, s.tips));
    }
    if (s.videoLink != null) {
      rows.add(_diffRow(l10n.videoLabel, orig?.videoLink, s.videoLink));
    }
    if (s.startPositionId != null) {
      rows.add(_diffRow(l10n.startLabel, orig?.startPositionName, s.startPositionName));
    }
    if (s.endPositionId != null) {
      rows.add(_diffRow(l10n.endLabel, orig?.endPositionName, s.endPositionName));
    }
    if (s.prerequisiteTrickIds != null) {
      rows.add(_diffRow(
        l10n.prerequisitesLabel,
        '${orig?.prerequisiteTrickIds.length ?? 0}',
        '${s.prerequisiteTrickIds!.length}',
      ));
    }

    return rows;
  }

  Widget _diffRow(String label, String? oldVal, String? newVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (oldVal != null)
              TextSpan(
                text: '$oldVal → ',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            TextSpan(
              text: newVal ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

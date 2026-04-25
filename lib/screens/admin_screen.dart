import 'package:flutter/material.dart';
import '../models/trick.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import 'submit_trick_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<(List<Trick>, Profile?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<Trick>, Profile?)> _load() async {
    final profile = await AuthService.getCurrentProfile(forceRefresh: true);
    if (profile?.isAdmin != true) return (<Trick>[], profile);
    final tricks = await TricksService.getPendingTricks();
    return (tricks, profile);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _updateStatus(int id, int status) async {
    await TricksService.updateTrickStatus(id, status);
    _refresh();
  }

  Future<void> _addPosition(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Position'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(hintText: 'e.g. Standing, Hanging'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await TricksService.addPosition(name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Position "$name" added.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Trick>, Profile?)>(
      future: _future,
      builder: (context, snap) {
        final isAdmin = snap.data?.$2?.isAdmin ?? false;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin'),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_location_alt_outlined),
                  tooltip: 'Add Position',
                  onPressed: () => _addPosition(context),
                ),
            ],
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<(List<Trick>, Profile?)> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(child: Text('Error: ${snap.error}'));
    }

    final profile = snap.data?.$2;
    if (profile?.isAdmin != true) {
      return const Center(
        child: Text('You do not have admin access.'),
      );
    }

    final tricks = snap.data!.$1;
    if (tricks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No pending tricks.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tricks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _PendingTrickCard(
          trick: tricks[i],
          onApprove: () => _updateStatus(tricks[i].id, 1),
          onReject: () => _updateStatus(tricks[i].id, 2),
          onEdit: () async {
            await Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SubmitTrickScreen(existingTrick: tricks[i]),
              ),
            );
            _refresh();
          },
        ),
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
    return Card(
      child: ExpansionTile(
        title: Text(trick.givenName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${trick.difficultyLabel} · submitted ${_fmtDate(trick.dateSubmitted)}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trick.technicalName != null)
                  _row('Technical Name', trick.technicalName!),
                if (trick.originalPerformer != null)
                  _row('Performer', trick.originalPerformer!),
                if (trick.description != null)
                  _row('Description', trick.description!),
                if (trick.tips != null) _row('Tips', trick.tips!),
                if (trick.videoLink != null) _row('Video', trick.videoLink!),
                const SizedBox(height: 12),
                OverflowBar(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700),
                    ),
                    FilledButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
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
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

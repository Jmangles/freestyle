import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../widgets/consistency_selector.dart';
import 'submit_trick_screen.dart';

class TrickDetailScreen extends StatefulWidget {
  final String trickId;
  const TrickDetailScreen({super.key, required this.trickId});

  @override
  State<TrickDetailScreen> createState() => _TrickDetailScreenState();
}

class _TrickDetailScreenState extends State<TrickDetailScreen> {
  late Future<(Trick, List<Trick>, UserTrick?, bool)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(Trick, List<Trick>, UserTrick?, bool)> _load() async {
    final trick = await TricksService.getTrickById(widget.trickId);
    final prereqsFuture = TricksService.getTricksByIds(trick.prerequisiteTrickIds);
    final userTrickFuture = AuthService.isLoggedIn
        ? UserTricksService.getUserTrickForTrick(widget.trickId)
        : Future.value(null);
    final profileFuture = AuthService.getCurrentProfile();
    final prereqs = await prereqsFuture;
    final userTrick = await userTrickFuture;
    final profile = await profileFuture;
    return (trick, prereqs, userTrick, profile?.isAdmin == true);
  }

  Future<void> _openEdit(Trick trick) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SubmitTrickScreen(existingTrick: trick)),
    );
    setState(() { _future = _load(); });
  }

  Future<void> _setConsistency(Consistency c) async {
    await UserTricksService.setConsistency(widget.trickId, c);
    setState(() { _future = _load(); });
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication)
        || await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open video link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Trick, List<Trick>, UserTrick?, bool)>(
      future: _future,
      builder: (context, snap) {
        final trick = snap.data?.$1;
        final isAdmin = snap.data?.$4 ?? false;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trick Detail'),
            actions: [
              if (isAdmin && trick != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Trick',
                  onPressed: () => _openEdit(trick),
                ),
            ],
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<(Trick, List<Trick>, UserTrick?, bool)> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(child: Text('Error: ${snap.error}'));
    }
    final (trick, prereqs, userTrick, _) = snap.data!;
    return _buildContent(trick, prereqs, userTrick);
  }

  Widget _buildContent(Trick trick, List<Trick> prereqs, UserTrick? userTrick) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(trick.givenName,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (trick.technicalName != null &&
              trick.technicalName != trick.givenName)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(trick.technicalName!,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 12),

          // Difficulty + positions row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(trick.difficultyTier),
                backgroundColor: theme.colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600),
              ),
              if (trick.startPositionName != null ||
                  trick.endPositionName != null)
                Chip(
                  //avatar: const Icon(Icons.swap_horiz, size: 16),
                  label: Text(
                    [
                      if (trick.startPositionName != null)
                        trick.startPositionName!,
                      if (trick.endPositionName != null) trick.endPositionName!,
                    ].join(' → '),
                  ),
                ),
            ],
          ),

          const Divider(height: 28),

          // Metadata
          if (trick.originalPerformer != null)
            _InfoRow(
                label: 'Original Performer', value: trick.originalPerformer!),
          if (trick.datePerformed != null)
            _InfoRow(
                label: 'Date First Performed',
                value: dateFmt.format(trick.datePerformed!)),
          _InfoRow(
              label: 'Date Submitted',
              value: dateFmt.format(trick.dateSubmitted)),

          // Description
          if (trick.description != null) ...[
            const SizedBox(height: 16),
            Text('Description',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trick.description!),
          ],

          // Tips
          if (trick.tips != null) ...[
            const SizedBox(height: 16),
            Text('Tips',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trick.tips!),
          ],

          // Prerequisites
          if (prereqs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Prerequisites',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: prereqs
                  .map((p) => ActionChip(
                        label: Text(p.givenName),
                        onPressed: () =>
                            context.push('/trick/${p.id}'),
                      ))
                  .toList(),
            ),
          ],

          // Video
          if (trick.videoLink != null && trick.videoLink!.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openVideo(trick.videoLink!),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch Video'),
            ),
          ],

          // Consistency tracker
          if (AuthService.isLoggedIn) ...[
            const Divider(height: 28),
            Text('My Consistency',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConsistencySelector(
              selected: userTrick?.consistency,
              onChanged: _setConsistency,
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

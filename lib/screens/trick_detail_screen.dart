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

class TrickDetailScreen extends StatefulWidget {
  final String trickId;
  const TrickDetailScreen({super.key, required this.trickId});

  @override
  State<TrickDetailScreen> createState() => _TrickDetailScreenState();
}

class _TrickDetailScreenState extends State<TrickDetailScreen> {
  late Future<(Trick, List<Trick>, UserTrick?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(Trick, List<Trick>, UserTrick?)> _load() async {
    final trick = await TricksService.getTrickById(widget.trickId);
    final prereqs =
        await TricksService.getTricksByIds(trick.prerequisiteTrickIds);
    final userTrick = AuthService.isLoggedIn
        ? await UserTricksService.getUserTrickForTrick(widget.trickId)
        : null;
    return (trick, prereqs, userTrick);
  }

  Future<void> _setConsistency(Consistency c) async {
    await UserTricksService.setConsistency(widget.trickId, c);
    setState(() => _future = _load());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Trick Detail')),
      body: FutureBuilder<(Trick, List<Trick>, UserTrick?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final (trick, prereqs, userTrick) = snap.data!;
          return _buildContent(trick, prereqs, userTrick);
        },
      ),
    );
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
                  avatar: const Icon(Icons.swap_horiz, size: 16),
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

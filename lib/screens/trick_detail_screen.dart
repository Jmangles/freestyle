import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../utils/date_formatters.dart';
import '../utils/difficulty_tier.dart';
import '../widgets/consistency_selector.dart';
import 'submit_trick_screen.dart';

class TrickDetailScreen extends StatefulWidget {
  final int trickId;
  const TrickDetailScreen({super.key, required this.trickId});

  @override
  State<TrickDetailScreen> createState() => _TrickDetailScreenState();
}

class _TrickDetailScreenState extends State<TrickDetailScreen> {
  late Future<TrickDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TrickDetailData> _load() async {
    final trick = await TricksService.getTrickById(widget.trickId);
    final prereqsFuture = TricksService.getTricksByIds(trick.prerequisiteTrickIds);
    final userTrickFuture = AuthService.isLoggedIn
        ? UserTricksService.getUserTrickForTrick(widget.trickId)
        : Future.value(null);
    final profileFuture = AuthService.getCurrentProfile();
    final prereqs = await prereqsFuture;
    final userTrick = await userTrickFuture;
    final profile = await profileFuture;
    return TrickDetailData(
      trick: trick,
      prerequisites: prereqs,
      userTrick: userTrick,
      isAdmin: profile?.isAdmin == true,
    );
  }

  Future<void> _deleteTrick(Trick trick) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trick'),
        content: Text('Are you sure you want to delete "${trick.givenName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TricksService.deleteTrick(trick.id);
    if (mounted) context.pop();
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
    return FutureBuilder<TrickDetailData>(
      future: _future,
      builder: (context, snap) {
        final trick = snap.data?.trick;
        final isAdmin = snap.data?.isAdmin ?? false;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Trick Detail'),
            actions: [
              if (isAdmin && trick != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Trick',
                  onPressed: () => _openEdit(trick),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete Trick',
                  onPressed: () => _deleteTrick(trick),
                ),
              ],
            ],
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<TrickDetailData> snap) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) {
      return Center(child: Text('Error: ${snap.error}'));
    }
    final data = snap.data!;
    return _buildContent(data.trick, data.prerequisites, data.userTrick);
  }

  Widget _buildContent(Trick trick, List<Trick> prereqs, UserTrick? userTrick) {
    final theme = Theme.of(context);

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
                label: Text(trick.difficultyLabel),
                backgroundColor: theme.colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600),
              ),
              if (trick.startPositionName != null ||
                  trick.endPositionName != null)
                Chip(
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
                value: formatDisplayDate(trick.datePerformed!)),
          _InfoRow(
              label: 'Date Submitted',
              value: formatDisplayDate(trick.dateSubmitted)),

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
            if (userTrick != null && userTrick.consistency.isLanded) ...[
              const SizedBox(height: 20),
              Text('Landed Details',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('All fields optional',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              _LandedDetailsSection(
                key: ValueKey(
                    '${userTrick.difficultyVote}-${userTrick.leashPosition?.index}-${userTrick.videoLink}'),
                trickId: widget.trickId,
                userTrick: userTrick,
                onSaved: () => setState(() { _future = _load(); }),
              ),
            ],
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

class _LandedDetailsSection extends StatefulWidget {
  final int trickId;
  final UserTrick userTrick;
  final VoidCallback onSaved;

  const _LandedDetailsSection({
    super.key,
    required this.trickId,
    required this.userTrick,
    required this.onSaved,
  });

  @override
  State<_LandedDetailsSection> createState() => _LandedDetailsSectionState();
}

class _LandedDetailsSectionState extends State<_LandedDetailsSection> {
  int? _difficultyVote;
  LeashPosition? _leashPosition;
  late TextEditingController _videoController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _difficultyVote = widget.userTrick.difficultyVote;
    _leashPosition = widget.userTrick.leashPosition;
    _videoController = TextEditingController(text: widget.userTrick.videoLink ?? '');
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await UserTricksService.setLandedDetails(
      widget.trickId,
      difficultyVote: _difficultyVote,
      leashPosition: _leashPosition,
      videoLink: _videoController.text.trim().isEmpty ? null : _videoController.text.trim(),
    );
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Difficulty Vote', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (_difficultyVote == null)
          TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add vote'),
            onPressed: () => setState(() => _difficultyVote = 15),
          )
        else
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  DifficultyTier.label(_difficultyVote!),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _difficultyVote!.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setState(() => _difficultyVote = v.round()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Remove vote',
                onPressed: () => setState(() => _difficultyVote = null),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text('Leash Position', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: LeashPosition.values.map((p) {
            final selected = _leashPosition == p;
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (sel) =>
                  setState(() => _leashPosition = sel ? p : null),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text('Video Link', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        TextField(
          controller: _videoController,
          decoration: const InputDecoration(
            hintText: 'https://',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save details'),
        ),
      ],
    );
  }
}

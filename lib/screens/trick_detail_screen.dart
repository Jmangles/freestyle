import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/screen_data.dart';
import '../models/trick.dart';
import '../models/trick_vote_stats.dart';
import '../models/user_trick.dart';
import '../services/auth_service.dart';
import '../services/tricks_service.dart';
import '../services/user_tricks_service.dart';
import '../utils/date_formatters.dart';
import '../utils/difficulty_tier.dart';
import '../utils/youtube_utils.dart';
import '../widgets/back_home_leading.dart';
import '../widgets/consistency_selector.dart';
import '../widgets/youtube_loop_player.dart';
import 'submit_trick_screen.dart';
import 'trick_progression_screen.dart';

class TrickDetailScreen extends StatefulWidget {
  final int trickId;
  const TrickDetailScreen({super.key, required this.trickId});

  @override
  State<TrickDetailScreen> createState() => _TrickDetailScreenState();
}

class _TrickDetailScreenState extends State<TrickDetailScreen> {
  late Future<TrickDetailData> _future;
  TrickDetailData? _data;

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
    final voteStatsFuture = UserTricksService.getTrickVoteStats(widget.trickId);
    final prereqs = await prereqsFuture;
    final userTrick = await userTrickFuture;
    final profile = await profileFuture;
    final voteStats = await voteStatsFuture;
    final prereqUserTricks = AuthService.isLoggedIn
        ? await UserTricksService.getUserTricksForTrickIds(
            prereqs.map((p) => p.id).toList())
        : <int, UserTrick>{};
    return TrickDetailData(
      trick: trick,
      prerequisites: prereqs,
      prerequisiteUserTricks: prereqUserTricks,
      userTrick: userTrick,
      canEditTricks: profile?.canEditTricks == true,
      voteStats: voteStats,
    );
  }

  Future<void> _deleteTrick(Trick trick) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTrickDialogTitle),
        content: Text(l10n.deleteTrickConfirmMessage(trick.givenName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteButton),
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

  Future<void> _openSuggestEdit(Trick trick) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SubmitTrickScreen(suggestionForTrick: trick)),
    );
  }

  Future<void> _setConsistency(Consistency c) async {
    if (_data != null) {
      final existing = _data!.userTrick;
      final optimistic = existing != null
          ? UserTrick(
              id: existing.id,
              userId: existing.userId,
              trickId: existing.trickId,
              consistency: c,
              difficultyVote: existing.difficultyVote,
              leashPosition: existing.leashPosition,
              videoLink: existing.videoLink,
              videoStart: existing.videoStart,
              videoEnd: existing.videoEnd,
            )
          : UserTrick(id: -1, userId: -1, trickId: widget.trickId, consistency: c);
      setState(() {
        _data = TrickDetailData(
          trick: _data!.trick,
          prerequisites: _data!.prerequisites,
          prerequisiteUserTricks: _data!.prerequisiteUserTricks,
          userTrick: optimistic,
          canEditTricks: _data!.canEditTricks,
          voteStats: _data!.voteStats,
        );
      });
    }
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
        SnackBar(content: Text(context.l10n.couldNotOpenVideoLink)),
      );
    }
  }

  Widget _buildVideoPlayer(String url, int? start, int? end) {
    final (:id, :isPortrait) = parseYouTubeVideo(url);
    if (id != null && YoutubeLoopPlayer.supported) {
      return YoutubeLoopPlayer(
        videoId: id,
        startSeconds: start,
        endSeconds: end,
        isPortrait: isPortrait,
      );
    }
    return FilledButton.icon(
      onPressed: () => _openVideo(url),
      icon: const Icon(Icons.play_circle_outline),
      label: Text(context.l10n.watchVideoButton),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final routeDepth = GoRouter.of(context)
        .routerDelegate
        .currentConfiguration
        .matches
        .length;
    return FutureBuilder<TrickDetailData>(
      future: _future,
      builder: (context, snap) {
        final trick = snap.data?.trick;
        final canEditTricks = snap.data?.canEditTricks ?? false;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: routeDepth > 2 ? 96 : 48,
            leading: BackHomeLeading(showHome: routeDepth > 2),
            title: Text(l10n.trickDetailTitle),
            actions: [
              if (canEditTricks && trick != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.editTrickTooltip,
                  onPressed: () => _openEdit(trick),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  tooltip: l10n.deleteTrickTooltip,
                  onPressed: () => _deleteTrick(trick),
                ),
              ] else if (!canEditTricks && AuthService.isLoggedIn && trick != null)
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined),
                  tooltip: l10n.suggestEditTooltip,
                  onPressed: () => _openSuggestEdit(trick),
                ),
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: l10n.viewProgressionTooltip,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrickProgressionScreen(trickId: widget.trickId),
                  ),
                ),
              ),
            ],
          ),
          body: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<TrickDetailData> snap) {
    if (snap.hasData) _data = snap.data;

    if (_data == null) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(child: Text(context.l10n.errorWithDetail(snap.error.toString())));
      }
      return const SizedBox.shrink();
    }

    final data = _data!;
    return _buildContent(data.trick, data.prerequisites, data.prerequisiteUserTricks, data.userTrick, data.voteStats);
  }

  Widget _buildContent(Trick trick, List<Trick> prereqs,
      Map<int, UserTrick> prereqUserTricks, UserTrick? userTrick,
      TrickVoteStats voteStats) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          if (trick.originalPerformer != null)
            _InfoRow(
                label: l10n.originalPerformerLabel, value: trick.originalPerformer!),
          if (trick.datePerformed != null)
            _InfoRow(
                label: l10n.dateFirstPerformedLabel,
                value: formatDisplayDate(trick.datePerformed!)),
          _InfoRow(
              label: l10n.dateSubmittedLabel,
              value: formatDisplayDate(trick.dateSubmitted)),

          if (trick.description != null) ...[
            const SizedBox(height: 16),
            Text(l10n.descriptionLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trick.description!),
          ],

          if (trick.tips != null) ...[
            const SizedBox(height: 16),
            Text(l10n.tipsLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(trick.tips!),
          ],

          if (prereqs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.prerequisitesLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: prereqs.map((p) {
                final consistency = prereqUserTricks[p.id]?.consistency;
                final bg = consistency?.cardColor(theme.brightness);
                final border = consistency != null
                    ? BorderSide(
                        color: consistency.borderColor(theme.brightness),
                        width: consistency.borderWidth,
                      )
                    : null;
                return ActionChip(
                  label: Text(p.givenName),
                  backgroundColor: bg,
                  side: border,
                  elevation: consistency?.hasGlow == true ? 6 : null,
                  shadowColor: consistency?.hasGlow == true
                      ? consistency!.borderColor(theme.brightness).withValues(alpha: 0.7)
                      : null,
                  onPressed: () => context.push('/trick/${p.id}'),
                );
              }).toList(),
            ),
          ],

          if (trick.videoLink != null && trick.videoLink!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildVideoPlayer(trick.videoLink!, trick.videoStart, trick.videoEnd),
          ],

          if (voteStats.hasAnyData) ...[
            const Divider(height: 28),
            Text(l10n.communityVotesLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                if (voteStats.hasDifficultyVotes)
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.difficultyLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        _VotePieChart(
                          entries: (voteStats.difficultyVotes.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)))
                              .map((e) {
                            final colors = DifficultyTier.badgeColors(e.key);
                            return _VoteEntry(
                              label: DifficultyTier.label(e.key),
                              count: e.value,
                              color: colors?.$1,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (voteStats.hasLeashVotes)
                  SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.leashPositionLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        _VotePieChart(
                          entries: (voteStats.leashPositions.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)))
                              .map((e) => _VoteEntry(
                                    label: LeashPosition.values[e.key].localizedLabel(l10n),
                                    count: e.value,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          if (AuthService.isLoggedIn) ...[
            const Divider(height: 28),
            Text(l10n.myConsistencyLabel,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConsistencySelector(
              selected: userTrick?.consistency,
              onChanged: _setConsistency,
            ),
            if (userTrick != null && userTrick.consistency.isLanded) ...[
              const SizedBox(height: 20),
              Text(l10n.landedDetailsLabel,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.allFieldsOptional,
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
  late TextEditingController _videoStartController;
  late TextEditingController _videoEndController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ut = widget.userTrick;
    _difficultyVote = ut.difficultyVote;
    _leashPosition = ut.leashPosition;
    _videoController = TextEditingController(text: ut.videoLink ?? '');
    _videoStartController =
        TextEditingController(text: ut.videoStart != null ? '${ut.videoStart}' : '');
    _videoEndController =
        TextEditingController(text: ut.videoEnd != null ? '${ut.videoEnd}' : '');
  }

  @override
  void dispose() {
    _videoController.dispose();
    _videoStartController.dispose();
    _videoEndController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final link = _videoController.text.trim();
      await UserTricksService.setLandedDetails(
        widget.trickId,
        difficultyVote: _difficultyVote,
        leashPosition: _leashPosition,
        videoLink: link.isEmpty ? null : link,
        videoStart: int.tryParse(_videoStartController.text.trim()),
        videoEnd: int.tryParse(_videoEndController.text.trim()),
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final savedVideo = parseYouTubeVideo(widget.userTrick.videoLink);
    final savedVideoId = savedVideo.id;
    final isPortrait = savedVideo.isPortrait;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<int?>(
                initialValue: _difficultyVote,
                decoration: InputDecoration(
                  labelText: l10n.difficultyVoteLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.noneOption),
                  ),
                  ...List.generate(30, (i) => i + 1).map((v) =>
                      DropdownMenuItem<int?>(
                        value: v,
                        child: Text(DifficultyTier.label(v)),
                      )),
                ],
                onChanged: (v) => setState(() => _difficultyVote = v),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<LeashPosition?>(
                initialValue: _leashPosition,
                decoration: InputDecoration(
                  labelText: l10n.leashPositionLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<LeashPosition?>(
                    value: null,
                    child: Text(l10n.noneOption),
                  ),
                  ...LeashPosition.values.map((p) =>
                      DropdownMenuItem<LeashPosition?>(
                        value: p,
                        child: Text(p.localizedLabel(l10n)),
                      )),
                ],
                onChanged: (p) => setState(() => _leashPosition = p),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.videoLinkLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        TextField(
          controller: _videoController,
          decoration: InputDecoration(
            hintText: l10n.videoLinkHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _videoStartController,
                decoration: InputDecoration(
                  labelText: l10n.loopStartLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _videoEndController,
                decoration: InputDecoration(
                  labelText: l10n.loopEndLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
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
              : Text(l10n.saveDetailsButton),
        ),
        if (savedVideoId != null && YoutubeLoopPlayer.supported) ...[
          const SizedBox(height: 16),
          Text(l10n.yourLandingVideoLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          YoutubeLoopPlayer(
            videoId: savedVideoId,
            startSeconds: widget.userTrick.videoStart,
            endSeconds: widget.userTrick.videoEnd,
            isPortrait: isPortrait,
          ),
        ],
      ],
    );
  }
}

class _VoteEntry {
  final String label;
  final int count;
  final Color? color;

  const _VoteEntry({required this.label, required this.count, this.color});
}

class _VotePieChart extends StatelessWidget {
  final List<_VoteEntry> entries;

  const _VotePieChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (sum, e) => sum + e.count);
    final colors = entries
        .map((e) => e.color ?? theme.colorScheme.primary)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 110,
            height: 110,
            child: CustomPaint(
              painter: _PieChartPainter(
                entries: entries,
                colors: colors,
                total: total,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...entries.asMap().entries.map((e) {
          final entry = e.value;
          final color = colors[e.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${entry.label} (${entry.count})',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<_VoteEntry> entries;
  final List<Color> colors;
  final int total;

  const _PieChartPainter({
    required this.entries,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final sweep = 2 * math.pi * entries[i].count / total;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..color = colors[i].withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      entries != old.entries || total != old.total;
}


import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/network_utils.dart';
import '../utils/safe_state.dart';
import '../utils/youtube_utils.dart';
import '../widgets/app_dialogs.dart';
import '../video/offline_video_service.dart';
import '../widgets/back_home_leading.dart';
import '../widgets/consistency_selector.dart';
import '../widgets/landed_details_section.dart';
import '../widgets/vote_pie_chart.dart';
import '../widgets/youtube_loop_player.dart';
import 'submit_trick_screen.dart';
import 'trick_progression_screen.dart';

class TrickDetailScreen extends StatefulWidget {
  final int trickId;
  const TrickDetailScreen({super.key, required this.trickId});

  @override
  State<TrickDetailScreen> createState() => _TrickDetailScreenState();
}

class _TrickDetailScreenState extends State<TrickDetailScreen>
    with SafeStateMixin {
  late Future<TrickDetailData> _future;
  TrickDetailData? _data;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (!kIsWeb) {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        setDeviceConnectivity(results);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<TrickDetailData> _load() async {
    final trick = await TricksService.getTrickById(widget.trickId);
    final prereqsFuture =
        TricksService.getTricksByIds(trick.prerequisiteTrickIds);
    final baseTricksFuture =
        TricksService.getTricksByIds(trick.baseTrickIds);
    final variationsFuture =
        TricksService.getVariationsOf(trick.id);
    final userTrickFuture = AuthService.isLoggedIn
        ? UserTricksService.getUserTrickForTrick(widget.trickId)
        : Future.value(null);
    final profileFuture = AuthService.getCurrentProfile();
    final voteStatsFuture =
        UserTricksService.getTrickVoteStats(widget.trickId);
    final prereqs = await prereqsFuture;
    final baseTricks = await baseTricksFuture;
    final variations = await variationsFuture;
    final userTrick = await userTrickFuture;
    final profile = await profileFuture;
    final voteStats = await voteStatsFuture;
    final prereqUserTricks = AuthService.isLoggedIn
        ? await UserTricksService.getUserTricksForTrickIds(
            prereqs.map((p) => p.id).toList())
        : <int, UserTrick>{};
    final variationUserTricks = AuthService.isLoggedIn
        ? await UserTricksService.getUserTricksForTrickIds(
            variations.map((v) => v.id).toList())
        : <int, UserTrick>{};
    return TrickDetailData(
      trick: trick,
      prerequisites: prereqs,
      baseTricks: baseTricks,
      variations: variations,
      prerequisiteUserTricks: prereqUserTricks,
      variationUserTricks: variationUserTricks,
      userTrick: userTrick,
      canEditTricks: profile?.canEditTricks == true,
      voteStats: voteStats,
    );
  }

  Future<void> _deleteTrick(Trick trick) async {
    final l10n = context.l10n;
    final confirmed = await AppDialogs.confirmDestructive(
      context,
      title: l10n.deleteTrickDialogTitle,
      content: l10n.deleteTrickConfirmMessage(trick.givenName),
      confirmLabel: l10n.deleteButton,
      cancelLabel: l10n.cancelButton,
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
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openSuggestEdit(Trick trick) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
          builder: (_) => SubmitTrickScreen(suggestionForTrick: trick)),
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
              updatedAt: existing.updatedAt,
            )
          : UserTrick(
              id: -1,
              userId: -1,
              trickId: widget.trickId,
              consistency: c,
              updatedAt: DateTime.now(),
            );
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
    setState(() {
      _future = _load();
    });
  }

  Future<void> _copyLink() async {
    final message = context.l10n.linkCopiedMessage;
    final url = Uri.base.resolve('/trick/${widget.trickId}').toString();
    await Clipboard.setData(ClipboardData(text: url));
    showInfoSnackBar(message);
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication) ||
            await launchUrl(uri, mode: LaunchMode.platformDefault);
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
        final canPop = context.canPop();
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leadingWidth: (canPop && routeDepth > 2) ? 96 : 48,
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
              ] else if (!canEditTricks &&
                  AuthService.isLoggedIn &&
                  trick != null &&
                  !isDeviceOffline)
                IconButton(
                  icon: const Icon(Icons.rate_review_outlined),
                  tooltip: l10n.suggestEditTooltip,
                  onPressed: () => _openSuggestEdit(trick),
                ),
              IconButton(
                icon: const Icon(Icons.link),
                tooltip: l10n.copyLinkTooltip,
                onPressed: _copyLink,
              ),
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: l10n.viewProgressionTooltip,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TrickProgressionScreen(trickId: widget.trickId),
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
        return Center(
            child: Text(
                context.l10n.errorWithDetail(snap.error.toString())));
      }
      return const SizedBox.shrink();
    }

    final data = _data!;
    return _buildContent(data.trick, data.prerequisites, data.baseTricks,
        data.variations, data.prerequisiteUserTricks, data.variationUserTricks,
        data.userTrick, data.voteStats);
  }

  Widget _buildContent(
      Trick trick,
      List<Trick> prereqs,
      List<Trick> baseTricks,
      List<Trick> variations,
      Map<int, UserTrick> prereqUserTricks,
      Map<int, UserTrick> variationUserTricks,
      UserTrick? userTrick,
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
                label: l10n.originalPerformerLabel,
                value: trick.originalPerformer!),
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

          if (baseTricks.where((t) => !prereqs.any((p) => p.id == t.id)).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Variation of',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: baseTricks
                  .where((t) => !prereqs.any((p) => p.id == t.id))
                  .map((t) => ActionChip(
                        label: Text(t.givenName),
                        onPressed: () => context.push('/trick/${t.id}'),
                      ))
                  .toList(),
            ),
          ],

          if (variations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Variations',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: variations.map((t) {
                final consistency = variationUserTricks[t.id]?.consistency;
                final bg = consistency?.cardColor(theme.brightness);
                final border = consistency != null
                    ? BorderSide(
                        color: consistency.borderColor(theme.brightness),
                        width: consistency.borderWidth,
                      )
                    : null;
                return ActionChip(
                  label: Text(t.givenName),
                  backgroundColor: bg,
                  side: border,
                  elevation: consistency?.hasGlow == true ? 6 : null,
                  shadowColor: consistency?.hasGlow == true
                      ? consistency!
                          .borderColor(theme.brightness)
                          .withValues(alpha: 0.7)
                      : null,
                  onPressed: () => context.push('/trick/${t.id}'),
                );
              }).toList(),
            ),
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
                      ? consistency!
                          .borderColor(theme.brightness)
                          .withValues(alpha: 0.7)
                      : null,
                  onPressed: () => context.push('/trick/${p.id}'),
                );
              }).toList(),
            ),
          ],

          if (trick.hasTrainingVideo)
            ValueListenableBuilder<Set<int>>(
              valueListenable: OfflineVideoService.savedTrickIds,
              builder: (context, saved, _) {
                if (isDeviceOffline && !saved.contains(trick.id)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/trick/${trick.id}/training-studio'),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Training Studio'),
                  ),
                );
              },
            ),

          if (!trick.hasTrainingVideo &&
              !isDeviceOffline &&
              trick.videoLink != null &&
              trick.videoLink!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildVideoPlayer(
                trick.videoLink!, trick.videoStart, trick.videoEnd),
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
                        VotePieChart(
                          entries: (voteStats.difficultyVotes.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)))
                              .map((e) {
                            final colors = DifficultyTier.badgeColors(e.key);
                            return VoteEntry(
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
                        VotePieChart(
                          entries: (voteStats.leashPositions.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key)))
                              .map((e) => VoteEntry(
                                    label: LeashPosition.values[e.key]
                                        .localizedLabel(l10n),
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
              LandedDetailsSection(
                key: ValueKey(
                    '${userTrick.difficultyVote}-${userTrick.leashPosition?.index}-${userTrick.videoLink}'),
                trickId: widget.trickId,
                userTrick: userTrick,
                onSaved: () => setState(() {
                  _future = _load();
                }),
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

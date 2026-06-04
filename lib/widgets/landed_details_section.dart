import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import '../l10n/enum_localizations.dart';
import '../models/user_trick.dart';
import '../services/user_tricks_service.dart';
import '../utils/difficulty_tier.dart';
import '../utils/safe_state.dart';
import '../utils/youtube_utils.dart';
import 'youtube_loop_player.dart';

/// Form for recording difficulty vote, leash position, and a YouTube video
/// link after a trick has been landed at least once.
class LandedDetailsSection extends StatefulWidget {
  final int trickId;
  final UserTrick userTrick;
  final VoidCallback onSaved;

  const LandedDetailsSection({
    super.key,
    required this.trickId,
    required this.userTrick,
    required this.onSaved,
  });

  @override
  State<LandedDetailsSection> createState() => _LandedDetailsSectionState();
}

class _LandedDetailsSectionState extends State<LandedDetailsSection>
    with SafeStateMixin {
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
    _videoStartController = TextEditingController(
        text: ut.videoStart != null ? '${ut.videoStart}' : '');
    _videoEndController = TextEditingController(
        text: ut.videoEnd != null ? '${ut.videoEnd}' : '');
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
      showErrorSnackBar(e.toString());
    } finally {
      safeSetState(() => _saving = false);
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
                      value: null, child: Text(l10n.noneOption)),
                  ...List.generate(30, (i) => i + 1).map((v) =>
                      DropdownMenuItem<int?>(
                          value: v, child: Text(DifficultyTier.label(v)))),
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
                      value: null, child: Text(l10n.noneOption)),
                  ...LeashPosition.values.map((p) =>
                      DropdownMenuItem<LeashPosition?>(
                          value: p, child: Text(p.localizedLabel(l10n)))),
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

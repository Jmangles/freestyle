import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../video/playback_direction.dart';
import '../video/training_video_controller.dart';
import '../video/video_provider.dart';

class TrainingStudioScreen extends StatefulWidget {
  final int trickId;
  final VideoProvider provider;
  final String? title;

  const TrainingStudioScreen({
    super.key,
    required this.trickId,
    required this.provider,
    this.title,
  });

  @override
  State<TrainingStudioScreen> createState() => _TrainingStudioScreenState();
}

class _TrainingStudioScreenState extends State<TrainingStudioScreen> {
  late final Player _forwardPlayer;
  late final Player _reversedPlayer;
  late final VideoController _forwardVideoController;
  late final VideoController _reversedVideoController;
  late final TrainingVideoController _controller;

  late final StreamSubscription<Duration> _forwardPositionSub;
  late final StreamSubscription<Duration> _reversedPositionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _forwardCompletedSub;
  late final StreamSubscription<bool> _reversedCompletedSub;

  bool _loading = true;

  Player get _activePlayer => _controller.state.direction == PlaybackDirection.forward
      ? _forwardPlayer
      : _reversedPlayer;

@override
  void initState() {
    super.initState();
    _forwardPlayer = Player();
    _reversedPlayer = Player();
    _forwardVideoController = VideoController(_forwardPlayer);
    _reversedVideoController = VideoController(_reversedPlayer);

    _controller = TrainingVideoController(
      provider: widget.provider,
      trickId: widget.trickId,
    );

    // Manual looping so the playback rate is re-applied on each cycle.
    // PlaylistMode.loop causes libmpv to reset the rate to 1.0 on loop.
    _forwardCompletedSub = _forwardPlayer.stream.completed.listen((done) {
      if (!done) return;
      _forwardPlayer.seek(Duration.zero).then((_) {
        _forwardPlayer.setRate(_controller.state.speed);
        _forwardPlayer.play();
      });
    });
    _reversedCompletedSub = _reversedPlayer.stream.completed.listen((done) {
      if (!done) return;
      _reversedPlayer.seek(Duration.zero).then((_) {
        _reversedPlayer.setRate(_controller.state.speed);
        _reversedPlayer.play();
      });
    });

    // Duration only needs to come from one file — both are the same length.
    _durationSub = _forwardPlayer.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _controller.setDuration(duration);
        if (mounted) setState(() => _loading = false);
      }
    });

    // Forward position is trick time directly.
    _forwardPositionSub = _forwardPlayer.stream.position.listen((pos) {
      if (_controller.state.direction != PlaybackDirection.forward) return;
      _controller.updatePosition(pos);
      if (mounted) setState(() {});
    });

    // Reversed file position must be mirrored to get trick time.
    _reversedPositionSub = _reversedPlayer.stream.position.listen((pos) {
      if (_controller.state.direction != PlaybackDirection.reversed) return;
      if (_controller.state.totalDuration == Duration.zero) return;
      _controller.updatePosition(_controller.state.totalDuration - pos);
      if (mounted) setState(() {});
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Start forward video playing immediately.
    _forwardPlayer.open(
      Media(widget.provider.forwardUrl(widget.trickId).toString()),
      play: true,
    );
    _controller.play();

    // Pre-load reversed in the background so it's ready when the user toggles.
    _reversedPlayer.open(
      Media(widget.provider.reversedUrl(widget.trickId).toString()),
      play: false,
    );
  }

  @override
  void dispose() {
    _forwardPositionSub.cancel();
    _reversedPositionSub.cancel();
    _durationSub.cancel();
    _forwardCompletedSub.cancel();
    _reversedCompletedSub.cancel();
    _controller.dispose();
    _forwardPlayer.dispose();
    _reversedPlayer.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    _controller.play();
    await _activePlayer.play();
  }

  Future<void> _pause() async {
    _controller.pause();
    await _activePlayer.pause();
  }

  Future<void> _restart() async {
    _controller.restart();
    await _activePlayer.seek(_controller.state.fileSeekPosition);
    await _activePlayer.play();
  }

  Future<void> _stepForward() async {
    await _activePlayer.pause();
    _controller.stepForward();
    await _activePlayer.seek(_controller.state.fileSeekPosition);
  }

  Future<void> _stepBackward() async {
    await _activePlayer.pause();
    _controller.stepBackward();
    await _activePlayer.seek(_controller.state.fileSeekPosition);
  }

  Future<void> _setSpeed(double speed) async {
    _controller.setSpeed(speed);
    await _forwardPlayer.setRate(speed);
    await _reversedPlayer.setRate(speed);
  }

  Future<void> _toggleDirection() async {
    // Pause the outgoing player before switching.
    await _activePlayer.pause();

    _controller.toggleDirection();

    // The incoming player is already loaded — just seek to the mirrored
    // position and play. No open() call means no buffering race.
    await _activePlayer.seek(_controller.state.fileSeekPosition);
    await _activePlayer.setRate(_controller.state.speed);
    await _activePlayer.play();
    _controller.play();
  }

  void _onScrub(double value) {
    if (_controller.state.totalDuration == Duration.zero) return;
    final newPosition = _controller.state.totalDuration * value;
    _controller.updatePosition(newPosition);
    _activePlayer.seek(_controller.state.fileSeekPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Training Studio'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildVideoArea(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    // Both VideoControllers stay in the tree so their players remain active.
    // Offstage hides the inactive one without destroying it.
    final isForward = _controller.state.direction == PlaybackDirection.forward;
    return Stack(
      children: [
        Offstage(
          offstage: !isForward,
          child: Video(controller: _forwardVideoController, controls: null),
        ),
        Offstage(
          offstage: isForward,
          child: Video(controller: _reversedVideoController, controls: null),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final state = _controller.state;
    final totalMicros = state.totalDuration.inMicroseconds;
    final progress = totalMicros > 0
        ? (state.position.inMicroseconds / totalMicros).clamp(0.0, 1.0)
        : 0.0;
    final canAct = !_loading;

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: canAct ? _onScrub : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_fmt(state.position)} / ${_fmt(state.totalDuration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.navigate_before, color: Colors.white),
                tooltip: 'Step back one frame',
                onPressed: canAct ? _stepBackward : null,
              ),
              IconButton(
                icon: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                tooltip: state.isPlaying ? 'Pause' : 'Play',
                onPressed: canAct ? (state.isPlaying ? _pause : _play) : null,
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next, color: Colors.white),
                tooltip: 'Step forward one frame',
                onPressed: canAct ? _stepForward : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay, color: Colors.white),
                tooltip: 'Restart',
                onPressed: canAct ? _restart : null,
              ),
              IconButton(
                icon: Icon(
                  state.direction == PlaybackDirection.forward
                      ? Icons.arrow_forward
                      : Icons.arrow_back,
                  color: state.direction == PlaybackDirection.reversed
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                ),
                tooltip: state.direction == PlaybackDirection.forward
                    ? 'Playing forward — tap to reverse'
                    : 'Playing reversed — tap to go forward',
                onPressed: canAct ? _toggleDirection : null,
              ),
              const Spacer(),
              ...[0.25, 0.5, 0.75, 1.0].map(
                (speed) => _SpeedButton(
                  speed: speed,
                  selected: state.speed == speed,
                  onTap: canAct ? () => _setSpeed(speed) : null,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _SpeedButton extends StatelessWidget {
  final double speed;
  final bool selected;
  final VoidCallback? onTap;

  const _SpeedButton({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  String get _label {
    if (speed == 0.25) return '¼×';
    if (speed == 0.5) return '½×';
    if (speed == 0.75) return '¾×';
    return '1×';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Text(
          _label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

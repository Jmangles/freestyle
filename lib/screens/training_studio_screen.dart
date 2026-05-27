import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../utils/web_connection.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/trick_annotation.dart';
import '../services/annotations_service.dart';
import '../services/auth_service.dart';
import '../video/playback_direction.dart';
import '../video/training_video_controller.dart';
import '../video/video_provider.dart';
import '../widgets/back_home_leading.dart';

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
  late final StreamSubscription<bool> _forwardPlayingSub;
  late final StreamSubscription<bool> _reversedPlayingSub;
  late final StreamSubscription<bool> _forwardBufferingSub;
  late final StreamSubscription<bool> _reversedBufferingSub;

  bool _loading = true;
  bool _buffering = false;
  bool _reversedLoaded = false;
  bool _useMobileQuality = false;
  Duration _lastForwardPos = Duration.zero;
  Duration _lastReversedPos = Duration.zero;
  List<TrickAnnotation> _annotations = [];
  bool _isEditor = false;

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

    // Duration only needs to come from one file — both are the same length.
    _durationSub = _forwardPlayer.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _controller.setDuration(duration);
        if (mounted) setState(() => _loading = false);
      }
    });

    // Forward position is trick time directly.
    // Detect a playlist loop by watching for the file position to jump
    // backward past a large gap — libmpv looped natively, so re-apply the
    // playback rate (PlaylistMode.loop resets it to 1.0 on every cycle).
    _forwardPositionSub = _forwardPlayer.stream.position.listen((pos) {
      if (_controller.state.direction != PlaybackDirection.forward) return;
      if (_lastForwardPos > const Duration(milliseconds: 500) &&
          pos < const Duration(milliseconds: 100)) {
        _forwardPlayer.setRate(_controller.state.speed);
      }
      _lastForwardPos = pos;
      _controller.updatePosition(pos);
      if (mounted) setState(() {});
    });

    // Reversed file position must be mirrored to get trick time.
    _reversedPositionSub = _reversedPlayer.stream.position.listen((pos) {
      if (_controller.state.direction != PlaybackDirection.reversed) return;
      if (_controller.state.totalDuration == Duration.zero) return;
      if (_lastReversedPos > const Duration(milliseconds: 500) &&
          pos < const Duration(milliseconds: 100)) {
        _reversedPlayer.setRate(_controller.state.speed);
      }
      _lastReversedPos = pos;
      _controller.updatePosition(_controller.state.totalDuration - pos);
      if (mounted) setState(() {});
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Sync controller play/pause state from the actual player so that browser
    // autoplay blocks (fresh page loads) are reflected in the UI correctly.
    _forwardPlayingSub = _forwardPlayer.stream.playing.listen((playing) {
      if (_controller.state.direction != PlaybackDirection.forward) return;
      if (playing) {
        _controller.play();
      } else {
        _controller.pause();
      }
    });
    _reversedPlayingSub = _reversedPlayer.stream.playing.listen((playing) {
      if (_controller.state.direction != PlaybackDirection.reversed) return;
      if (playing) {
        _controller.play();
      } else {
        _controller.pause();
      }
    });

    _forwardBufferingSub = _forwardPlayer.stream.buffering.listen((buffering) {
      if (_controller.state.direction != PlaybackDirection.forward) return;
      if (mounted) setState(() => _buffering = buffering);
    });
    _reversedBufferingSub = _reversedPlayer.stream.buffering.listen((buffering) {
      if (_controller.state.direction != PlaybackDirection.reversed) return;
      if (mounted) setState(() => _buffering = buffering);
    });

    _initPlayers();
    _loadAnnotationsAndProfile();
  }

  // Configure MPV to buffer aggressively so temporary network stalls are
  // absorbed by the cache rather than reported as EOF mid-playback.
  Future<void> _configureMpvForStreaming(Player player) async {
    if (kIsWeb) return;
    try {
      // NativePlayer.setProperty exists at runtime on Android/desktop but the
      // pub stub doesn't declare it, so we use dynamic dispatch to avoid the
      // static type error. The try-catch handles platforms without the method.
      final dynamic native = player.platform;
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '15');
      await native.setProperty('demuxer-max-bytes', '15728640'); // 15 MB
      await native.setProperty('network-timeout', '20');
    } catch (_) {}
  }

  Future<void> _initPlayers() async {
    if (kIsWeb) {
      final type = getWebConnectionType();
      if (type != null) {
        // Network Information API available (Chrome/Edge) — trust it directly.
        _useMobileQuality = type == 'cellular';
      } else {
        // API absent (Firefox/Safari) — fall back to screen width as a proxy.
        final view = WidgetsBinding.instance.platformDispatcher.implicitView!;
        final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
        _useMobileQuality = logicalWidth < 600;
      }
    } else {
      final result = await Connectivity().checkConnectivity();
      _useMobileQuality = !result.contains(ConnectivityResult.wifi) &&
          !result.contains(ConnectivityResult.ethernet);
    }

    if (!mounted) return;
    final forwardUrl = _useMobileQuality
        ? widget.provider.forwardMobileUrl(widget.trickId)
        : widget.provider.forwardUrl(widget.trickId);

    await _configureMpvForStreaming(_forwardPlayer);
    _forwardPlayer.open(Media(forwardUrl.toString()), play: true);
    _forwardPlayer.setPlaylistMode(PlaylistMode.loop);
    _controller.play();
    // Reversed video is opened lazily on first direction toggle to save mobile bandwidth.
  }

  Future<void> _loadAnnotationsAndProfile() async {
    final language = WidgetsBinding
        .instance.platformDispatcher.locale.languageCode;
    final annotationsFuture =
        AnnotationsService.getForTrick(widget.trickId, language);
    final profileFuture = AuthService.getCurrentProfile();
    final annotations = await annotationsFuture;
    final profile = await profileFuture;
    if (mounted) {
      setState(() {
        _annotations = annotations;
        _isEditor = profile?.canEditTricks == true;
      });
    }
  }

  @override
  void dispose() {
    _forwardPositionSub.cancel();
    _reversedPositionSub.cancel();
    _durationSub.cancel();
    _forwardPlayingSub.cancel();
    _reversedPlayingSub.cancel();
    _forwardBufferingSub.cancel();
    _reversedBufferingSub.cancel();
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

  Future<void> _togglePlayPause() async {
    if (_controller.state.isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  Future<void> _setSpeed(double speed) async {
    _controller.setSpeed(speed);
    await _forwardPlayer.setRate(speed);
    await _reversedPlayer.setRate(speed);
  }

  Future<void> _toggleDirection() async {
    await _activePlayer.pause();
    _controller.toggleDirection();

    if (_controller.state.direction == PlaybackDirection.reversed && !_reversedLoaded) {
      _reversedLoaded = true;
      final reversedUrl = _useMobileQuality
          ? widget.provider.reversedMobileUrl(widget.trickId)
          : widget.provider.reversedUrl(widget.trickId);
      await _configureMpvForStreaming(_reversedPlayer);
      await _reversedPlayer.open(Media(reversedUrl.toString()), play: false);
      await _reversedPlayer.setPlaylistMode(PlaylistMode.loop);
    }

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

  void _showAnnotationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text('Annotations',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text('Add at ${_fmt(_controller.state.position)}'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddAnnotationDialog();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_annotations.isEmpty)
              const Expanded(child: Center(child: Text('No annotations yet')))
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _annotations.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final a = _annotations[i];
                    return ListTile(
                      title: Text(a.text),
                      subtitle: Text(
                          '${_fmt(Duration(milliseconds: a.startMs))} – ${_fmt(Duration(milliseconds: a.endMs))}'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _setSpeed(0.25);
                        final pos = Duration(milliseconds: a.startMs);
                        _controller.updatePosition(pos);
                        _activePlayer.seek(_controller.state.fileSeekPosition);
                        _play();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditAnnotationDialog(a);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () async {
                              await AnnotationsService.delete(a.id);
                              if (mounted) {
                                setState(() => _annotations
                                    .removeWhere((x) => x.id == a.id));
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _kLanguages = [
    ('en', 'English'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('pt', 'Portuguese'),
    ('it', 'Italian'),
    ('ja', 'Japanese'),
    ('zh', 'Chinese'),
  ];

  Future<void> _showAddAnnotationDialog() async {
    final totalMs = _controller.state.totalDuration.inMilliseconds;
    final startMs = _controller.state.position.inMilliseconds;
    final endMs = (startMs + 2000).clamp(0, totalMs);
    final result = await _showAnnotationDialog(
        startMs: startMs, endMs: endMs, text: '', language: 'en');
    if (result == null || !mounted) return;
    final annotation = await AnnotationsService.create(
      trickId: widget.trickId,
      startMs: result.$1,
      endMs: result.$2,
      text: result.$3,
      language: result.$4,
    );
    if (mounted) {
      setState(() {
        _annotations = [..._annotations, annotation]
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
      });
    }
  }

  Future<void> _showEditAnnotationDialog(TrickAnnotation annotation) async {
    final result = await _showAnnotationDialog(
      startMs: annotation.startMs,
      endMs: annotation.endMs,
      text: annotation.text,
      language: annotation.language,
    );
    if (result == null || !mounted) return;
    final updated = await AnnotationsService.update(
      annotation.id,
      startMs: result.$1,
      endMs: result.$2,
      text: result.$3,
      language: result.$4,
    );
    if (mounted) {
      setState(() {
        _annotations =
            _annotations.map((a) => a.id == annotation.id ? updated : a).toList();
      });
    }
  }

  Future<(int, int, String, String)?> _showAnnotationDialog({
    required int startMs,
    required int endMs,
    required String text,
    required String language,
  }) {
    final textCtrl = TextEditingController(text: text);
    final startCtrl =
        TextEditingController(text: (startMs / 1000).toStringAsFixed(2));
    final endCtrl =
        TextEditingController(text: (endMs / 1000).toStringAsFixed(2));
    String selectedLanguage = _kLanguages.any((l) => l.$1 == language)
        ? language
        : 'en';

    return showDialog<(int, int, String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(text.isEmpty ? 'Add Annotation' : 'Edit Annotation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                    labelText: 'Text', border: OutlineInputBorder()),
                autofocus: true,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Start (s)',
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                          labelText: 'End (s)', border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedLanguage,
                decoration: const InputDecoration(
                    labelText: 'Language', border: OutlineInputBorder()),
                items: _kLanguages
                    .map((l) => DropdownMenuItem(
                          value: l.$1,
                          child: Text(l.$2),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => selectedLanguage = v ?? 'en'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final t = textCtrl.text.trim();
                if (t.isEmpty) return;
                final s =
                    ((double.tryParse(startCtrl.text) ?? 0) * 1000).round();
                final e =
                    ((double.tryParse(endCtrl.text) ?? 0) * 1000).round();
                Navigator.pop(ctx, (s, e, t, selectedLanguage));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: context.canPop() ? 96 : 48,
        leading: const BackHomeLeading(showHome: true),
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
            if (!_loading && _buffering)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (kDebugMode && !_loading)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _useMobileQuality ? 'mobile' : 'full',
                    style: TextStyle(
                      color: _useMobileQuality ? Colors.orange : Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
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
    final isForward = _controller.state.direction == PlaybackDirection.forward;
    final position = _controller.state.position;

    final videoStack = GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        children: [
          Offstage(
            offstage: !isForward,
            child: Video(controller: _forwardVideoController, controls: null, fit: BoxFit.fitHeight),
          ),
          Offstage(
            offstage: isForward,
            child: Video(controller: _reversedVideoController, controls: null, fit: BoxFit.fitHeight),
          ),
        ],
      ),
    );

    if (_annotations.isEmpty) return videoStack;

    void onAnnotationTap(TrickAnnotation a) {
      _setSpeed(0.25);
      _controller.updatePosition(Duration(milliseconds: a.startMs));
      _activePlayer.seek(_controller.state.fileSeekPosition);
      _play();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 360 (sidebar) + a minimum usable video width — overlay on narrow screens.
        const kBreakpoint = 1280.0;

        if (constraints.maxWidth < kBreakpoint) {
          return Stack(
            children: [
              Positioned.fill(child: videoStack),
              Positioned(
                top: 16,
                right: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight - 32),
                  child: _MobileAnnotationOverlay(
                    annotations: _annotations,
                    position: position,
                    onTap: onAnnotationTap,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: videoStack),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _AnnotationSidebar(
                annotations: _annotations,
                position: position,
                onTap: onAnnotationTap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    final state = _controller.state;
    final totalMs = state.totalDuration.inMilliseconds;
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: canAct ? _onScrub : null,
                      ),
                    ),
                    if (_annotations.isNotEmpty && totalMs > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _AnnotationDotPainter(
                              annotations: _annotations,
                              totalMs: totalMs,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
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
              if (_isEditor)
                IconButton(
                  icon: const Icon(Icons.comment_outlined, color: Colors.white),
                  tooltip: 'Manage annotations',
                  onPressed: canAct ? _showAnnotationsSheet : null,
                ),
              DropdownButton<double>(
                value: state.speed,
                dropdownColor: Colors.black87,
                underline: const SizedBox.shrink(),
                iconEnabledColor: Colors.white54,
                alignment: Alignment.center,
                items: const [
                  DropdownMenuItem(value: 0.25, alignment: Alignment.center, child: Text('0.25x', style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 0.5,  alignment: Alignment.center, child: Text('0.5x',  style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 0.75, alignment: Alignment.center, child: Text('0.75x', style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 1.0,  alignment: Alignment.center, child: Text('1x',    style: TextStyle(color: Colors.white, fontSize: 13))),
                ],
                onChanged: canAct ? (v) { if (v != null) _setSpeed(v); } : null,
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

class _AnnotationDotPainter extends CustomPainter {
  final List<TrickAnnotation> annotations;
  final int totalMs;
  final Color color;

  // Flutter's default RoundSliderOverlayShape has overlayRadius 12, which
  // becomes the horizontal inset of the track inside the Slider widget.
  static const double _trackPadding = 12.0;
  static const double _dotRadius = 4.0;

  const _AnnotationDotPainter({
    required this.annotations,
    required this.totalMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMs == 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final trackWidth = size.width - _trackPadding * 2;
    final centerY = size.height / 2;
    for (final a in annotations) {
      final x = (_trackPadding + a.startMs / totalMs * trackWidth)
          .clamp(_trackPadding, size.width - _trackPadding);
      canvas.drawCircle(Offset(x, centerY), _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_AnnotationDotPainter old) =>
      annotations != old.annotations || totalMs != old.totalMs;
}

class _AnnotationSidebar extends StatefulWidget {
  final List<TrickAnnotation> annotations;
  final Duration position;
  final void Function(TrickAnnotation) onTap;

  const _AnnotationSidebar({
    required this.annotations,
    required this.position,
    required this.onTap,
  });

  @override
  State<_AnnotationSidebar> createState() => _AnnotationSidebarState();
}

class _AnnotationSidebarState extends State<_AnnotationSidebar> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.annotations]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _expanded ? 288 : 43,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _expanded ? _buildExpanded(sorted) : _buildCollapsed(),
      ),
    );
  }

  Widget _buildCollapsed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white54),
          iconSize: 24,
          padding: EdgeInsets.zero,
          tooltip: 'Show annotations',
          onPressed: () => setState(() => _expanded = true),
        ),
      ],
    );
  }

  Widget _buildExpanded(List<TrickAnnotation> sorted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 5, 5),
          child: Row(
            children: [
              const Text(
                'ANNOTATIONS',
                style: TextStyle(
                    color: Colors.white38, fontSize: 12, letterSpacing: 1.2),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white38),
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Hide annotations',
                onPressed: () => setState(() => _expanded = false),
              ),
            ],
          ),
        ),
        Builder(builder: (context) {
            final activeId = sorted
                .where((a) => a.isActiveAt(widget.position))
                .fold<TrickAnnotation?>(
                  null,
                  (best, a) =>
                      best == null || a.startMs >= best.startMs ? a : best,
                )
                ?.id;
            return ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: sorted.length,
            separatorBuilder: (context, i) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, i) {
              final a = sorted[i];
              final isActive = a.id == activeId;
              return GestureDetector(
                onTap: () => widget.onTap(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.text,
                        style: TextStyle(
                          color: isActive ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtMs(a.startMs)} – ${_fmtMs(a.endMs)}',
                        style: TextStyle(
                          color: isActive
                              ? Colors.black.withValues(alpha: 0.7)
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          }),
      ],
    );
  }

  static String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _MobileAnnotationOverlay extends StatefulWidget {
  final List<TrickAnnotation> annotations;
  final Duration position;
  final void Function(TrickAnnotation) onTap;

  const _MobileAnnotationOverlay({
    required this.annotations,
    required this.position,
    required this.onTap,
  });

  @override
  State<_MobileAnnotationOverlay> createState() => _MobileAnnotationOverlayState();
}

class _MobileAnnotationOverlayState extends State<_MobileAnnotationOverlay> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.annotations]..sort((a, b) => a.startMs.compareTo(b.startMs));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _expanded ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          clipBehavior: Clip.hardEdge,
          child: _expanded
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final a in sorted)
                        _MobileAnnotationChip(
                          annotation: a,
                          isActive: a.isActiveAt(widget.position),
                          onTap: () => widget.onTap(a),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _MobileAnnotationChip extends StatelessWidget {
  final TrickAnnotation annotation;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileAnnotationChip({
    required this.annotation,
    required this.isActive,
    required this.onTap,
  });

  static String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isActive ? Colors.black : Colors.white;
    final timeColor = isActive ? Colors.black54 : Colors.white38;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  annotation.text,
                  maxLines: isActive ? null : 2,
                  overflow: isActive ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_fmtMs(annotation.startMs)} – ${_fmtMs(annotation.endMs)}',
                  style: TextStyle(color: timeColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

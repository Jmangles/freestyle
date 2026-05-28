import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../constants/layout_constants.dart';
import '../constants/playback_constants.dart';
import '../utils/date_formatters.dart';
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
import '../widgets/annotation_widgets.dart';
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
  late final StreamSubscription<bool> _forwardCompletedSub;
  late final StreamSubscription<bool> _reversedCompletedSub;
  late final StreamSubscription<bool> _forwardPlayingSub;
  late final StreamSubscription<bool> _reversedPlayingSub;
  late final StreamSubscription<bool> _forwardBufferingSub;
  late final StreamSubscription<bool> _reversedBufferingSub;

  bool _loading = true;
  double? _downloadProgress; // null = indeterminate, 0.0–1.0 = known
  bool _buffering = false;
  bool _reversedLoaded = false;
  bool _useMobileQuality = false;
  bool _forwardLooping = false;
  bool _reversedLooping = false;
  DateTime? _lastForwardCompletedAt;
  DateTime? _lastReversedCompletedAt;
  List<TrickAnnotation> _annotations = [];
  bool _isEditor = false;

  // Debug counters — only populated in debug mode.
  int _dbgFwdFired = 0;
  int _dbgFwdFalseEof = 0;
  int _dbgFwdRealEof = 0;
  int _dbgFwdDebounced = 0;
  final List<String> _dbgLog = [];

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

    // Manual looping so the playback rate is preserved on each cycle.
    // PlaylistMode.loop is not used because libmpv loops the demuxer (when it
    // finishes reading the network stream) rather than the renderer (when the
    // last frame is displayed), causing early loops on Android.
    // keep-open=yes makes libmpv pause instead of stop at EOF, so buffered
    // frames past the network EOF can still be displayed before we loop.
    //
    // False-EOF detection: if completed fires while position is still far from
    // the end, the demuxer finished downloading before the renderer caught up —
    // call play() to drain the buffer.  1-second threshold (instead of a
    // shorter value) covers Android's position-stream staleness: the stream can
    // lag ~500 ms behind the renderer, so a 300 ms window was insufficient and
    // the renderer's true EOF was mis-classified as false EOF.
    //
    // Debounce: calling play() at a keep-open EOF causes an immediate
    // re-completion event.  We collapse any bursts within kEofDebounce so the
    // first event drives the decision and subsequent ones are ignored.
    _forwardCompletedSub = _forwardPlayer.stream.completed.listen((done) {
      if (!done || _forwardLooping) return;
      final total = _controller.state.totalDuration;
      if (total < kEofTolerance) return;
      final now = DateTime.now();
      // ctrlPos  = last value our stream subscription recorded (may be stale).
      // playerPos = value held directly in the Player object (updated first).
      // Logging both reveals whether position-stream staleness is the culprit.
      final ctrlPos   = _controller.state.position;
      final playerPos = _forwardPlayer.state.position;
      if (_lastForwardCompletedAt != null &&
          now.difference(_lastForwardCompletedAt!) < kEofDebounce) {
        if (kDebugMode) {
          _dbgFwdDebounced++;
          _dbgEvent('FWD debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}');
        }
        return;
      }
      _lastForwardCompletedAt = now;
      if (kDebugMode) _dbgFwdFired++;
      if (ctrlPos < total - kEofTolerance) {
        if (kDebugMode) {
          _dbgFwdFalseEof++;
          _dbgEvent('FWD false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');
        }
        // False EOF — demuxer hit network EOF but buffered frames remain.
        _forwardPlayer.play();
        return;
      }
      if (kDebugMode) {
        _dbgFwdRealEof++;
        _dbgEvent('FWD real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');
      }
      _forwardLooping = true;
      _forwardPlayer.seek(Duration.zero).then((_) {
        if (!mounted) return;
        _forwardPlayer.setRate(_controller.state.speed);
        _forwardPlayer.play();
      });
    });
    _reversedCompletedSub = _reversedPlayer.stream.completed.listen((done) {
      if (!done || _reversedLooping) return;
      final total = _controller.state.totalDuration;
      if (total < kEofTolerance) return;
      final now = DateTime.now();
      final ctrlPos   = _controller.state.position;
      final playerPos = _reversedPlayer.state.position;
      if (_lastReversedCompletedAt != null &&
          now.difference(_lastReversedCompletedAt!) < kEofDebounce) {
        if (kDebugMode) _dbgEvent('REV debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}');
        return;
      }
      _lastReversedCompletedAt = now;
      // For the reversed file, filePos = total − trickTime, so real EOF is
      // trickTime ≈ 0.  False EOF is trickTime > kEofTolerance (file still far from end).
      if (ctrlPos > kEofTolerance) {
        if (kDebugMode) _dbgEvent('REV false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');
        // False EOF — demuxer hit network EOF but buffered frames remain.
        _reversedPlayer.play();
        return;
      }
      if (kDebugMode) _dbgEvent('REV real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');
      _reversedLooping = true;
      _reversedPlayer.seek(Duration.zero).then((_) {
        if (!mounted) return;
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
      final prev = _controller.state.position;
      if (!_forwardLooping &&
          prev > kJumpMinPrev &&
          pos < prev - kEofDebounce) {
        final total = _controller.state.totalDuration;
        final isEofLoop = total > Duration.zero &&
            prev >= total - kEofTolerance &&
            pos < kNearStartThreshold;
        if (isEofLoop) {
          // keep-open reset position before our completed handler ran; claim
          // the loop now so the pending completed event exits early.
          _forwardLooping = true;
        }
        if (kDebugMode) {
          _dbgEvent('POS↩ ${prev.inMilliseconds}→${pos.inMilliseconds}ms'
              ' player=${_forwardPlayer.state.position.inMilliseconds}ms'
              ' loop=$_forwardLooping eofLoop=$isEofLoop');
        }
      }
      if (_forwardLooping && pos > kLoopClearThreshold) {
        _forwardLooping = false;
      }
      _controller.updatePosition(pos);
      if (mounted) setState(() {});
    });

    // Reversed file position must be mirrored to get trick time.
    _reversedPositionSub = _reversedPlayer.stream.position.listen((pos) {
      if (_controller.state.direction != PlaybackDirection.reversed) return;
      if (_controller.state.totalDuration == Duration.zero) return;
      if (_reversedLooping && pos > kLoopClearThreshold) {
        _reversedLooping = false;
      }
      _controller.updatePosition(_controller.state.totalDuration - pos);
      if (mounted) setState(() {});
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Sync controller play/pause state from the actual player so that browser
    // autoplay blocks (fresh page loads) are reflected in the UI correctly.
    _forwardPlayingSub = _forwardPlayer.stream.playing.listen((playing) {
      if (kDebugMode) {
        _dbgEvent('FWD playing=$playing pos=${_controller.state.position.inMilliseconds}ms'
            ' fwdLoop=$_forwardLooping');
      }
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
      await native.setProperty('demuxer-max-bytes', kMpvCacheBytes);
      await native.setProperty('demuxer-max-back-bytes', kMpvCacheBytes); // seek(0) on loop served from memory
      await native.setProperty('cache-pause', 'yes');   // stall instead of false-EOF when buffer runs dry mid-stream
      await native.setProperty('keep-open', 'yes');     // pause at EOF instead of stopping
      await native.setProperty('network-timeout', kMpvNetworkTimeout);
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
        _useMobileQuality = logicalWidth < kMobileWidthBreakpoint;
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

    // On Android/desktop: download the video to a local temp file before
    // opening the player.  Playing from a local file eliminates a class of
    // libmpv-on-Android bugs where the player silently resets position to 0
    // whenever the HTTP demuxer reaches network EOF (i.e. once the file finishes
    // downloading), causing early loops that don't fire the `completed` event.
    // The loading indicator is already showing, so the download happens behind
    // the spinner.  Falls back to the remote URL if the download fails.
    final forwardPath = kIsWeb
        ? forwardUrl.toString()
        : await _downloadToTemp(
            forwardUrl.toString(),
            onProgress: (p) { if (mounted) setState(() => _downloadProgress = p); },
          );
    if (!mounted) return;
    await _configureMpvForStreaming(_forwardPlayer);
    _forwardPlayer.open(Media(forwardPath), play: true);
    _controller.play();
    // Reversed video is opened lazily on first direction toggle to save mobile bandwidth.
  }

  /// Returns a local path for [url], downloading only if not already cached.
  /// Uses the app cache directory so files survive across sessions.
  /// Returns [url] unchanged on any error so streaming acts as a fallback.
  Future<String> _downloadToTemp(String url, {void Function(double)? onProgress}) async {
    try {
      final dir = await getApplicationCacheDirectory();
      final path = '${dir.path}/ts_${url.hashCode.abs()}.mp4';
      final file = File(path);
      if (await file.exists() && await file.length() > 0) return path;
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) return url;
        final total = response.contentLength; // -1 if server omits Content-Length
        final sink = file.openWrite();
        int received = 0;
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 && onProgress != null) onProgress(received / total);
        }
        await sink.close();
        return path;
      } finally {
        client.close();
      }
    } catch (e, st) {
      debugPrint('TrainingStudio._downloadToTemp failed, falling back to stream: $e\n$st');
      return url;
    }
  }

  Future<void> _loadAnnotationsAndProfile() async {
    try {
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
    } catch (e, st) {
      debugPrint('TrainingStudio._loadAnnotationsAndProfile: $e\n$st');
      // Annotations are non-critical — the player continues working without them.
    }
  }

  @override
  void dispose() {
    _forwardPositionSub.cancel();
    _reversedPositionSub.cancel();
    _durationSub.cancel();
    _forwardCompletedSub.cancel();
    _reversedCompletedSub.cancel();
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
      final reversedPath = kIsWeb
          ? reversedUrl.toString()
          : await _downloadToTemp(reversedUrl.toString());
      await _configureMpvForStreaming(_reversedPlayer);
      await _reversedPlayer.open(Media(reversedPath), play: false);
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
                    label: Text('Add at ${formatDuration(_controller.state.position)}'),
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
                          '${formatDuration(Duration(milliseconds: a.startMs))} – ${formatDuration(Duration(milliseconds: a.endMs))}'),
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
    final endMs = (startMs + kAnnotationDefaultDurationMs).clamp(0, totalMs);
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
                  ? Center(child: CircularProgressIndicator(value: _downloadProgress))
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
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1 — quality + live position from both sources
                        Text(
                          '${_useMobileQuality ? 'MOBILE' : 'FULL'}'
                          '  ctrl=${_controller.state.position.inMilliseconds}ms'
                          '  player=${_forwardPlayer.state.position.inMilliseconds}ms'
                          '  total=${_controller.state.totalDuration.inMilliseconds}ms',
                          style: TextStyle(
                            color: _useMobileQuality ? Colors.orange : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Row 2 — playback state flags
                        Text(
                          '${_controller.state.isPlaying ? 'PLAYING' : 'paused'}'
                          '  ${_buffering ? 'BUFFERING' : 'buf-ok'}'
                          '  fwdLoop=$_forwardLooping'
                          '  revLoop=$_reversedLooping',
                        ),
                        // Row 3 — completed-event counters
                        Text(
                          'completed: fired=$_dbgFwdFired'
                          '  falseEOF=$_dbgFwdFalseEof'
                          '  realEOF=$_dbgFwdRealEof'
                          '  debounced=$_dbgFwdDebounced',
                        ),
                        // Rolling event log (newest at top)
                        if (_dbgLog.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final line in _dbgLog.reversed)
                            Text(line, style: const TextStyle(color: Colors.white54)),
                        ],
                      ],
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
        if (constraints.maxWidth < kAnnotationSidebarBreakpoint) {
          return Stack(
            children: [
              Positioned.fill(child: videoStack),
              Positioned(
                top: 16,
                right: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight - 32),
                  child: MobileAnnotationOverlay(
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
              child: AnnotationSidebar(
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
                            painter: AnnotationDotPainter(
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
                  '${formatDuration(state.position)} / ${formatDuration(state.totalDuration)}',
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

  void _dbgEvent(String msg) {
    final ts = DateTime.now();
    final entry = '${ts.second.toString().padLeft(2,'0')}.${ts.millisecond.toString().padLeft(3,'0')} $msg';
    _dbgLog.add(entry);
    if (_dbgLog.length > 12) _dbgLog.removeAt(0);
    debugPrint('[TS] $msg');
    if (mounted) setState(() {});
  }
}

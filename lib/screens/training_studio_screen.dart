import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../constants/playback_constants.dart';
import '../utils/network_utils.dart';
import '../utils/connection_speed.dart';
import '../utils/web_connection.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/trick_annotation.dart';
import '../services/annotations_service.dart';
import '../services/auth_service.dart';
import '../video/mpv_config.dart';
import '../video/offline_video_service.dart';
import '../video/training_video_controller.dart';
import '../video/video_provider.dart';
import '../video/video_quality_resolver.dart';
import '../video/web_video_cache.dart';
import '../utils/safe_state.dart';
import '../widgets/back_home_leading.dart';
import '../widgets/training_studio_controls.dart';
import '../widgets/training_studio_debug_overlay.dart';
import '../widgets/training_studio_video_area.dart';
import 'training_studio_dialogs.dart';

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

class _TrainingStudioScreenState extends State<TrainingStudioScreen>
    with SafeStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  late final TrainingVideoController _controller;

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _completedSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<bool> _bufferingSub;

  bool _loading = true;
  double? _downloadProgress; // null = indeterminate, 0.0–1.0 = known
  bool _buffering = false;
  bool _useMobileQuality = false;
  bool _looping = false;
  DateTime? _lastCompletedAt;
  List<TrickAnnotation> _annotations = [];
  bool _isEditor = false;

  // Snapshot of offline state taken once at player-init time. Used only for
  // quality-selection logic and the debug overlay.
  bool _isOfflineAtInit = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _forwardSaved = false;
  // Non-null when the forward video was downloaded to app cache and can be saved permanently.
  String? _forwardCachePath;
  String _forwardFilename = kForwardVideo;
  bool _saving = false;
  bool _cancelForwardDownload = false;
  // True from open() until the first playing=true event, so that any
  // playing=false fired during blob-URL initialisation triggers a re-play.
  bool _awaitingWebAutoplay = false;
  String? _initError;

  // Debug counters/info — only populated in debug mode.
  String _dbgQualityInfo = '';
  int _dbgFwdFalseEof = 0;
  int _dbgFwdRealEof = 0;
  int _dbgFwdDebounced = 0;
  int get _dbgFwdFired => _dbgFwdFalseEof + _dbgFwdRealEof;
  final List<String> _dbgLog = [];

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _controller = TrainingVideoController(
      provider: widget.provider,
      trickId: widget.trickId,
    );
    _controller.addListener(() {
      safeSetState(() {});
    });

    _setupSubscriptions();

    if (!kIsWeb) {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        setDeviceConnectivity(results);
        safeSetState(() {});
      });
    }

    _initPlayers();
    _loadAnnotationsAndProfile();
  }

  void _setupSubscriptions() {
    _completedSub = _player.stream.completed.listen(_onCompleted);
    _durationSub = _player.stream.duration.listen(_onDuration);
    _positionSub = _player.stream.position.listen(_onPosition);
    _playingSub = _player.stream.playing.listen(_onPlaying);
    _bufferingSub = _player.stream.buffering.listen(_onBuffering);
  }

  // Manual looping so the playback rate is preserved on each cycle.
  // PlaylistMode.loop is not used because libmpv loops the demuxer (when it
  // finishes reading the network stream) rather than the renderer (when the
  // last frame is displayed), causing early loops on Android.
  // keep-open=yes makes libmpv pause instead of stop at EOF, so buffered
  // frames past the network EOF can still be displayed before we loop.
  //
  // False-EOF detection: if completed fires while position is still far from
  // the end, the demuxer finished downloading before the renderer caught up —
  // call play() to drain the buffer. 1-second threshold (instead of a
  // shorter value) covers Android's position-stream staleness: the stream can
  // lag ~500 ms behind the renderer, so a 300 ms window was insufficient and
  // the renderer's true EOF was mis-classified as false EOF.
  //
  // Debounce: calling play() at a keep-open EOF causes an immediate
  // re-completion event. We collapse any bursts within kEofDebounce so the
  // first event drives the decision and subsequent ones are ignored.
  void _onCompleted(bool done) {
    if (!done || _looping) return;

    final total = _controller.state.totalDuration;

    if (total < kEofTolerance) return;

    final now = DateTime.now();
    final ctrlPos = _controller.state.position;
    final playerPos = _player.state.position;

    if (_lastCompletedAt != null &&
        now.difference(_lastCompletedAt!) < kEofDebounce) {
      _dbgEvent(
          'FWD debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}',
          _DbgCounter.fwdDebounced);
      return;
    }

    _lastCompletedAt = now;

    if (ctrlPos < total - kEofTolerance) {
      _dbgEvent(
          'FWD false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
          _DbgCounter.fwdFalseEof);
      // False EOF — demuxer hit network EOF but buffered frames remain.
      _player.play();
      return;
    }

    _dbgEvent(
        'FWD real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
        _DbgCounter.fwdRealEof);

    _looping = true;
    _player.seek(Duration.zero).then((_) {
      if (!mounted) return;
      _player.setRate(_controller.state.speed);
      _player.play();
    });
  }

  void _onDuration(Duration duration) {
    if (duration <= Duration.zero) return;

    _controller.setDuration(duration);

    if (!mounted) return;

    setState(() => _loading = false);

    // On web, play:true in open() can lose a race against the duration event
    // with local blob URLs. Nudge play immediately, then once more after a short
    // delay to cover the case where play() is silently absorbed with no events.
    if (kIsWeb) {
      _player.play();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _awaitingWebAutoplay) _player.play();
      });
    }
  }

  void _onPosition(Duration pos) {
    final prev = _controller.state.position;
    if (!_looping && prev > kJumpMinPrev && pos < prev - kEofDebounce) {
      final total = _controller.state.totalDuration;
      final isEofLoop = total > Duration.zero &&
          prev >= total - kEofTolerance &&
          pos < kNearStartThreshold;
      if (isEofLoop) {
        _looping = true;
      }
      _dbgEvent('POS↩ ${prev.inMilliseconds}→${pos.inMilliseconds}ms'
          ' player=${_player.state.position.inMilliseconds}ms'
          ' loop=$_looping eofLoop=$isEofLoop');
    }
    if (_looping && pos > kLoopClearThreshold) {
      _looping = false;
    }
    // Position advancing is the reliable signal that autoplay actually worked.
    if (kIsWeb &&
        _awaitingWebAutoplay &&
        pos > const Duration(milliseconds: 200)) {
      _awaitingWebAutoplay = false;
    }
    _controller.updatePosition(pos);
    safeSetState(() {});
  }

  void _onPlaying(bool playing) {
    _dbgEvent(
        'FWD playing=$playing pos=${_controller.state.position.inMilliseconds}ms'
        ' loop=$_looping');
    if (kIsWeb) {
      // Don't clear on playing=true — it can fire briefly before the player
      // settles back to false. Cleared by position advancement instead.
      if (!playing && _awaitingWebAutoplay) {
        _player.play();
      }
    }
    if (playing) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  void _onBuffering(bool buffering) {
    safeSetState(() => _buffering = buffering);
  }

  Future<void> _initPlayers() async {
    bool isWifi = false;

    if (!kIsWeb) {
      final result = await Connectivity().checkConnectivity();

      _isOfflineAtInit = result.every((r) => r == ConnectivityResult.none);

      setDeviceConnectivity(result);

      isWifi = !_isOfflineAtInit &&
          (result.contains(ConnectivityResult.wifi) ||
              result.contains(ConnectivityResult.ethernet));

      _useMobileQuality = !isWifi && !_isOfflineAtInit;
    }

    if (!mounted) return;

    String forwardPath;

    if (!kIsWeb) {
      final fwdExists =
          await OfflineVideoService.videoExists(widget.trickId, kForwardVideo);
      final fwdMobileExists = await OfflineVideoService.videoExists(
          widget.trickId, kForwardMobileVideo);

      if (!mounted) return;

      setState(() {
        _forwardSaved = fwdExists || fwdMobileExists;
      });

      final resolved = await resolveNativeForwardPath(VideoResolutionContext(
        trickId: widget.trickId,
        provider: widget.provider,
        isWifi: isWifi,
        isOffline: _isOfflineAtInit,
        fwdExists: fwdExists,
        fwdMobileExists: fwdMobileExists,
        isCancelled: () => _cancelForwardDownload,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
        isMounted: () => mounted,
      ));

      if (!mounted) return;

      if (resolved == null) {
        setState(() {
          _loading = false;
          _initError = 'No saved video available offline.';
        });
        return;
      }

      forwardPath = resolved.path;
      _forwardFilename = resolved.filename;
      _useMobileQuality = resolved.useMobileQuality;
      _forwardCachePath = resolved.cachePath;

      if (resolved.startQualityUpgrade) {
        unawaited(_startQualityUpgrade());
      }
    } else {
      // Web — check session cache before quality detection so quality stays
      // consistent across visits and the speed test doesn't re-run needlessly.
      _isOfflineAtInit = false;
      final fullKey = '${widget.trickId}_full';
      final mobileKey = '${widget.trickId}_mobile';
      final preCached = getCachedWebVideo(fullKey, mobileKey);

      if (preCached != null) {
        forwardPath = preCached.url;
        _useMobileQuality = preCached.isMobile;
        _forwardFilename =
            preCached.isMobile ? kForwardMobileVideo : kForwardVideo;
        if (kDebugMode) {
          _dbgQualityInfo =
              'sessionCache (${preCached.isMobile ? 'mobile' : 'full'})';
        }
      } else {
        if (isMobileBrowser()) {
          // Mobile browsers are limited by hardware decoding, not bandwidth —
          // the speed test can't detect this, so always serve mobile quality.
          _useMobileQuality = true;
          if (kDebugMode) _dbgQualityInfo = 'mobileBrowser';
        } else {
          final type = getWebConnectionType();
          if (type != null) {
            _useMobileQuality =
                type == 'slow-2g' || type == '2g' || type == '3g';
            if (kDebugMode) _dbgQualityInfo = 'effectiveType=$type';
          } else {
            String? speedTestError;
            final mbps = await estimateConnectionSpeedMbps(
              onError: kDebugMode ? (e) => speedTestError = e : null,
            );
            _useMobileQuality =
                mbps != null && mbps < kMobileQualityThresholdMbps;
            if (kDebugMode) {
              _dbgQualityInfo =
                  'speedTest=${mbps != null ? '${mbps.toStringAsFixed(2)}Mbps' : 'null${speedTestError != null ? ' ($speedTestError)' : ''}'}';
            }
          }
        }

        _forwardFilename =
            _useMobileQuality ? kForwardMobileVideo : kForwardVideo;
        final forwardUrl = _useMobileQuality
            ? widget.provider.forwardMobileUrl(widget.trickId)
            : widget.provider.forwardUrl(widget.trickId);
        final cacheKey = _useMobileQuality ? mobileKey : fullKey;

        final blobUrl = await downloadAndCacheWebVideo(
          forwardUrl.toString(),
          cacheKey: cacheKey,
          isCancelled: () => _cancelForwardDownload,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
          onError: kDebugMode
              ? (e) {
                  if (mounted) setState(() => _dbgQualityInfo += ' err:$e');
                }
              : null,
        );
        if (!mounted) return;
        forwardPath = blobUrl ?? forwardUrl.toString();
      }
    }

    if (!mounted) return;

    await configureMpvForStreaming(_player);

    if (!mounted) return;

    if (kIsWeb) _awaitingWebAutoplay = true;
    _player.open(Media(forwardPath), play: true);
    _controller.play();

    if (mounted) setState(() => _downloadProgress = null);
  }

  /// Silently downloads full-quality forward video to replace the mobile-quality
  /// permanent file. Intentionally unawaited; cancellable via [_cancelForwardDownload].
  Future<void> _startQualityUpgrade() async {
    if (_cancelForwardDownload) return;

    _cancelForwardDownload = false;

    try {
      final fullUrl = widget.provider.forwardUrl(widget.trickId).toString();
      
      await OfflineVideoService.downloadToPermanent(
        fullUrl,
        widget.trickId,
        kForwardVideo,
        isCancelled: () => _cancelForwardDownload,
      );
    } catch (_) {
      return;
    }

    if (!mounted || _cancelForwardDownload) return;

    try {
      await OfflineVideoService.deleteVideo(
          widget.trickId, kForwardMobileVideo);
    } catch (e) {
      debugPrint('Quality upgrade: failed to delete $kForwardMobileVideo: $e');
    }

    if (!mounted) return;

    setState(() {
      _forwardFilename = kForwardVideo;
      _useMobileQuality = false;
    });
  }

  Future<void> _saveVideo() async {
    if (_saving || _forwardCachePath == null || _forwardSaved) return;
    setState(() => _saving = true);
    try {
      final fileExists = await File(_forwardCachePath!).exists();
      if (!fileExists) {
        if (!mounted) return;

        setState(() => _forwardCachePath = null);

        showInfoSnackBar(
            'Cached video was cleared — reopen the training studio to re-download');
        return;
      }

      final sufficient = await OfflineVideoService.hasSufficientStorage();

      if (!mounted) return;

      if (!sufficient) {
        final proceed = await showStorageWarning(context);

        if (!mounted || !proceed) return;
      }

      try {
        await OfflineVideoService.saveFromCache(
            _forwardCachePath!, widget.trickId, _forwardFilename);

        if (!mounted) return;

        setState(() => _forwardSaved = true);

        OfflineVideoService.markSaved(widget.trickId);
      } catch (e) {
        showInfoSnackBar('Could not save video: $e');
      }
    } finally {
      safeSetState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteVideo() async {
    final confirmed = await showDeleteVideoDialog(context);
    if (confirmed != true || !mounted) return;

    _cancelForwardDownload = true;
    try {
      await OfflineVideoService.deleteAllVideos(widget.trickId);
      if (!mounted) return;
      setState(() {
        _forwardSaved = false;
        _forwardCachePath = null;
      });
      OfflineVideoService.markDeleted(widget.trickId);
    } catch (e) {
      showInfoSnackBar('Could not delete video: $e');
    }
    // _cancelForwardDownload is intentionally NOT reset here — see _startQualityUpgrade.
  }

  Future<void> _loadAnnotationsAndProfile() async {
    try {
      final language =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final annotationsFuture =
          AnnotationsService.getForTrick(widget.trickId, language);
      final profileFuture = AuthService.getCurrentProfile();
      final annotations = await annotationsFuture;
      final profile = await profileFuture;
      safeSetState(() {
        _annotations = annotations;
        _isEditor = profile?.canEditTricks == true;
      });
    } catch (e, st) {
      debugPrint('TrainingStudio._loadAnnotationsAndProfile: $e\n$st');
    }
  }

  Future<void> _play() async {
    _controller.play();
    await _player.play();
  }

  Future<void> _pause() async {
    _awaitingWebAutoplay = false;
    _controller.pause();
    await _player.pause();
  }

  Future<void> _restart() async {
    _controller.restart();
    await _player.seek(_controller.state.position);
    await _player.play();
  }

  Future<void> _step(void Function() move) async {
    await _player.pause();
    move();
    await _player.seek(_controller.state.position);
  }

  Future<void> _stepForward() => _step(_controller.stepForward);
  Future<void> _stepBackward() => _step(_controller.stepBackward);

  Future<void> _togglePlayPause() async {
    if (_controller.state.isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  void _seekToAnnotation(TrickAnnotation a) {
    _setSpeed(0.25);
    _controller.updatePosition(Duration(milliseconds: a.startMs));
    _player.seek(_controller.state.position);
    _play();
  }

  Future<void> _setSpeed(double speed) async {
    _controller.setSpeed(speed);
    await _player.setRate(speed);
  }

  void _onScrub(double value) {
    if (_controller.state.totalDuration == Duration.zero) return;
    final newPosition = _controller.state.totalDuration * value;
    _controller.updatePosition(newPosition);
    _player.seek(newPosition);
  }

  void _showAnnotationsSheet() {
    showAnnotationsSheet(
      context,
      annotations: _annotations,
      currentPosition: _controller.state.position,
      onAnnotationTap: _seekToAnnotation,
      onAddTapped: _showAddAnnotationDialog,
      onEditTapped: _showEditAnnotationDialog,
      onDeleteAnnotation: (a) async {
        try {
          await AnnotationsService.delete(a.id);
        } catch (e) {
          showInfoSnackBar('Could not delete annotation: $e');
          return false;
        }
        safeSetState(() => _annotations.removeWhere((x) => x.id == a.id));
        return true;
      },
    );
  }

  Future<void> _showAddAnnotationDialog() async {
    final totalMs = _controller.state.totalDuration.inMilliseconds;
    final startMs = _controller.state.position.inMilliseconds;
    final endMs = (startMs + kAnnotationDefaultDurationMs).clamp(0, totalMs);
    final result = await showAnnotationFormDialog(
      context,
      startMs: startMs,
      endMs: endMs,
      text: '',
      language: 'en',
    );
    if (result == null || !mounted) return;
    try {
      final annotation = await AnnotationsService.create(
        trickId: widget.trickId,
        startMs: result.$1,
        endMs: result.$2,
        text: result.$3,
        language: result.$4,
      );
      safeSetState(() {
        _annotations = [..._annotations, annotation]
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
      });
    } catch (e) {
      showInfoSnackBar('Could not save annotation: $e');
    }
  }

  Future<void> _showEditAnnotationDialog(TrickAnnotation annotation) async {
    final result = await showAnnotationFormDialog(
      context,
      startMs: annotation.startMs,
      endMs: annotation.endMs,
      text: annotation.text,
      language: annotation.language,
    );
    if (result == null || !mounted) return;
    try {
      final updated = await AnnotationsService.update(
        annotation.id,
        startMs: result.$1,
        endMs: result.$2,
        text: result.$3,
        language: result.$4,
      );
      safeSetState(() {
        _annotations = _annotations
            .map((a) => a.id == annotation.id ? updated : a)
            .toList();
      });
    } catch (e) {
      showInfoSnackBar('Could not save annotation: $e');
    }
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
        actions: [
          if (!kIsWeb) ...[
            if (_forwardSaved)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove from device',
                onPressed: _saving ? null : _confirmDeleteVideo,
              )
            else if (_saving)
              const SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.save_alt,
                  color: (!_loading && _forwardCachePath != null)
                      ? null
                      : Colors.white38,
                ),
                tooltip: (!_loading && _forwardCachePath != null)
                    ? 'Save to device'
                    : null,
                onPressed: (!_loading && _forwardCachePath != null)
                    ? _saveVideo
                    : null,
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _loading
                  ? Center(
                      child:
                          CircularProgressIndicator(value: _downloadProgress))
                  : _initError != null
                      ? Center(
                          child: Text(
                            _initError!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : TrainingStudioVideoArea(
                          videoController: _videoController,
                          state: _controller.state,
                          annotations: _annotations,
                          onTap: _togglePlayPause,
                          onAnnotationTap: _seekToAnnotation,
                        ),
            ),
            if (!_loading && _buffering)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (kDebugMode && !_loading)
              TrainingStudioDebugOverlay(
                state: _controller.state,
                playerPosition: _player.state.position,
                filename: _forwardFilename,
                useMobileQuality: _useMobileQuality,
                buffering: _buffering,
                looping: _looping,
                fwdFired: _dbgFwdFired,
                fwdFalseEof: _dbgFwdFalseEof,
                fwdRealEof: _dbgFwdRealEof,
                fwdDebounced: _dbgFwdDebounced,
                isOfflineAtInit: _isOfflineAtInit,
                isLiveOffline: isDeviceOffline,
                forwardSaved: _forwardSaved,
                hasCachedPath: _forwardCachePath != null,
                qualityInfo: _dbgQualityInfo,
                log: _dbgLog,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TrainingStudioControls(
                state: _controller.state,
                loading: _loading,
                hasError: _initError != null,
                isEditor: _isEditor,
                annotations: _annotations,
                onStepBackward: _stepBackward,
                onStepForward: _stepForward,
                onPlay: _play,
                onPause: _pause,
                onRestart: _restart,
                onScrub: _onScrub,
                onSetSpeed: _setSpeed,
                onShowAnnotations: _showAnnotationsSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dbgEvent(String msg, [_DbgCounter? counter]) {
    if (!kDebugMode) return;
    switch (counter) {
      case _DbgCounter.fwdFalseEof:
        _dbgFwdFalseEof++;
      case _DbgCounter.fwdRealEof:
        _dbgFwdRealEof++;
      case _DbgCounter.fwdDebounced:
        _dbgFwdDebounced++;
      case null:
        break;
    }
    final ts = DateTime.now();
    final entry =
        '${ts.second.toString().padLeft(2, '0')}.${ts.millisecond.toString().padLeft(3, '0')} $msg';
    _dbgLog.add(entry);
    if (_dbgLog.length > 12) _dbgLog.removeAt(0);
    debugPrint('[TS] $msg');
    safeSetState(() {});
  }

  @override
  void dispose() {
    _cancelForwardDownload = true;
    _connectivitySub?.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _completedSub.cancel();
    _playingSub.cancel();
    _bufferingSub.cancel();
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }
}

enum _DbgCounter { fwdFalseEof, fwdRealEof, fwdDebounced }

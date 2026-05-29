import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../constants/layout_constants.dart';
import '../constants/playback_constants.dart';
import '../utils/network_utils.dart';
import '../utils/web_connection.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/trick_annotation.dart';
import '../services/annotations_service.dart';
import '../services/auth_service.dart';
import '../video/offline_video_service.dart';
import '../video/playback_direction.dart';
import '../video/training_video_controller.dart';
import '../video/video_provider.dart';
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

  // Snapshot of offline state taken once at player-init time. Used only for
  // quality-selection logic (_resolveNativeForwardPath) and the debug overlay.
  // Live UI decisions (e.g. the reverse-button visibility) use isDeviceOffline
  // from network_utils, which is kept current by the connectivity subscription.
  bool _isOfflineAtInit = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _forwardSaved = false;
  bool _reversedSaved = false;
  // Non-null when the forward video was downloaded to app cache and can be saved permanently.
  String? _forwardCachePath;
  String _forwardFilename = kForwardVideo;
  bool _saving = false;
  bool _reversedDownloading = false;
  bool _cancelForwardDownload = false;
  bool _cancelReversedDownload = false;
  String? _initError;

  // Debug counters — only populated in debug mode.
  int _dbgFwdFalseEof = 0;
  int _dbgFwdRealEof = 0;
  int _dbgFwdDebounced = 0;
  int get _dbgFwdFired => _dbgFwdFalseEof + _dbgFwdRealEof;
  final List<String> _dbgLog = [];

  Player get _activePlayer =>
      _controller.state.direction == PlaybackDirection.forward
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
    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _setupSubscriptions();

    if (!kIsWeb) {
      // Updates the global isDeviceOffline flag and triggers a rebuild so
      // live UI decisions (e.g. reverse-button visibility) react immediately.
      // Pending-writes flushing on reconnect is handled separately by
      // main_shell.dart's own connectivity subscription — no overlap here.
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        setDeviceConnectivity(results);
        if (mounted) setState(() {});
      });
    }

    _initPlayers();
    _loadAnnotationsAndProfile();
  }

  void _setupSubscriptions() {
    _forwardCompletedSub =
        _forwardPlayer.stream.completed.listen(_onForwardCompleted);
    _reversedCompletedSub =
        _reversedPlayer.stream.completed.listen(_onReversedCompleted);
    // Duration only needs to come from one file — both are the same length.
    _durationSub = _forwardPlayer.stream.duration.listen(_onDuration);
    _forwardPositionSub =
        _forwardPlayer.stream.position.listen(_onForwardPosition);
    _reversedPositionSub =
        _reversedPlayer.stream.position.listen(_onReversedPosition);
    _forwardPlayingSub =
        _forwardPlayer.stream.playing.listen(_onForwardPlaying);
    _reversedPlayingSub =
        _reversedPlayer.stream.playing.listen(_onReversedPlaying);
    _forwardBufferingSub =
        _forwardPlayer.stream.buffering.listen(_onForwardBuffering);
    _reversedBufferingSub =
        _reversedPlayer.stream.buffering.listen(_onReversedBuffering);
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
  void _onForwardCompleted(bool done) {
    if (!done || _forwardLooping) return;

    final total = _controller.state.totalDuration;

    if (total < kEofTolerance) return;

    final now = DateTime.now();
    // ctrlPos  = last value our stream subscription recorded (may be stale).
    // playerPos = value held directly in the Player object (updated first).
    // Logging both reveals whether position-stream staleness is the culprit.
    final ctrlPos = _controller.state.position;
    final playerPos = _forwardPlayer.state.position;

    if (_lastForwardCompletedAt != null &&
        now.difference(_lastForwardCompletedAt!) < kEofDebounce) {
      _dbgEvent(
          'FWD debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}',
          _DbgCounter.fwdDebounced);
      return;
    }

    _lastForwardCompletedAt = now;

    if (ctrlPos < total - kEofTolerance) {
      _dbgEvent(
          'FWD false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
          _DbgCounter.fwdFalseEof);
      // False EOF — demuxer hit network EOF but buffered frames remain.
      _forwardPlayer.play();
      return;
    }

    _dbgEvent(
        'FWD real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}',
        _DbgCounter.fwdRealEof);

    _forwardLooping = true;
    _forwardPlayer.seek(Duration.zero).then((_) {
      if (!mounted) return;
      _forwardPlayer.setRate(_controller.state.speed);
      _forwardPlayer.play();
    });
  }

  void _onReversedCompleted(bool done) {
    if (!done || _reversedLooping) return;

    final total = _controller.state.totalDuration;

    if (total < kEofTolerance) return;

    final now = DateTime.now();
    final ctrlPos = _controller.state.position;
    final playerPos = _reversedPlayer.state.position;

    if (_lastReversedCompletedAt != null &&
        now.difference(_lastReversedCompletedAt!) < kEofDebounce) {
      _dbgEvent(
          'REV debounce ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds}');
      return;
    }

    _lastReversedCompletedAt = now;

    // For the reversed file, filePos = total − trickTime, so real EOF is
    // trickTime ≈ 0. False EOF is trickTime > kEofTolerance (file still far from end).
    if (ctrlPos > kEofTolerance) {
      _dbgEvent(
          'REV false-EOF ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');
      // False EOF — demuxer hit network EOF but buffered frames remain.
      _reversedPlayer.play();
      return;
    }

    _dbgEvent(
        'REV real-EOF→loop ctrl=${ctrlPos.inMilliseconds} player=${playerPos.inMilliseconds} total=${total.inMilliseconds}');

    _reversedLooping = true;
    _reversedPlayer.seek(Duration.zero).then((_) {
      if (!mounted) return;

      _reversedPlayer.setRate(_controller.state.speed);
      _reversedPlayer.play();
    });
  }

  void _onDuration(Duration duration) {
    if (duration <= Duration.zero) return;

    _controller.setDuration(duration);

    if (!mounted) return;

    setState(() => _loading = false);
  }

  // Forward position is trick time directly.
  void _onForwardPosition(Duration pos) {
    if (_controller.state.direction != PlaybackDirection.forward) return;
    final prev = _controller.state.position;
    if (!_forwardLooping && prev > kJumpMinPrev && pos < prev - kEofDebounce) {
      final total = _controller.state.totalDuration;
      final isEofLoop = total > Duration.zero &&
          prev >= total - kEofTolerance &&
          pos < kNearStartThreshold;
      if (isEofLoop) {
        // keep-open reset position before our completed handler ran; claim
        // the loop now so the pending completed event exits early.
        _forwardLooping = true;
      }
      _dbgEvent('POS↩ ${prev.inMilliseconds}→${pos.inMilliseconds}ms'
          ' player=${_forwardPlayer.state.position.inMilliseconds}ms'
          ' loop=$_forwardLooping eofLoop=$isEofLoop');
    }
    if (_forwardLooping && pos > kLoopClearThreshold) {
      _forwardLooping = false;
    }
    _controller.updatePosition(pos);
    if (mounted) setState(() {});
  }

  // Reversed file position must be mirrored to get trick time.
  void _onReversedPosition(Duration pos) {
    if (_controller.state.direction != PlaybackDirection.reversed) return;
    if (_controller.state.totalDuration == Duration.zero) return;
    if (_reversedLooping && pos > kLoopClearThreshold) {
      _reversedLooping = false;
    }
    _controller.updatePosition(_controller.state.totalDuration - pos);
    if (mounted) setState(() {});
  }

  // Sync controller play/pause state from the actual player so that browser
  // autoplay blocks (fresh page loads) are reflected in the UI correctly.
  void _onForwardPlaying(bool playing) {
    _dbgEvent(
        'FWD playing=$playing pos=${_controller.state.position.inMilliseconds}ms'
        ' fwdLoop=$_forwardLooping');
    if (_controller.state.direction != PlaybackDirection.forward) return;
    if (playing) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  void _onReversedPlaying(bool playing) {
    if (_controller.state.direction != PlaybackDirection.reversed) return;
    if (playing) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  void _onForwardBuffering(bool buffering) {
    if (_controller.state.direction != PlaybackDirection.forward) return;
    if (mounted) setState(() => _buffering = buffering);
  }

  void _onReversedBuffering(bool buffering) {
    if (_controller.state.direction != PlaybackDirection.reversed) return;
    if (mounted) setState(() => _buffering = buffering);
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
      await native.setProperty('demuxer-max-back-bytes',
          kMpvCacheBytes); // seek(0) on loop served from memory
      await native.setProperty('cache-pause',
          'yes'); // stall instead of false-EOF when buffer runs dry mid-stream
      await native.setProperty(
          'keep-open', 'yes'); // pause at EOF instead of stopping
      await native.setProperty('network-timeout', kMpvNetworkTimeout);
    } catch (_) {}
  }

  Future<void> _initPlayers() async {
    bool isWifi;

    if (kIsWeb) {
      final type = getWebConnectionType();

      if (type != null) {
        _useMobileQuality = type == 'cellular';
        isWifi = !_useMobileQuality;
      } else {
        final view = WidgetsBinding.instance.platformDispatcher.implicitView!;
        final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
        _useMobileQuality = logicalWidth < kMobileWidthBreakpoint;
        isWifi = !_useMobileQuality;
      }

      _isOfflineAtInit = false;
    } else {
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
      final revExists =
          await OfflineVideoService.videoExists(widget.trickId, kReversedVideo);
      final revMobileExists = await OfflineVideoService.videoExists(
          widget.trickId, kReversedMobileVideo);

      if (!mounted) return;

      setState(() {
        _forwardSaved = fwdExists || fwdMobileExists;
        _reversedSaved = revExists || revMobileExists;
      });

      final resolved = await _resolveNativeForwardPath(
        isWifi: isWifi,
        isOffline: _isOfflineAtInit,
        fwdExists: fwdExists,
        fwdMobileExists: fwdMobileExists,
      );

      // This is not redundant, the above async method may complete when the user has navigated away.
      if (!mounted) return;

      if (resolved == null) {
        // Offline with no saved file — button should have been hidden upstream,
        // but guard against deep links or back-nav races.
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
      // Web
      final forwardUrl = _useMobileQuality
          ? widget.provider.forwardMobileUrl(widget.trickId)
          : widget.provider.forwardUrl(widget.trickId);

      forwardPath = forwardUrl.toString();
    }

    if (!mounted) return;

    await _configureMpvForStreaming(_forwardPlayer);

    if (!mounted) return;

    _forwardPlayer.open(Media(forwardPath), play: true);
    _controller.play();
    
    if (mounted) setState(() => _downloadProgress = null);
    // Reversed video is opened lazily on first direction toggle to save mobile bandwidth.
  }

  /// Resolves the forward-video path, filename, and quality settings for the
  /// current connectivity and on-device file state. Returns null when offline
  /// with no saved file — the caller should surface an error and abort init.
  Future<
      ({
        String path,
        String filename,
        bool useMobileQuality,
        String? cachePath,
        bool startQualityUpgrade,
      })?> _resolveNativeForwardPath({
    required bool isWifi,
    required bool isOffline,
    required bool fwdExists,
    required bool fwdMobileExists,
  }) async {
    if (isWifi) {
      if (fwdExists) {
        return (
          path: await OfflineVideoService.videoPath(
              widget.trickId, kForwardVideo),
          filename: kForwardVideo,
          useMobileQuality: false,
          cachePath: null,
          startQualityUpgrade: false,
        );
      }
      if (fwdMobileExists) {
        // Serve mobile quality from device; trigger silent background upgrade.
        return (
          path: await OfflineVideoService.videoPath(
              widget.trickId, kForwardMobileVideo),
          filename: kForwardMobileVideo,
          useMobileQuality: true,
          cachePath: null,
          startQualityUpgrade: true,
        );
      }
      // WiFi + neither on device → evict any mobile cache entry, download full quality.
      final fullUrl = widget.provider.forwardUrl(widget.trickId).toString();
      final cacheDir = await getApplicationCacheDirectory();
      final mobileCache =
          File('${cacheDir.path}/ts_${widget.trickId}_fwd_mobile.mp4');
      if (await mobileCache.exists()) {
        await mobileCache.delete().catchError((_) => mobileCache);
      }
      if (!mounted) return null;
      final cached = await OfflineVideoService.downloadToCache(
        fullUrl,
        cacheKey: '${widget.trickId}_fwd',
        isCancelled: () => _cancelForwardDownload,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (!mounted) return null;
      return (
        path: cached ?? fullUrl,
        filename: kForwardVideo,
        useMobileQuality: false,
        cachePath: cached,
        startQualityUpgrade: false,
      );
    }

    if (isOffline) {
      if (fwdExists) {
        return (
          path: await OfflineVideoService.videoPath(
              widget.trickId, kForwardVideo),
          filename: kForwardVideo,
          useMobileQuality: false,
          cachePath: null,
          startQualityUpgrade: false,
        );
      }
      if (fwdMobileExists) {
        return (
          path: await OfflineVideoService.videoPath(
              widget.trickId, kForwardMobileVideo),
          filename: kForwardMobileVideo,
          useMobileQuality: true,
          cachePath: null,
          startQualityUpgrade: false,
        );
      }
      return null; // No saved file and offline.
    }

    // Cellular
    if (fwdExists) {
      // Full quality on device — no downgrade on mobile.
      return (
        path:
            await OfflineVideoService.videoPath(widget.trickId, kForwardVideo),
        filename: kForwardVideo,
        useMobileQuality: false,
        cachePath: null,
        startQualityUpgrade: false,
      );
    }
    if (fwdMobileExists) {
      return (
        path: await OfflineVideoService.videoPath(
            widget.trickId, kForwardMobileVideo),
        filename: kForwardMobileVideo,
        useMobileQuality: true,
        cachePath: null,
        startQualityUpgrade: false,
      );
    }
    // Cellular + neither on device → download mobile quality to cache.
    final mobileUrl =
        widget.provider.forwardMobileUrl(widget.trickId).toString();
    final cached = await OfflineVideoService.downloadToCache(
      mobileUrl,
      cacheKey: '${widget.trickId}_fwd_mobile',
      isCancelled: () => _cancelForwardDownload,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );
    if (!mounted) return null;
    return (
      path: cached ?? mobileUrl,
      filename: kForwardMobileVideo,
      useMobileQuality: true,
      cachePath: cached,
      startQualityUpgrade: false,
    );
  }

  /// Silently downloads full-quality forward video to replace the mobile-quality
  /// permanent file. Intentionally unawaited; cancellable via [_cancelForwardDownload].
  Future<void> _startQualityUpgrade() async {
    // Guard: if dispose (or any other caller) set the cancel flag before this
    // coroutine ran on the event loop, exit without resetting it.
    if (_cancelForwardDownload) return;
    // Reset cancellation before starting. This executes synchronously at the
    // unawaited() call site — before downloadToPermanent's first await and
    // therefore before any user interaction can set _cancelForwardDownload = true.
    // Removing this line would also be safe (the flag starts false), but keeping
    // it makes the intent explicit for future readers.
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
      // Download failed or was cancelled — partial file cleaned up by downloadToPermanent.
      return;
    }
    if (!mounted || _cancelForwardDownload) return;
    // Delete the mobile-quality file separately so a delete failure doesn't
    // obscure a successful download (and leave both files on disk silently).
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

  /// Loads the reversed video into the reversed player.
  /// Returns true on success, false if the user cancelled or an error occurred.
  Future<bool> _loadReversedVideo() async {
    if (_reversedDownloading) return false; // guard against double-tap race
    String reversedPath;

    if (!kIsWeb && _reversedSaved) {
      // Serve from permanent storage — prefer the matching quality, fall back to the other.
      final preferred =
          _useMobileQuality ? kReversedMobileVideo : kReversedVideo;
      final fallback =
          _useMobileQuality ? kReversedVideo : kReversedMobileVideo;
      String? path;
      if (await OfflineVideoService.videoExists(widget.trickId, preferred)) {
        path = await OfflineVideoService.videoPath(widget.trickId, preferred);
      } else if (await OfflineVideoService.videoExists(
          widget.trickId, fallback)) {
        path = await OfflineVideoService.videoPath(widget.trickId, fallback);
      }
      if (path == null || !mounted) return false;
      reversedPath = path;
    } else if (!kIsWeb) {
      // Online — check storage, then download directly to permanent storage.
      // Set the flag synchronously before the first await so a second tap
      // cannot slip through the guard at the top of this method.
      setState(() => _reversedDownloading = true);
      final sufficient = await OfflineVideoService.hasSufficientStorage();
      if (!mounted) return false;
      if (!sufficient) {
        final proceed = await showStorageWarning(context);
        if (!mounted) return false;
        if (proceed != true) {
          setState(() => _reversedDownloading = false);
          return false;
        }
      }
      try {
        final reversedUrl = _useMobileQuality
            ? widget.provider.reversedMobileUrl(widget.trickId)
            : widget.provider.reversedUrl(widget.trickId);
        final filename =
            _useMobileQuality ? kReversedMobileVideo : kReversedVideo;
        reversedPath = await OfflineVideoService.downloadToPermanent(
          reversedUrl.toString(),
          widget.trickId,
          filename,
          isCancelled: () => _cancelReversedDownload,
        );
        if (!mounted) return false;
        setState(() {
          _reversedDownloading = false;
          _reversedSaved = true;
        });
      } catch (e) {
        if (!mounted) return false;
        setState(() => _reversedDownloading = false);
        if (e is OfflineVideoCancelledException) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download reversed video: $e')),
        );
        return false;
      }
    } else {
      // Web
      final reversedUrl = _useMobileQuality
          ? widget.provider.reversedMobileUrl(widget.trickId)
          : widget.provider.reversedUrl(widget.trickId);
      reversedPath = reversedUrl.toString();
    }

    _reversedLooping = false;
    await _configureMpvForStreaming(_reversedPlayer);
    try {
      await _reversedPlayer.open(Media(reversedPath), play: false);
    } catch (e) {
      debugPrint('TrainingStudio: failed to open reversed video: $e');
      return false;
    }
    _reversedLoaded =
        true; // set after successful open so a failed open leaves the flag clear
    return true;
  }

  Future<void> _saveVideo() async {
    if (_saving || _forwardCachePath == null || _forwardSaved) return;
    setState(() => _saving = true);
    try {
      if (!await File(_forwardCachePath!).exists()) {
        if (!mounted) return;
        setState(() => _forwardCachePath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Cached video was cleared — reopen the training studio to re-download')),
        );
        return;
      }

      final sufficient = await OfflineVideoService.hasSufficientStorage();
      if (!mounted) return;
      if (!sufficient) {
        final proceed = await showStorageWarning(context);
        if (!mounted || proceed != true) return;
      }

      _cancelReversedDownload = true;
      try {
        await OfflineVideoService.saveFromCache(
            _forwardCachePath!, widget.trickId, _forwardFilename);
        if (!mounted) return;
        setState(() => _forwardSaved = true);
        OfflineVideoService.markSaved(widget.trickId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      _cancelReversedDownload = false;
    }
  }

  Future<void> _confirmDeleteVideo() async {
    final confirmed = await showDeleteVideoDialog(context);
    if (confirmed != true || !mounted) return;

    _cancelForwardDownload = true;
    _cancelReversedDownload = true;
    try {
      // deleteAllVideos removes the entire trick directory. The quality upgrade
      // may write forward.mp4 after the cancel flags are set but before the
      // flag checks run; deleting the whole directory covers that window.
      await OfflineVideoService.deleteAllVideos(widget.trickId);
      if (!mounted) return;
      final hadReversedLoaded = _reversedLoaded;
      setState(() {
        _forwardSaved = false;
        _forwardCachePath = null;
        _reversedSaved = false;
        _reversedLoaded = false;
      });
      OfflineVideoService.markDeleted(widget.trickId);
      // Stop the reversed player so it doesn't hold a file handle on the
      // now-deleted path. Resets the looping flag while we're here.
      if (hadReversedLoaded) {
        _reversedLooping = false;
        try {
          await _reversedPlayer.stop();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete video: $e')),
      );
    } finally {
      // _cancelForwardDownload is intentionally NOT reset here. Resetting it in
      // finally races with a still-running download future: the future's rename
      // could land after the directory was deleted, recreating the file on disk
      // and making the video reappear on next launch. _startQualityUpgrade
      // resets the flag itself before each new download cycle, so leaving it
      // true here is safe and keeps the cancel effective until the next save.
      _cancelReversedDownload = false;
    }
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
    _cancelForwardDownload = true;
    _cancelReversedDownload = true;
    _connectivitySub?.cancel();
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

    if (_controller.state.direction == PlaybackDirection.forward &&
        !_reversedLoaded) {
      final loaded = await _loadReversedVideo();
      if (!mounted) return;
      if (!loaded) {
        await _activePlayer.play();
        _controller.play();
        return;
      }
    }

    _controller.toggleDirection();
    _forwardLooping = false;
    _reversedLooping = false;
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
    showAnnotationsSheet(
      context,
      annotations: _annotations,
      currentPosition: _controller.state.position,
      onAnnotationTap: (a) {
        _setSpeed(0.25);
        _controller.updatePosition(Duration(milliseconds: a.startMs));
        _activePlayer.seek(_controller.state.fileSeekPosition);
        _play();
      },
      onAddTapped: _showAddAnnotationDialog,
      onEditTapped: _showEditAnnotationDialog,
      onDeleteAnnotation: (a) async {
        try {
          await AnnotationsService.delete(a.id);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not delete annotation: $e')),
            );
          }
          return false;
        }
        if (mounted)
          setState(() => _annotations.removeWhere((x) => x.id == a.id));
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
      if (mounted) {
        setState(() {
          _annotations = [..._annotations, annotation]
            ..sort((a, b) => a.startMs.compareTo(b.startMs));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save annotation: $e')),
        );
      }
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
      if (mounted) {
        setState(() {
          _annotations = _annotations
              .map((a) => a.id == annotation.id ? updated : a)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save annotation: $e')),
        );
      }
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
                  color: (!_loading && _forwardCachePath != null) ? null : Colors.white38,
                ),
                tooltip: (!_loading && _forwardCachePath != null) ? 'Save to device' : null,
                onPressed: (!_loading && _forwardCachePath != null) ? _saveVideo : null,
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
                          forwardController: _forwardVideoController,
                          reversedController: _reversedVideoController,
                          state: _controller.state,
                          annotations: _annotations,
                          onTap: _togglePlayPause,
                          onAnnotationTap: (a) {
                            _setSpeed(0.25);
                            _controller.updatePosition(
                                Duration(milliseconds: a.startMs));
                            _activePlayer
                                .seek(_controller.state.fileSeekPosition);
                            _play();
                          },
                        ),
            ),
            if (!_loading && _buffering)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (kDebugMode && !_loading)
              TrainingStudioDebugOverlay(
                state: _controller.state,
                forwardPlayerPosition: _forwardPlayer.state.position,
                useMobileQuality: _useMobileQuality,
                buffering: _buffering,
                forwardLooping: _forwardLooping,
                reversedLooping: _reversedLooping,
                fwdFired: _dbgFwdFired,
                fwdFalseEof: _dbgFwdFalseEof,
                fwdRealEof: _dbgFwdRealEof,
                fwdDebounced: _dbgFwdDebounced,
                isOfflineAtInit: _isOfflineAtInit,
                isLiveOffline: isDeviceOffline,
                forwardSaved: _forwardSaved,
                reversedSaved: _reversedSaved,
                hasCachedPath: _forwardCachePath != null,
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
                reversedDownloading: _reversedDownloading,
                reversedSaved: _reversedSaved,
                isEditor: _isEditor,
                annotations: _annotations,
                onStepBackward: _stepBackward,
                onStepForward: _stepForward,
                onPlay: _play,
                onPause: _pause,
                onRestart: _restart,
                onToggleDirection: _toggleDirection,
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
    if (mounted) setState(() {});
  }
}

enum _DbgCounter { fwdFalseEof, fwdRealEof, fwdDebounced }

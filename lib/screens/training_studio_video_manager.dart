import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import '../l10n/app_localizations_extension.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../constants/playback_constants.dart';
import '../utils/connection_speed.dart';
import '../utils/network_utils.dart';
import '../utils/safe_state.dart';
import '../utils/web_connection.dart';
import '../video/mpv_config.dart';
import '../video/offline_video_service.dart';
import '../video/training_video_controller.dart';
import '../video/video_provider.dart';
import '../video/video_quality_resolver.dart';
import '../video/web_video_cache.dart';
import 'training_studio_dialogs.dart';
import 'training_studio_playback.dart';

mixin TrainingStudioVideoManagerMixin<T extends StatefulWidget>
    on SafeStateMixin<T>, TrainingStudioPlaybackMixin<T> {
  int get videoTrickId;
  VideoProvider get videoProvider;

  late final Player _player;
  late final VideoController _videoKitController;
  late final TrainingVideoController _controller;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Satisfies TrainingStudioPlaybackMixin abstract requirements.
  @override
  Player get player => _player;
  @override
  TrainingVideoController get videoController => _controller;
  @override
  void onPlayerDurationReady() => safeSetState(() => loading = false);

  // Exposes the media-kit VideoController for the video widget.
  VideoController get videoKitController => _videoKitController;

  bool loading = true;
  double? downloadProgress; // null = indeterminate, 0.0–1.0 = known
  bool isOfflineAtInit = false;
  bool useMobileQuality = false;
  bool forwardSaved = false;
  // Non-null when the forward video was downloaded to app cache and can be saved permanently.
  String? forwardCachePath;
  String forwardFilename = kForwardVideo;
  bool saving = false;
  bool cancelForwardDownload = false;
  String? initError;

  void initVideo() {
    _player = Player();
    _videoKitController = VideoController(_player);
    _controller = TrainingVideoController(
      provider: videoProvider,
      trickId: videoTrickId,
    );
    _controller.addListener(() => safeSetState(() {}));

    setupPlaybackSubscriptions();

    if (!kIsWeb) {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        setDeviceConnectivity(results);
        safeSetState(() {});
      });
    }

    _initVideoPath();
  }

  void disposeVideo() {
    cancelForwardDownload = true;
    _connectivitySub?.cancel();
    disposePlaybackSubscriptions();
    _controller.dispose();
    _player.dispose();
  }

  Future<void> _initVideoPath() async {
    bool isWifi = false;

    if (!kIsWeb) {
      isWifi = await _checkNativeConnectivity();
    }

    if (!mounted) return;

    final String? forwardPath = kIsWeb
        ? await _resolveWebForwardPath()
        : await _resolveNativeForwardPath(isWifi);

    if (!mounted || forwardPath == null) return;

    await _startPlayback(forwardPath);
  }

  Future<bool> _checkNativeConnectivity() async {
    final result = await Connectivity().checkConnectivity();

    isOfflineAtInit = result.every((r) => r == ConnectivityResult.none);

    setDeviceConnectivity(result);

    final isWifi = !isOfflineAtInit &&
        (result.contains(ConnectivityResult.wifi) ||
            result.contains(ConnectivityResult.ethernet));

    useMobileQuality = !isWifi && !isOfflineAtInit;

    return isWifi;
  }

  Future<String?> _resolveNativeForwardPath(bool isWifi) async {
    final l10n = context.l10n;
    final fwdExists =
        await OfflineVideoService.videoExists(videoTrickId, kForwardVideo);
    final fwdMobileExists =
        await OfflineVideoService.videoExists(videoTrickId, kForwardMobileVideo);

    if (!mounted) return null;

    safeSetState(() => forwardSaved = fwdExists || fwdMobileExists);

    final resolved = await resolveNativeForwardPath(VideoResolutionContext(
      trickId: videoTrickId,
      provider: videoProvider,
      isWifi: isWifi,
      isOffline: isOfflineAtInit,
      fwdExists: fwdExists,
      fwdMobileExists: fwdMobileExists,
      isCancelled: () => cancelForwardDownload,
      onProgress: (p) => safeSetState(() => downloadProgress = p),
      isMounted: () => mounted,
    ));

    if (!mounted) return null;

    if (resolved == null) {
      safeSetState(() {
        loading = false;
        initError = l10n.noSavedVideoOffline;
      });
      return null;
    }

    forwardFilename = resolved.filename;
    useMobileQuality = resolved.useMobileQuality;
    forwardCachePath = resolved.cachePath;

    if (resolved.startQualityUpgrade) {
      unawaited(_startQualityUpgrade());
    }

    return resolved.path;
  }

  // Web — check session cache before quality detection so quality stays
  // consistent across visits and the speed test doesn't re-run needlessly.
  Future<String> _resolveWebForwardPath() async {
    isOfflineAtInit = false;
    final fullKey = '${videoTrickId}_full';
    final mobileKey = '${videoTrickId}_mobile';
    final preCached = getCachedWebVideo(fullKey, mobileKey);

    if (preCached != null) {
      useMobileQuality = preCached.isMobile;
      forwardFilename = preCached.isMobile ? kForwardMobileVideo : kForwardVideo;

      if (kDebugMode) {
        dbgQualityInfo = 'sessionCache (${preCached.isMobile ? 'mobile' : 'full'})';
      }

      return preCached.url;
    }

    useMobileQuality = await _detectWebQuality();
    forwardFilename = useMobileQuality ? kForwardMobileVideo : kForwardVideo;

    final forwardUrl = useMobileQuality
        ? videoProvider.forwardMobileUrl(videoTrickId)
        : videoProvider.forwardUrl(videoTrickId);

    final cacheKey = useMobileQuality ? mobileKey : fullKey;

    final blobUrl = await downloadAndCacheWebVideo(
      forwardUrl.toString(),
      cacheKey: cacheKey,
      isCancelled: () => cancelForwardDownload,
      onProgress: (p) => safeSetState(() => downloadProgress = p),
      onError: kDebugMode
          ? (e) {
              if (mounted) safeSetState(() => dbgQualityInfo += ' err:$e');
            }
          : null,
    );

    return blobUrl ?? forwardUrl.toString();
  }

  Future<bool> _detectWebQuality() async {
    if (isMobileBrowser()) {
      // Mobile browsers are limited by hardware decoding, not bandwidth —
      // the speed test can't detect this, so always serve mobile quality.
      if (kDebugMode) dbgQualityInfo = 'mobileBrowser';

      return true;
    }

    final type = getWebConnectionType();
    if (type != null) {
      if (kDebugMode) dbgQualityInfo = 'effectiveType=$type';
      return type == 'slow-2g' || type == '2g' || type == '3g';
    }

    String? speedTestError;
    final mbps = await estimateConnectionSpeedMbps(
      onError: kDebugMode ? (e) => speedTestError = e : null,
    );
    if (kDebugMode) {
      dbgQualityInfo =
          'speedTest=${mbps != null ? '${mbps.toStringAsFixed(2)}Mbps' : 'null${speedTestError != null ? ' ($speedTestError)' : ''}'}';
    }
    return mbps != null && mbps < kMobileQualityThresholdMbps;
  }

  Future<void> _startPlayback(String forwardPath) async {
    await configureMpvForStreaming(_player);

    if (!mounted) return;

    if (kIsWeb) awaitingWebAutoplay = true;

    _player.open(Media(forwardPath), play: true);
    _controller.play();

    safeSetState(() => downloadProgress = null);
  }

  /// Silently downloads full-quality forward video to replace the mobile-quality
  /// permanent file. Intentionally unawaited; cancellable via [cancelForwardDownload].
  Future<void> _startQualityUpgrade() async {
    if (cancelForwardDownload) return;

    cancelForwardDownload = false;

    try {
      final fullUrl = videoProvider.forwardUrl(videoTrickId).toString();

      await OfflineVideoService.downloadToPermanent(
        fullUrl,
        videoTrickId,
        kForwardVideo,
        isCancelled: () => cancelForwardDownload,
      );
    } catch (_) {
      return;
    }

    if (!mounted || cancelForwardDownload) return;

    try {
      await OfflineVideoService.deleteVideo(videoTrickId, kForwardMobileVideo);
    } catch (e) {
      debugPrint('Quality upgrade: failed to delete $kForwardMobileVideo: $e');
    }

    if (!mounted) return;

    safeSetState(() {
      forwardFilename = kForwardVideo;
      useMobileQuality = false;
    });
  }

  Future<void> saveVideo() async {
    if (saving || forwardCachePath == null || forwardSaved) return;
    final l10n = context.l10n;

    safeSetState(() => saving = true);

    try {
      final fileExists = await File(forwardCachePath!).exists();

      if (!fileExists) {
        if (!mounted) return;

        safeSetState(() => forwardCachePath = null);

        showInfoSnackBar(l10n.cachedVideoCleared);

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
            forwardCachePath!, videoTrickId, forwardFilename);

        if (!mounted) return;

        safeSetState(() => forwardSaved = true);

        OfflineVideoService.markSaved(videoTrickId);
      } catch (e) {
        showInfoSnackBar(l10n.couldNotSaveVideo(e.toString()));
      }
    } finally {
      safeSetState(() => saving = false);
    }
  }

  Future<void> confirmDeleteVideo() async {
    final l10n = context.l10n;
    final confirmed = await showDeleteVideoDialog(context);

    if (confirmed != true || !mounted) return;

    cancelForwardDownload = true;

    try {
      await OfflineVideoService.deleteAllVideos(videoTrickId);

      if (!mounted) return;

      safeSetState(() {
        forwardSaved = false;
        forwardCachePath = null;
      });

      OfflineVideoService.markDeleted(videoTrickId);
    } catch (e) {
      showInfoSnackBar(l10n.couldNotDeleteVideo(e.toString()));
    }
    // cancelForwardDownload is intentionally NOT reset here — see _startQualityUpgrade.
  }
}

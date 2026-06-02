import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'offline_video_service.dart';
import 'video_provider.dart';

/// The resolved path, filename, and quality flags for a native forward video.
typedef NativeVideoResolution = ({
  String path,
  String filename,
  bool useMobileQuality,
  String? cachePath,
  bool startQualityUpgrade,
});

class VideoResolutionContext {
  const VideoResolutionContext({
    required this.trickId,
    required this.provider,
    required this.isWifi,
    required this.isOffline,
    required this.fwdExists,
    required this.fwdMobileExists,
    required this.isCancelled,
    required this.onProgress,
    required this.isMounted,
  });

  final int trickId;
  final VideoProvider provider;
  final bool isWifi;
  final bool isOffline;
  final bool fwdExists;
  final bool fwdMobileExists;
  final bool Function() isCancelled;
  final void Function(double?) onProgress;
  final bool Function() isMounted;
}

String getTrickCacheKey(int trickId, {required bool mobile}) =>
    mobile ? '${trickId}_fwd_mobile' : '${trickId}_fwd';

Future<File> getTrickCacheFile(int trickId, {required bool mobile}) async {
  final dir = await getApplicationCacheDirectory();
  return File('${dir.path}/ts_${getTrickCacheKey(trickId, mobile: mobile)}.mp4');
}

/// Resolves which forward-video file to play on native platforms based on
/// connectivity and what is already saved to device storage.
///
/// Returns null when the device is offline with no saved file — the caller
/// should surface an error and abort player initialisation.
Future<NativeVideoResolution?> resolveNativeForwardPath(
    VideoResolutionContext ctx) async {
  if (ctx.isWifi) return _handleWifi(ctx);
  if (ctx.isOffline) return _resolveFromDevice(ctx);
  return _handleCellular(ctx);
}

Future<NativeVideoResolution?> _handleCellular(
    VideoResolutionContext ctx) async {
  final fromDevice = await _resolveFromDevice(ctx);

  if (fromDevice != null) return fromDevice;

  // Neither on device → download mobile quality to cache.
  final mobileUrl = ctx.provider.forwardMobileUrl(ctx.trickId).toString();

  final cached = await OfflineVideoService.downloadToCache(
    mobileUrl,
    cacheKey: getTrickCacheKey(ctx.trickId, mobile: true),
    isCancelled: ctx.isCancelled,
    onProgress: ctx.onProgress,
  );

  if (!ctx.isMounted()) return null;

  return _mobileQuality(cached ?? mobileUrl, cachePath: cached);
}

Future<NativeVideoResolution?> _handleWifi(VideoResolutionContext ctx) async {
  // Did we cache the video in either quality?
  final fromDevice = await _resolveFromDevice(ctx, upgradeIfMobile: true);

  if (fromDevice != null) return fromDevice;

  // Neither on device, evict any mobile cache entry, download full quality.
  final fullUrl = ctx.provider.forwardUrl(ctx.trickId).toString();
  final mobileCache = await getTrickCacheFile(ctx.trickId, mobile: true);

  if (await mobileCache.exists()) {
    await mobileCache.delete().catchError((_) => mobileCache);
  }

  if (!ctx.isMounted()) return null;

  final cached = await OfflineVideoService.downloadToCache(
    fullUrl,
    cacheKey: getTrickCacheKey(ctx.trickId, mobile: false),
    isCancelled: ctx.isCancelled,
    onProgress: ctx.onProgress,
  );

  if (!ctx.isMounted()) return null;

  return _fullQuality(cached ?? fullUrl, cachePath: cached);
}

/// Checks device storage and returns a resolution if a saved file exists.
/// Returns null if neither quality is saved — the caller handles downloading.
Future<NativeVideoResolution?> _resolveFromDevice(
  VideoResolutionContext ctx, {
  bool upgradeIfMobile = false,
}) async {
  if (ctx.fwdExists) {
    return _fullQuality(
        await OfflineVideoService.videoPath(ctx.trickId, kForwardVideo));
  }

  if (ctx.fwdMobileExists) {
    return _mobileQuality(
      await OfflineVideoService.videoPath(ctx.trickId, kForwardMobileVideo),
      startUpgrade: upgradeIfMobile,
    );
  }

  return null;
}

NativeVideoResolution _fullQuality(String path, {String? cachePath}) => (
      path: path,
      filename: kForwardVideo,
      useMobileQuality: false,
      cachePath: cachePath,
      startQualityUpgrade: false,
    );

NativeVideoResolution _mobileQuality(String path,
        {String? cachePath, bool startUpgrade = false}) =>
    (
      path: path,
      filename: kForwardMobileVideo,
      useMobileQuality: true,
      cachePath: cachePath,
      startQualityUpgrade: startUpgrade,
    );

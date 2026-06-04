import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:media_kit/media_kit.dart';
import '../constants/playback_constants.dart';

/// Applies buffering and hardware-decoding MPV properties so that temporary
/// network stalls are absorbed by the cache rather than reported as EOF.
///
/// No-op on web (MPV is not used there).
Future<void> configureMpvForStreaming(Player player) async {
  if (kIsWeb) return;
  try {
    // NativePlayer.setProperty exists at runtime on Android/desktop but the
    // pub stub doesn't declare it, so we use dynamic dispatch to avoid the
    // static type error. The try-catch handles platforms without the method.
    final dynamic native = player.platform;
    if (Platform.isAndroid) {
      await native.setProperty('hwdec', 'mediacodec');
    } else if (Platform.isIOS) {
      await native.setProperty('hwdec', 'videotoolbox');
    } else {
      await native.setProperty('hwdec', 'auto-safe');
    }
    await native.setProperty('cache', 'yes');
    await native.setProperty('demuxer-max-bytes', kMpvCacheBytes);
    await native.setProperty('demuxer-max-back-bytes', kMpvCacheBytes);
    await native.setProperty('cache-pause', 'yes');
    await native.setProperty('keep-open', 'yes');
    await native.setProperty('network-timeout', kMpvNetworkTimeout);
  } catch (_) {}
}

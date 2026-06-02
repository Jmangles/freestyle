({String url, bool isMobile})? getCachedWebVideo(
        String fullKey, String mobileKey) =>
    null;

Future<String?> downloadAndCacheWebVideo(
  String url, {
  required String cacheKey,
  void Function(double)? onProgress,
  bool Function()? isCancelled,
  void Function(String)? onError,
}) async =>
    null;

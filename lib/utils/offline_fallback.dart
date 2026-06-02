import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'network_utils.dart';

/// Runs [online] when the device has connectivity, otherwise calls [offline].
/// On network errors (transient failures) it also falls back to [offline].
/// Non-network exceptions and all errors on web are re-thrown so callers can
/// surface them as real failures.
///
/// [caller] is included in debug log lines for quick identification.
Future<T> withOfflineFallback<T>({
  required String caller,
  required Future<T> Function() online,
  required Future<T> Function() offline,
}) async {
  if (isDeviceOffline) return offline();
  try {
    return await online();
  } catch (e, st) {
    if (kIsWeb || !isNetworkError(e)) {
      debugPrint('$caller: $e\n$st');
      rethrow;
    }
    debugPrint('$caller: network error, using cache');
    return offline();
  }
}

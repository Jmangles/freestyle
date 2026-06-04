import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

bool _deviceOffline = false;

/// Whether the device is known to have no network interface.
/// Updated by [setDeviceConnectivity]; always false on web.
bool get isDeviceOffline => !kIsWeb && _deviceOffline;

/// Call this whenever connectivity changes so services can skip Supabase calls
/// when the device is known offline.
void setDeviceConnectivity(List<ConnectivityResult> results) {
  _deviceOffline = results.every((r) => r == ConnectivityResult.none);
}

/// Returns true when [e] is a transient network failure rather than an
/// application-level error. Used by services to decide whether to fall back to
/// the local cache instead of propagating the exception.
///
/// Always returns false on web — the browser handles connectivity and there is
/// no local cache to fall back to.
bool isNetworkError(Object e) {
  if (kIsWeb) return false;
  return e is SocketException || e is http.ClientException || e is TimeoutException;
}

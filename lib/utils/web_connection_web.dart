import 'dart:js_interop';

extension type _NetworkInformation._(JSObject _) implements JSObject {
  external String? get effectiveType;
}

@JS('navigator.connection')
external _NetworkInformation? get _connection;

@JS('navigator.userAgent')
external String get _userAgent;

String? getWebConnectionType() {
  try {
    return _connection?.effectiveType;
  } catch (_) {
    return null;
  }
}

bool isMobileBrowser() {
  try {
    final ua = _userAgent.toLowerCase();
    return ua.contains('mobile') || ua.contains('android');
  } catch (_) {
    return false;
  }
}

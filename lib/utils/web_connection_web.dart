import 'dart:js_interop';

extension type _NetworkInformation._(JSObject _) implements JSObject {
  external String? get effectiveType;
}

@JS('navigator.connection')
external _NetworkInformation? get _connection;

String? getWebConnectionType() {
  try {
    return _connection?.effectiveType;
  } catch (_) {
    return null;
  }
}

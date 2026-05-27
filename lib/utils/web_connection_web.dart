import 'dart:js_interop';

extension type _NetworkInformation._(JSObject _) implements JSObject {
  external String? get type;
}

@JS('navigator.connection')
external _NetworkInformation? get _connection;

String? getWebConnectionType() {
  try {
    return _connection?.type;
  } catch (_) {
    return null;
  }
}

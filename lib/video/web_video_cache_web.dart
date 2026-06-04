import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny?> blobParts);
}

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

final _sessionCache = <String, String>{};

({String url, bool isMobile})? getCachedWebVideo(
    String fullKey, String mobileKey) {
  final full = _sessionCache[fullKey];

  if (full != null) return (url: full, isMobile: false);

  final mobile = _sessionCache[mobileKey];

  if (mobile != null) return (url: mobile, isMobile: true);
  
  return null;
}

Future<String?> downloadAndCacheWebVideo(
  String url, {
  required String cacheKey,
  void Function(double)? onProgress,
  bool Function()? isCancelled,
  void Function(String)? onError,
}) async {
  final cached = _sessionCache[cacheKey];

  if (cached != null) {
    onProgress?.call(1.0);
    return cached;
  }

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final streamed = await client.send(request);

    if (streamed.statusCode != 200) {
      onError?.call('HTTP ${streamed.statusCode}');
      return null;
    }

    final total = streamed.contentLength ?? -1;
    // copy:true ensures takeBytes() returns an owned Uint8List with no
    // byteOffset, which is required for a correct .toJS conversion.
    final builder = BytesBuilder();
    var received = 0;

    await for (final chunk in streamed.stream) {
      if (isCancelled?.call() == true) return null;

      builder.add(chunk);
      received += chunk.length;

      if (total <= 0) continue;

      onProgress?.call(received / total);
    }

    if (isCancelled?.call() == true) return null;

    final bytes = builder.takeBytes();
    final List<JSAny?> parts = [bytes.toJS];
    final blob = _Blob(parts.toJS);
    final objectUrl = _createObjectUrl(blob);

    _sessionCache[cacheKey] = objectUrl;

    onProgress?.call(1.0);

    return objectUrl;
  } catch (e, st) {
    debugPrint('WebVideoCache: download/blob failed: $e\n$st');

    onError?.call(e.toString());
    
    return null;
  } finally {
    client.close();
  }
}

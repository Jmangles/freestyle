import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'av1_codec_stub.dart' if (dart.library.js_interop) 'av1_codec_web.dart';

bool _av1Supported = false;
bool get av1Supported => _av1Supported;

Future<void> initAv1Support() async {
  _av1Supported = await _resolve();
}

Future<bool> _resolve() async {
  if (kIsWeb) return webCanPlayAv1();
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 29;
  }
  if (Platform.isIOS) {
    final version = (await DeviceInfoPlugin().iosInfo).systemVersion;
    final major = int.tryParse(version.split('.').first) ?? 0;
    return major >= 14;
  }
  return true; // macOS, Windows, Linux
}

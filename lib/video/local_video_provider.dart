import 'dart:io';
import 'package:flutter/foundation.dart';
import 'video_provider.dart';

class LocalVideoProvider implements VideoProvider {
  final String baseUrl;

  const LocalVideoProvider({required this.baseUrl});

  factory LocalVideoProvider.defaultForPlatform() =>
      LocalVideoProvider(baseUrl: _defaultBaseUrl());

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  /// Ignores trickId — serves the single set of test fixture videos.
  @override
  Uri forwardUrl(int trickId) => Uri.parse('$baseUrl/trick_forward.mp4');

  @override
  Uri reversedUrl(int trickId) => Uri.parse('$baseUrl/trick_reversed.mp4');
}

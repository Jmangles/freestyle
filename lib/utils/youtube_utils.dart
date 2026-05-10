Uri? _parseYouTubeUri(String? url) {
  if (url == null || url.isEmpty) return null;
  return Uri.tryParse(url);
}

/// Returns both the video ID and whether the URL is a portrait (Shorts) video
/// in a single parse. Use this when both values are needed at the same call site.
({String? id, bool isPortrait}) parseYouTubeVideo(String? url) {
  final uri = _parseYouTubeUri(url);
  if (uri == null) return (id: null, isPortrait: false);
  final isPortrait = uri.pathSegments.contains('shorts');
  String? id;
  if (uri.host == 'youtu.be') {
    id = uri.pathSegments.firstOrNull;
  } else if (uri.host.endsWith('youtube.com')) {
    if (isPortrait) {
      final i = uri.pathSegments.indexOf('shorts');
      id = i + 1 < uri.pathSegments.length ? uri.pathSegments[i + 1] : null;
    } else {
      id = uri.queryParameters['v'];
    }
  }
  return (id: id, isPortrait: isPortrait);
}

String? extractYouTubeId(String? url) => parseYouTubeVideo(url).id;

bool isYouTubePortraitUrl(String? url) => parseYouTubeVideo(url).isPortrait;

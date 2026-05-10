Uri? _parseYouTubeUri(String? url) {
  if (url == null || url.isEmpty) return null;
  return Uri.tryParse(url);
}

String? extractYouTubeId(String? url) {
  final uri = _parseYouTubeUri(url);
  if (uri == null) return null;
  if (uri.host == 'youtu.be') return uri.pathSegments.firstOrNull;
  if (uri.host.endsWith('youtube.com')) {
    final shortsIdx = uri.pathSegments.indexOf('shorts');
    if (shortsIdx != -1) {
      return shortsIdx + 1 < uri.pathSegments.length ? uri.pathSegments[shortsIdx + 1] : null;
    }
    return uri.queryParameters['v'];
  }
  return null;
}

bool isYouTubePortraitUrl(String? url) {
  return _parseYouTubeUri(url)?.pathSegments.contains('shorts') == true;
}

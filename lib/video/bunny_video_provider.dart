import 'video_provider.dart';

class BunnyVideoProvider implements VideoProvider {
  final String baseUrl;

  const BunnyVideoProvider({required this.baseUrl});

  @override
  Uri forwardUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/forward.mp4');

  @override
  Uri reversedUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/reversed.mp4');

  @override
  Uri forwardMobileUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/forward_mobile.mp4');

  @override
  Uri reversedMobileUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/reversed_mobile.mp4');
}

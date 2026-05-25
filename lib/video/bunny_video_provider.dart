import 'video_provider.dart';

class BunnyVideoProvider implements VideoProvider {
  final String baseUrl;

  const BunnyVideoProvider({required this.baseUrl});

  @override
  Uri forwardUrl(int trickId) => Uri.parse('$baseUrl/$trickId/forward.mp4');

  @override
  Uri reversedUrl(int trickId) => Uri.parse('$baseUrl/$trickId/reversed.mp4');
}

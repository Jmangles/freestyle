import 'offline_video_service.dart';
import 'video_provider.dart';

class BunnyVideoProvider implements VideoProvider {
  final String baseUrl;

  const BunnyVideoProvider({required this.baseUrl});

  @override
  Uri forwardUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/$kForwardVideo');

  @override
  Uri reversedUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/$kReversedVideo');

  @override
  Uri forwardMobileUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/$kForwardMobileVideo');

  @override
  Uri reversedMobileUrl(int trickId) => Uri.parse('$baseUrl/tricks/$trickId/$kReversedMobileVideo');
}

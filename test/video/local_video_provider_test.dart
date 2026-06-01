import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/video/local_video_provider.dart';

void main() {
  group('LocalVideoProvider', () {
    const provider = LocalVideoProvider(baseUrl: 'http://localhost:8080');

    test('forwardUrl returns correct path', () {
      expect(
        provider.forwardUrl(1),
        Uri.parse('http://localhost:8080/trick_forward.mp4'),
      );
    });

    test('trickId is ignored — same URL regardless of id', () {
      expect(provider.forwardUrl(1), equals(provider.forwardUrl(99)));
    });

    test('custom baseUrl is reflected in URLs', () {
      const other = LocalVideoProvider(baseUrl: 'http://192.168.1.10:8080');
      expect(other.forwardUrl(1).host, '192.168.1.10');
    });
  });
}

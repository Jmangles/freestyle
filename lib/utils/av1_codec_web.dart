// ignore: avoid_web_libraries_in_flutter
import 'dart:html' show VideoElement;

bool webCanPlayAv1() {
  try {
    final canPlay = VideoElement().canPlayType('video/mp4; codecs="av01.0.05M.08"');
    return canPlay == 'probably' || canPlay == 'maybe';
  } catch (_) {
    return false;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/video/training_video_controller.dart';
import 'package:freestyle_highline/video/training_video_state.dart';
import 'package:freestyle_highline/video/video_provider.dart';

class _MockProvider implements VideoProvider {
  @override
  Uri forwardUrl(int trickId) => Uri.parse('http://mock/$trickId/forward.mp4');

  @override
  Uri forwardMobileUrl(int trickId) => Uri.parse('http://mock/$trickId/forward_mobile.mp4');
}

TrainingVideoController _make({int trickId = 1}) =>
    TrainingVideoController(provider: _MockProvider(), trickId: trickId);

const _duration = Duration(seconds: 12);
const _frame = Duration(microseconds: 16667);

void main() {
  group('TrainingVideoState equality', () {
    test('equal states are equal', () {
      const a = TrainingVideoState(speed: 0.5);
      const b = TrainingVideoState(speed: 0.5);
      expect(a, equals(b));
    });

    test('differing fields are not equal', () {
      const a = TrainingVideoState(speed: 0.5);
      const b = TrainingVideoState(speed: 1.0);
      expect(a, isNot(equals(b)));
    });
  });

  group('initial state', () {
    test('defaults are correct', () {
      final c = _make();
      expect(c.state.speed, 1.0);
      expect(c.state.position, Duration.zero);
      expect(c.state.totalDuration, Duration.zero);
      expect(c.state.isPlaying, false);
    });
  });

  group('currentVideoUrl', () {
    test('returns forwardUrl', () {
      final c = _make(trickId: 7);
      expect(c.currentVideoUrl, Uri.parse('http://mock/7/forward.mp4'));
    });
  });

  group('play / pause', () {
    test('play sets isPlaying to true', () {
      final c = _make();
      c.play();
      expect(c.state.isPlaying, true);
    });

    test('pause sets isPlaying to false', () {
      final c = _make();
      c.play();
      c.pause();
      expect(c.state.isPlaying, false);
    });

    test('play when already playing does not notify', () {
      final c = _make();
      c.play();
      var notified = false;
      c.addListener(() => notified = true);
      c.play();
      expect(notified, false);
    });

    test('pause when already paused does not notify', () {
      final c = _make();
      var notified = false;
      c.addListener(() => notified = true);
      c.pause();
      expect(notified, false);
    });
  });

  group('restart', () {
    test('seeks to zero and plays', () {
      final c = _make();
      c.setDuration(_duration);
      c.updatePosition(const Duration(seconds: 5));
      c.restart();
      expect(c.state.position, Duration.zero);
      expect(c.state.isPlaying, true);
    });
  });

  group('stepForward', () {
    test('advances position by one frame', () {
      final c = _make();
      c.setDuration(_duration);
      c.stepForward();
      expect(c.state.position, _frame);
    });

    test('pauses playback', () {
      final c = _make();
      c.setDuration(_duration);
      c.play();
      c.stepForward();
      expect(c.state.isPlaying, false);
    });

    test('clamps at totalDuration', () {
      final c = _make();
      c.setDuration(_duration);
      c.updatePosition(_duration);
      c.stepForward();
      expect(c.state.position, _duration);
    });
  });

  group('stepBackward', () {
    test('decrements position by one frame', () {
      final c = _make();
      c.setDuration(_duration);
      c.updatePosition(const Duration(seconds: 1));
      c.stepBackward();
      expect(c.state.position, const Duration(seconds: 1) - _frame);
    });

    test('pauses playback', () {
      final c = _make();
      c.setDuration(_duration);
      c.updatePosition(const Duration(seconds: 1));
      c.play();
      c.stepBackward();
      expect(c.state.isPlaying, false);
    });

    test('clamps at Duration.zero', () {
      final c = _make();
      c.setDuration(_duration);
      c.stepBackward();
      expect(c.state.position, Duration.zero);
    });
  });

  group('setSpeed', () {
    test('updates speed', () {
      final c = _make();
      c.setSpeed(0.5);
      expect(c.state.speed, 0.5);
    });

    test('same speed does not notify', () {
      final c = _make();
      var notified = false;
      c.addListener(() => notified = true);
      c.setSpeed(1.0);
      expect(notified, false);
    });

    test('invalid speed asserts in debug mode', () {
      final c = _make();
      expect(() => c.setSpeed(0.33), throwsA(isA<AssertionError>()));
    });
  });

  group('setDuration', () {
    test('updates totalDuration', () {
      final c = _make();
      c.setDuration(_duration);
      expect(c.state.totalDuration, _duration);
    });

    test('same duration does not notify', () {
      final c = _make();
      c.setDuration(_duration);
      var notified = false;
      c.addListener(() => notified = true);
      c.setDuration(_duration);
      expect(notified, false);
    });
  });

  group('updatePosition', () {
    test('updates position', () {
      final c = _make();
      c.updatePosition(const Duration(seconds: 3));
      expect(c.state.position, const Duration(seconds: 3));
    });

    test('same position does not notify', () {
      final c = _make();
      c.updatePosition(const Duration(seconds: 3));
      var notified = false;
      c.addListener(() => notified = true);
      c.updatePosition(const Duration(seconds: 3));
      expect(notified, false);
    });
  });
}

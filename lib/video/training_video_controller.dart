import 'package:flutter/foundation.dart';
import 'playback_direction.dart';
import 'training_video_state.dart';
import 'video_provider.dart';

/// One frame at 60 fps — used for frame-step operations.
const Duration kFrameStep = Duration(microseconds: 16667);

class TrainingVideoController extends ChangeNotifier {
  final VideoProvider provider;
  final int trickId;

  TrainingVideoState _state;

  TrainingVideoController({required this.provider, required this.trickId})
      : _state = const TrainingVideoState();

  TrainingVideoState get state => _state;

  Uri get currentVideoUrl => _state.direction == PlaybackDirection.forward
      ? provider.forwardUrl(trickId)
      : provider.reversedUrl(trickId);

  void play() {
    if (_state.isPlaying) return;
    _state = _state.copyWith(isPlaying: true);
    notifyListeners();
  }

  void pause() {
    if (!_state.isPlaying) return;
    _state = _state.copyWith(isPlaying: false);
    notifyListeners();
  }

  /// Seeks to the start of the current playback direction and resumes.
  /// Forward: seeks to trick-time 0. Reversed: seeks to trick-time totalDuration.
  void restart() {
    final startPosition = _state.direction == PlaybackDirection.forward
        ? Duration.zero
        : _state.totalDuration;
    _state = _state.copyWith(position: startPosition, isPlaying: true);
    notifyListeners();
  }

  /// Advances one frame forward in trick time, pausing playback.
  void stepForward() {
    final next = _state.position + kFrameStep;
    _state = _state.copyWith(
      isPlaying: false,
      position: next > _state.totalDuration ? _state.totalDuration : next,
    );
    notifyListeners();
  }

  /// Steps one frame backward in trick time, pausing playback.
  void stepBackward() {
    final prev = _state.position - kFrameStep;
    _state = _state.copyWith(
      isPlaying: false,
      position: prev < Duration.zero ? Duration.zero : prev,
    );
    notifyListeners();
  }

  void setSpeed(double speed) {
    assert(kPlaybackSpeeds.contains(speed), 'Speed $speed is not in kPlaybackSpeeds');
    if (_state.speed == speed) return;
    _state = _state.copyWith(speed: speed);
    notifyListeners();
  }

  /// Flips playback direction. Trick-time position is preserved so the
  /// media_kit layer can convert to the correct file-seek position via
  /// TrainingVideoState.fileSeekPosition.
  void toggleDirection() {
    final newDirection = _state.direction == PlaybackDirection.forward
        ? PlaybackDirection.reversed
        : PlaybackDirection.forward;
    _state = _state.copyWith(direction: newDirection);
    notifyListeners();
  }

  /// Called by the media_kit integration (phase 2) to sync playback position.
  /// Position must be in trick time, not file time.
  void updatePosition(Duration position) {
    if (_state.position == position) return;
    _state = _state.copyWith(position: position);
    notifyListeners();
  }

  /// Called when the video file reports its duration. Both files have the
  /// same duration so this only needs to be set once from the forward file.
  void setDuration(Duration duration) {
    if (_state.totalDuration == duration) return;
    _state = _state.copyWith(totalDuration: duration);
    notifyListeners();
  }
}

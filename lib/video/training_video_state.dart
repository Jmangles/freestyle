import 'playback_direction.dart';

const List<double> kPlaybackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0];

class TrainingVideoState {
  final PlaybackDirection direction;
  final double speed;

  /// Position in trick time — always relative to the start of the trick,
  /// regardless of which video file is loaded or the playback direction.
  final Duration position;
  final Duration totalDuration;
  final bool isPlaying;

  const TrainingVideoState({
    this.direction = PlaybackDirection.forward,
    this.speed = 1.0,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlaying = false,
  });

  TrainingVideoState copyWith({
    PlaybackDirection? direction,
    double? speed,
    Duration? position,
    Duration? totalDuration,
    bool? isPlaying,
  }) =>
      TrainingVideoState(
        direction: direction ?? this.direction,
        speed: speed ?? this.speed,
        position: position ?? this.position,
        totalDuration: totalDuration ?? this.totalDuration,
        isPlaying: isPlaying ?? this.isPlaying,
      );

  /// Converts trick-time position to the seek position in the current video file.
  /// Forward file: file_position == trick_position
  /// Reversed file: file_position == totalDuration - trick_position
  Duration get fileSeekPosition => direction == PlaybackDirection.forward
      ? position
      : totalDuration - position;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingVideoState &&
          direction == other.direction &&
          speed == other.speed &&
          position == other.position &&
          totalDuration == other.totalDuration &&
          isPlaying == other.isPlaying;

  @override
  int get hashCode =>
      Object.hash(direction, speed, position, totalDuration, isPlaying);
}

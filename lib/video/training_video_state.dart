const List<double> kPlaybackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0];

class TrainingVideoState {
  final double speed;

  /// Position in trick time — always relative to the start of the trick.
  final Duration position;
  final Duration totalDuration;
  final bool isPlaying;

  const TrainingVideoState({
    this.speed = 1.0,
    this.position = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isPlaying = false,
  });

  TrainingVideoState copyWith({
    double? speed,
    Duration? position,
    Duration? totalDuration,
    bool? isPlaying,
  }) =>
      TrainingVideoState(
        speed: speed ?? this.speed,
        position: position ?? this.position,
        totalDuration: totalDuration ?? this.totalDuration,
        isPlaying: isPlaying ?? this.isPlaying,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingVideoState &&
          speed == other.speed &&
          position == other.position &&
          totalDuration == other.totalDuration &&
          isPlaying == other.isPlaying;

  @override
  int get hashCode => Object.hash(speed, position, totalDuration, isPlaying);
}

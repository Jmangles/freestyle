import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/trick_annotation.dart';
import '../utils/date_formatters.dart';
import '../utils/network_utils.dart';
import '../video/playback_direction.dart';
import '../video/training_video_state.dart';
import 'annotation_widgets.dart';

class TrainingStudioControls extends StatelessWidget {
  final TrainingVideoState state;
  final bool loading;
  final bool hasError;
  final bool reversedDownloading;
  final bool reversedSaved;
  final bool isEditor;
  final List<TrickAnnotation> annotations;

  final VoidCallback onStepBackward;
  final VoidCallback onStepForward;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onRestart;
  final VoidCallback onToggleDirection;
  final ValueChanged<double> onScrub;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onShowAnnotations;

  const TrainingStudioControls({
    super.key,
    required this.state,
    required this.loading,
    required this.hasError,
    required this.reversedDownloading,
    required this.reversedSaved,
    required this.isEditor,
    required this.annotations,
    required this.onStepBackward,
    required this.onStepForward,
    required this.onPlay,
    required this.onPause,
    required this.onRestart,
    required this.onToggleDirection,
    required this.onScrub,
    required this.onSetSpeed,
    required this.onShowAnnotations,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = state.totalDuration.inMilliseconds;
    final totalMicros = state.totalDuration.inMicroseconds;
    final progress = totalMicros > 0
        ? (state.position.inMicroseconds / totalMicros).clamp(0.0, 1.0)
        : 0.0;
    final canAct = !loading && !hasError;
    final hideReverseButton = !kIsWeb && !loading && isDeviceOffline && !reversedSaved;

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: canAct ? onScrub : null,
                      ),
                    ),
                    if (annotations.isNotEmpty && totalMs > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: AnnotationDotPainter(
                              annotations: annotations,
                              totalMs: totalMs,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${formatDuration(state.position)} / ${formatDuration(state.totalDuration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.navigate_before, color: Colors.white),
                tooltip: 'Step back one frame',
                onPressed: canAct ? onStepBackward : null,
              ),
              IconButton(
                icon: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                tooltip: state.isPlaying ? 'Pause' : 'Play',
                onPressed: canAct ? (state.isPlaying ? onPause : onPlay) : null,
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next, color: Colors.white),
                tooltip: 'Step forward one frame',
                onPressed: canAct ? onStepForward : null,
              ),
              IconButton(
                icon: const Icon(Icons.replay, color: Colors.white),
                tooltip: 'Restart',
                onPressed: canAct ? onRestart : null,
              ),
              if (!hideReverseButton)
                reversedDownloading
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          state.direction == PlaybackDirection.forward
                              ? Icons.arrow_forward
                              : Icons.arrow_back,
                          color: state.direction == PlaybackDirection.reversed
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white,
                        ),
                        tooltip: state.direction == PlaybackDirection.forward
                            ? 'Playing forward — tap to reverse'
                            : 'Playing reversed — tap to go forward',
                        onPressed: canAct ? onToggleDirection : null,
                      ),
              const Spacer(),
              if (isEditor)
                IconButton(
                  icon: const Icon(Icons.comment_outlined, color: Colors.white),
                  tooltip: 'Manage annotations',
                  onPressed: canAct ? onShowAnnotations : null,
                ),
              DropdownButton<double>(
                value: state.speed,
                dropdownColor: Colors.black87,
                underline: const SizedBox.shrink(),
                iconEnabledColor: Colors.white54,
                alignment: Alignment.center,
                items: const [
                  DropdownMenuItem(value: 0.25, alignment: Alignment.center, child: Text('0.25x', style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 0.5,  alignment: Alignment.center, child: Text('0.5x',  style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 0.75, alignment: Alignment.center, child: Text('0.75x', style: TextStyle(color: Colors.white, fontSize: 13))),
                  DropdownMenuItem(value: 1.0,  alignment: Alignment.center, child: Text('1x',    style: TextStyle(color: Colors.white, fontSize: 13))),
                ],
                onChanged: canAct ? (v) { if (v != null) onSetSpeed(v); } : null,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }
}

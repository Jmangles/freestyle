import 'package:flutter/material.dart';
import '../video/training_video_state.dart';

class TrainingStudioDebugOverlay extends StatelessWidget {
  final TrainingVideoState state;
  final Duration playerPosition;
  final bool useMobileQuality;
  final bool buffering;
  final bool looping;
  final int fwdFired;
  final int fwdFalseEof;
  final int fwdRealEof;
  final int fwdDebounced;
  final bool isOfflineAtInit;
  final bool isLiveOffline;
  final bool forwardSaved;
  final bool hasCachedPath;
  final String qualityInfo;
  final List<String> log;

  const TrainingStudioDebugOverlay({
    super.key,
    required this.state,
    required this.playerPosition,
    required this.useMobileQuality,
    required this.buffering,
    required this.looping,
    required this.fwdFired,
    required this.fwdFalseEof,
    required this.fwdRealEof,
    required this.fwdDebounced,
    required this.isOfflineAtInit,
    required this.isLiveOffline,
    required this.forwardSaved,
    required this.hasCachedPath,
    required this.qualityInfo,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'monospace',
            height: 1.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${useMobileQuality ? 'MOBILE' : 'FULL'}'
                '  ctrl=${state.position.inMilliseconds}ms'
                '  player=${playerPosition.inMilliseconds}ms'
                '  total=${state.totalDuration.inMilliseconds}ms',
                style: TextStyle(
                  color: useMobileQuality ? Colors.orange : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${state.isPlaying ? 'PLAYING' : 'paused'}'
                '  ${buffering ? 'BUFFERING' : 'buf-ok'}'
                '  loop=$looping',
              ),
              Text(
                'completed: fired=$fwdFired'
                '  falseEOF=$fwdFalseEof'
                '  realEOF=$fwdRealEof'
                '  debounced=$fwdDebounced',
              ),
              Text(
                'initOffline=$isOfflineAtInit  liveOffline=$isLiveOffline'
                '  fwdSaved=$forwardSaved'
                '  cached=$hasCachedPath',
              ),
              if (qualityInfo.isNotEmpty) Text('connection: $qualityInfo'),
              if (log.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final line in log.reversed)
                  Text(line, style: const TextStyle(color: Colors.white54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/network_utils.dart';
import '../utils/safe_state.dart';
import '../video/video_provider.dart';
import '../widgets/back_home_leading.dart';
import '../widgets/training_studio_controls.dart';
import '../widgets/training_studio_debug_overlay.dart';
import '../widgets/training_studio_video_area.dart';
import 'training_studio_annotations.dart';
import 'training_studio_playback.dart';
import 'training_studio_video_manager.dart';

class TrainingStudioScreen extends StatefulWidget {
  final int trickId;
  final VideoProvider provider;
  final String? title;

  const TrainingStudioScreen({
    super.key,
    required this.trickId,
    required this.provider,
    this.title,
  });

  @override
  State<TrainingStudioScreen> createState() => _TrainingStudioScreenState();
}

class _TrainingStudioScreenState extends State<TrainingStudioScreen>
    with
        SafeStateMixin,
        TrainingStudioPlaybackMixin<TrainingStudioScreen>,
        TrainingStudioVideoManagerMixin<TrainingStudioScreen>,
        TrainingStudioAnnotationsMixin<TrainingStudioScreen> {
  @override
  int get videoTrickId => widget.trickId;
  @override
  VideoProvider get videoProvider => widget.provider;

  @override
  int get annotationTrickId => widget.trickId;
  @override
  Duration get annotationCurrentPosition => videoController.state.position;
  @override
  Duration get annotationTotalDuration => videoController.state.totalDuration;

  @override
  void initState() {
    super.initState();
    initVideo();
    loadAnnotationsAndProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: context.canPop() ? 96 : 48,
        leading: const BackHomeLeading(showHome: true),
        title: Text(widget.title ?? 'Training Studio'),
        actions: [
          if (!kIsWeb) ...[
            if (forwardSaved)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove from device',
                onPressed: saving ? null : confirmDeleteVideo,
              )
            else if (saving)
              const SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.save_alt,
                  color: (!loading && forwardCachePath != null)
                      ? null
                      : Colors.white38,
                ),
                tooltip: (!loading && forwardCachePath != null)
                    ? 'Save to device'
                    : null,
                onPressed: (!loading && forwardCachePath != null)
                    ? saveVideo
                    : null,
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(value: downloadProgress))
                  : initError != null
                      ? Center(
                          child: Text(
                            initError!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : TrainingStudioVideoArea(
                          videoController: videoKitController,
                          state: videoController.state,
                          annotations: annotations,
                          onTap: togglePlayPause,
                          onAnnotationTap: seekToAnnotation,
                        ),
            ),
            if (!loading && buffering)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (kDebugMode && !loading)
              TrainingStudioDebugOverlay(
                state: videoController.state,
                playerPosition: player.state.position,
                filename: forwardFilename,
                useMobileQuality: useMobileQuality,
                buffering: buffering,
                looping: looping,
                fwdFired: dbgFwdFired,
                fwdFalseEof: dbgFwdFalseEof,
                fwdRealEof: dbgFwdRealEof,
                fwdDebounced: dbgFwdDebounced,
                isOfflineAtInit: isOfflineAtInit,
                isLiveOffline: isDeviceOffline,
                forwardSaved: forwardSaved,
                hasCachedPath: forwardCachePath != null,
                qualityInfo: dbgQualityInfo,
                log: dbgLog,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TrainingStudioControls(
                state: videoController.state,
                loading: loading,
                hasError: initError != null,
                isEditor: isEditor,
                annotations: annotations,
                onStepBackward: stepBackward,
                onStepForward: stepForward,
                onPlay: play,
                onPause: pause,
                onRestart: restart,
                onScrub: onScrub,
                onSetSpeed: setSpeed,
                onShowAnnotations: () => showAnnotationsPanel(seekToAnnotation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeVideo();
    super.dispose();
  }
}

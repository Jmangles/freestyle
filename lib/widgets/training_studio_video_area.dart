import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../constants/layout_constants.dart';
import '../models/trick_annotation.dart';
import '../video/training_video_state.dart';
import 'annotation_widgets.dart';

class TrainingStudioVideoArea extends StatelessWidget {
  final VideoController videoController;
  final TrainingVideoState state;
  final List<TrickAnnotation> annotations;
  final VoidCallback onTap;
  final void Function(TrickAnnotation) onAnnotationTap;

  const TrainingStudioVideoArea({
    super.key,
    required this.videoController,
    required this.state,
    required this.annotations,
    required this.onTap,
    required this.onAnnotationTap,
  });

  @override
  Widget build(BuildContext context) {
    final position = state.position;

    final videoStack = GestureDetector(
      onTap: onTap,
      child: Video(controller: videoController, controls: null, fit: BoxFit.fitHeight),
    );

    if (annotations.isEmpty) return videoStack;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kAnnotationSidebarBreakpoint) {
          return Stack(
            children: [
              Positioned.fill(child: videoStack),
              Positioned(
                top: 16,
                right: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight - 32),
                  child: MobileAnnotationOverlay(
                    annotations: annotations,
                    position: position,
                    onTap: onAnnotationTap,
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: videoStack),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AnnotationSidebar(
                annotations: annotations,
                position: position,
                onTap: onAnnotationTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

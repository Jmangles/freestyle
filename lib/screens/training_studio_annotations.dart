import 'package:flutter/material.dart';
import '../constants/playback_constants.dart';
import '../l10n/app_localizations_extension.dart';
import '../models/trick_annotation.dart';
import '../services/annotations_service.dart';
import '../services/auth_service.dart';
import '../utils/safe_state.dart';
import 'training_studio_dialogs.dart';

mixin TrainingStudioAnnotationsMixin<T extends StatefulWidget>
    on SafeStateMixin<T> {
  List<TrickAnnotation> annotations = [];
  bool isEditor = false;

  int get annotationTrickId;
  Duration get annotationCurrentPosition;
  Duration get annotationTotalDuration;

  Future<void> loadAnnotationsAndProfile() async {
    try {
      final language =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
          
      final annotationsFuture =
          AnnotationsService.getForTrick(annotationTrickId, language);
      final profileFuture = AuthService.getCurrentProfile();

      final annotationsList = await annotationsFuture;
      final profile = await profileFuture;

      safeSetState(() {
        annotations = annotationsList;
        isEditor = profile?.canEditTricks == true;
      });
    } catch (e, st) {
      debugPrint('TrainingStudio.loadAnnotationsAndProfile: $e\n$st');
    }
  }

  void showAnnotationsPanel(void Function(TrickAnnotation) onAnnotationTap) {
    showAnnotationsSheet(
      context,
      annotations: annotations,
      currentPosition: annotationCurrentPosition,
      onAnnotationTap: onAnnotationTap,
      onAddTapped: showAddAnnotationDialog,
      onEditTapped: showEditAnnotationDialog,
      onDeleteAnnotation: (a) async {
        final l10n = context.l10n;
        try {
          await AnnotationsService.delete(a.id);
        } catch (e) {
          showInfoSnackBar(l10n.couldNotDeleteAnnotation(e.toString()));
          return false;
        }
        safeSetState(() => annotations.removeWhere((x) => x.id == a.id));
        return true;
      },
    );
  }

  Future<void> showAddAnnotationDialog() async {
    final l10n = context.l10n;
    final totalMs = annotationTotalDuration.inMilliseconds;
    final startMs = annotationCurrentPosition.inMilliseconds;
    final endMs = (startMs + kAnnotationDefaultDurationMs).clamp(0, totalMs);
    final result = await showAnnotationFormDialog(
      context,
      startMs: startMs,
      endMs: endMs,
      text: '',
      language: 'en',
    );
    if (result == null || !mounted) return;
    try {
      final annotation = await AnnotationsService.create(
        trickId: annotationTrickId,
        startMs: result.$1,
        endMs: result.$2,
        text: result.$3,
        language: result.$4,
      );
      safeSetState(() {
        annotations = [...annotations, annotation]
          ..sort((a, b) => a.startMs.compareTo(b.startMs));
      });
    } catch (e) {
      showInfoSnackBar(l10n.couldNotSaveAnnotation(e.toString()));
    }
  }

  Future<void> showEditAnnotationDialog(TrickAnnotation annotation) async {
    final l10n = context.l10n;
    final result = await showAnnotationFormDialog(
      context,
      startMs: annotation.startMs,
      endMs: annotation.endMs,
      text: annotation.text,
      language: annotation.language,
    );
    if (result == null || !mounted) return;
    try {
      final updated = await AnnotationsService.update(
        annotation.id,
        startMs: result.$1,
        endMs: result.$2,
        text: result.$3,
        language: result.$4,
      );
      safeSetState(() {
        annotations =
            annotations.map((a) => a.id == annotation.id ? updated : a).toList();
      });
    } catch (e) {
      showInfoSnackBar(l10n.couldNotSaveAnnotation(e.toString()));
    }
  }
}

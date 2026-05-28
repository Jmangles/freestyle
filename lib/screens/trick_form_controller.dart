import 'package:flutter/material.dart';
import '../models/trick.dart';
import '../utils/string_utils.dart';

/// Holds all mutable form state and TextEditingControllers for the trick
/// submit/edit/suggest form, keeping them out of the screen widget.
class TrickFormController {
  final TextEditingController givenName;
  final TextEditingController technicalName;
  final TextEditingController originalPerformer;
  final TextEditingController description;
  final TextEditingController tips;
  final TextEditingController videoLink;
  final TextEditingController videoStart;
  final TextEditingController videoEnd;

  int difficultyTier;
  DateTime? datePerformed;
  int? startPositionId;
  int? endPositionId;
  List<int> prerequisiteIds;
  bool isCore;

  TrickFormController.fromTrick(Trick? t)
      : givenName = TextEditingController(text: t?.givenName),
        technicalName = TextEditingController(text: t?.technicalName),
        originalPerformer = TextEditingController(text: t?.originalPerformer),
        description = TextEditingController(text: t?.description),
        tips = TextEditingController(text: t?.tips),
        videoLink = TextEditingController(text: t?.videoLink),
        videoStart = TextEditingController(
            text: t?.videoStart != null ? '${t!.videoStart}' : ''),
        videoEnd = TextEditingController(
            text: t?.videoEnd != null ? '${t!.videoEnd}' : ''),
        difficultyTier = t?.difficultyTier ?? -1,
        datePerformed = t?.datePerformed,
        startPositionId = t?.startPositionId,
        endPositionId = t?.endPositionId,
        prerequisiteIds = t != null ? List.from(t.prerequisiteTrickIds) : [],
        isCore = false;

  Map<String, dynamic> get formFields => {
        'given_name': givenName.text.trim(),
        'technical_name': trimToNull(technicalName.text),
        'difficulty_tier': difficultyTier,
        'date_performed': datePerformed?.toIso8601String().split('T').first,
        'original_performer': trimToNull(originalPerformer.text),
        'prerequisite_trick_ids': prerequisiteIds,
        'description': trimToNull(description.text),
        'tips': trimToNull(tips.text),
        'video_link': trimToNull(videoLink.text),
        'video_start': int.tryParse(videoStart.text.trim()),
        'video_end': int.tryParse(videoEnd.text.trim()),
        'start_position_id': startPositionId,
        'end_position_id': endPositionId,
        'flags': isCore ? 1 : 0,
      };

  /// Returns only fields that differ from [original] and are non-null.
  Map<String, dynamic> computeSuggestionDelta(Trick original) {
    final fields = <String, dynamic>{};

    final name = givenName.text.trim();
    if (name.isNotEmpty && name != original.givenName) fields['given_name'] = name;

    final techName = trimToNull(technicalName.text);
    if (techName != null && techName != original.technicalName) fields['technical_name'] = techName;

    if (difficultyTier != original.difficultyTier) fields['difficulty_tier'] = difficultyTier;

    final origDate = original.datePerformed?.toIso8601String().split('T').first;
    final suggestedDate = datePerformed?.toIso8601String().split('T').first;
    if (suggestedDate != null && suggestedDate != origDate) fields['date_performed'] = suggestedDate;

    final performer = trimToNull(originalPerformer.text);
    if (performer != null && performer != original.originalPerformer) fields['original_performer'] = performer;

    final prereqsChanged =
        prerequisiteIds.length != original.prerequisiteTrickIds.length ||
        !prerequisiteIds.toSet().containsAll(original.prerequisiteTrickIds);
    if (prereqsChanged) fields['prerequisite_trick_ids'] = prerequisiteIds;

    final desc = trimToNull(description.text);
    if (desc != null && desc != original.description) fields['description'] = desc;

    final tipsText = trimToNull(tips.text);
    if (tipsText != null && tipsText != original.tips) fields['tips'] = tipsText;

    final video = trimToNull(videoLink.text);
    if (video != null && video != original.videoLink) fields['video_link'] = video;

    final start = int.tryParse(videoStart.text.trim());
    if (start != null && start != original.videoStart) fields['video_start'] = start;

    final end = int.tryParse(videoEnd.text.trim());
    if (end != null && end != original.videoEnd) fields['video_end'] = end;

    if (startPositionId != null && startPositionId != original.startPositionId) fields['start_position_id'] = startPositionId;
    if (endPositionId != null && endPositionId != original.endPositionId) fields['end_position_id'] = endPositionId;

    return fields;
  }

  void dispose() {
    givenName.dispose();
    technicalName.dispose();
    originalPerformer.dispose();
    description.dispose();
    tips.dispose();
    videoLink.dispose();
    videoStart.dispose();
    videoEnd.dispose();
  }
}

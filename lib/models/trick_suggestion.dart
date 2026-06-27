import '../utils/difficulty_tier.dart';

class TrickSuggestion {
  final int id;
  final int trickId;

  // All suggestion fields are nullable — null means "no change proposed".
  final String? givenName;
  final String? technicalName;
  final int? difficultyTier;
  final DateTime? datePerformed;
  final String? originalPerformer;
  final List<int>? prerequisiteTrickIds;
  final List<int>? baseTrickIds;
  final String? description;
  final String? tips;
  final String? videoLink;
  final int? videoStart;
  final int? videoEnd;
  final int? startPositionId;
  final int? endPositionId;
  final String? startPositionName;
  final String? endPositionName;

  final int? submittedBy;
  final DateTime dateSubmitted;

  String? get difficultyLabel =>
      difficultyTier != null ? DifficultyTier.label(difficultyTier!) : null;

  const TrickSuggestion({
    required this.id,
    required this.trickId,
    this.givenName,
    this.technicalName,
    this.difficultyTier,
    this.datePerformed,
    this.originalPerformer,
    this.prerequisiteTrickIds,
    this.baseTrickIds,
    this.description,
    this.tips,
    this.videoLink,
    this.videoStart,
    this.videoEnd,
    this.startPositionId,
    this.endPositionId,
    this.startPositionName,
    this.endPositionName,
    this.submittedBy,
    required this.dateSubmitted,
  });

  factory TrickSuggestion.fromJson(Map<String, dynamic> json) {
    final startPos = json['start_position'] as Map<String, dynamic>?;
    final endPos = json['end_position'] as Map<String, dynamic>?;
    return TrickSuggestion(
      id: json['id'] as int,
      trickId: json['trick_id'] as int,
      givenName: json['given_name'] as String?,
      technicalName: json['technical_name'] as String?,
      difficultyTier: json['difficulty_tier'] as int?,
      datePerformed: json['date_performed'] != null
          ? DateTime.parse(json['date_performed'] as String)
          : null,
      originalPerformer: json['original_performer'] as String?,
      prerequisiteTrickIds:
          (json['prerequisite_trick_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      baseTrickIds:
          (json['base_trick_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      description: json['description'] as String?,
      tips: json['tips'] as String?,
      videoLink: json['video_link'] as String?,
      videoStart: json['video_start'] as int?,
      videoEnd: json['video_end'] as int?,
      startPositionId: json['start_position_id'] as int?,
      endPositionId: json['end_position_id'] as int?,
      startPositionName: startPos?['name'] as String?,
      endPositionName: endPos?['name'] as String?,
      submittedBy: json['submitted_by'] as int?,
      dateSubmitted: DateTime.parse(json['date_submitted'] as String),
    );
  }

  /// Returns a Supabase update map from the non-null fields only.
  /// Since the table only stores changed fields, every non-null value
  /// is a proposed change and should be applied directly.
  Map<String, dynamic> toDeltaJson() => {
        if (givenName != null) 'given_name': givenName,
        if (technicalName != null) 'technical_name': technicalName,
        if (difficultyTier != null) 'difficulty_tier': difficultyTier,
        if (datePerformed != null)
          'date_performed': datePerformed!.toIso8601String().split('T').first,
        if (originalPerformer != null) 'original_performer': originalPerformer,
        if (prerequisiteTrickIds != null)
          'prerequisite_trick_ids': prerequisiteTrickIds,
        if (baseTrickIds != null) 'base_trick_ids': baseTrickIds,
        if (description != null) 'description': description,
        if (tips != null) 'tips': tips,
        if (videoLink != null) 'video_link': videoLink,
        if (videoStart != null) 'video_start': videoStart,
        if (videoEnd != null) 'video_end': videoEnd,
        if (startPositionId != null) 'start_position_id': startPositionId,
        if (endPositionId != null) 'end_position_id': endPositionId,
      };
}

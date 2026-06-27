import 'approval_status.dart';
import '../utils/difficulty_tier.dart';

class Trick {
  final int id;
  final String givenName;
  final String? technicalName;
  final int difficultyTier;
  final DateTime dateSubmitted;
  final DateTime? datePerformed;
  final String? originalPerformer;
  final List<int> prerequisiteTrickIds;
  final List<int> baseTrickIds;
  final String? description;
  final String? tips;
  final String? videoLink;
  final int? videoStart;
  final int? videoEnd;
  final int? startPositionId;
  final int? endPositionId;
  final ApprovalStatus status;
  final int? submittedBy;
  final int flags;

  // Joined via Supabase select
  final String? startPositionName;
  final String? endPositionName;

  bool get isCore => flags & 1 != 0;
  bool get hasTrainingVideo => flags & 2 != 0;

  static String tierLabel(int value) => DifficultyTier.label(value);

  String get difficultyLabel => DifficultyTier.label(difficultyTier);

  int get difficultyLogicalTier => DifficultyTier.logicalTier(difficultyTier);

  const Trick({
    required this.id,
    required this.givenName,
    this.technicalName,
    required this.difficultyTier,
    required this.dateSubmitted,
    this.datePerformed,
    this.originalPerformer,
    required this.prerequisiteTrickIds,
    required this.baseTrickIds,
    this.description,
    this.tips,
    this.videoLink,
    this.videoStart,
    this.videoEnd,
    this.startPositionId,
    this.endPositionId,
    required this.status,
    this.submittedBy,
    this.flags = 0,
    this.startPositionName,
    this.endPositionName,
  });

  factory Trick.fromJson(Map<String, dynamic> json) {
    final startPos = json['start_position'] as Map<String, dynamic>?;
    final endPos = json['end_position'] as Map<String, dynamic>?;
    return Trick(
      id: json['id'] as int,
      givenName: json['given_name'] as String,
      technicalName: json['technical_name'] as String?,
      difficultyTier: json['difficulty_tier'] as int,
      dateSubmitted: DateTime.parse(json['date_submitted'] as String),
      datePerformed: json['date_performed'] != null
          ? DateTime.parse(json['date_performed'] as String)
          : null,
      originalPerformer: json['original_performer'] as String?,
      prerequisiteTrickIds:
          (json['prerequisite_trick_ids'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              [],
      baseTrickIds:
          (json['base_trick_ids'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              [],
      description: json['description'] as String?,
      tips: json['tips'] as String?,
      videoLink: json['video_link'] as String?,
      videoStart: json['video_start'] as int?,
      videoEnd: json['video_end'] as int?,
      startPositionId: json['start_position_id'] as int?,
      endPositionId: json['end_position_id'] as int?,
      status: ApprovalStatus.fromIndex(json['status'] as int),
      submittedBy: json['submitted_by'] as int?,
      flags: json['flags'] as int? ?? 0,
      startPositionName: startPos?['name'] as String?,
      endPositionName: endPos?['name'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'given_name': givenName,
        'technical_name': technicalName,
        'difficulty_tier': difficultyTier,
        'date_performed': datePerformed?.toIso8601String().split('T').first,
        'original_performer': originalPerformer,
        'prerequisite_trick_ids': prerequisiteTrickIds,
        'base_trick_ids': baseTrickIds,
        'description': description,
        'tips': tips,
        'video_link': videoLink,
        'video_start': videoStart,
        'video_end': videoEnd,
        'start_position_id': startPositionId,
        'end_position_id': endPositionId,
      };

  Trick copyWith({
    String? givenName,
    String? technicalName,
    int? difficultyTier,
    DateTime? datePerformed,
    String? originalPerformer,
    List<int>? prerequisiteTrickIds,
    List<int>? baseTrickIds,
    String? description,
    String? tips,
    String? videoLink,
    int? videoStart,
    int? videoEnd,
    int? startPositionId,
    int? endPositionId,
    int? flags,
  }) =>
      Trick(
        id: id,
        givenName: givenName ?? this.givenName,
        technicalName: technicalName ?? this.technicalName,
        difficultyTier: difficultyTier ?? this.difficultyTier,
        dateSubmitted: dateSubmitted,
        datePerformed: datePerformed ?? this.datePerformed,
        originalPerformer: originalPerformer ?? this.originalPerformer,
        prerequisiteTrickIds:
            prerequisiteTrickIds ?? this.prerequisiteTrickIds,
        baseTrickIds: baseTrickIds ?? this.baseTrickIds,
        description: description ?? this.description,
        tips: tips ?? this.tips,
        videoLink: videoLink ?? this.videoLink,
        videoStart: videoStart ?? this.videoStart,
        videoEnd: videoEnd ?? this.videoEnd,
        startPositionId: startPositionId ?? this.startPositionId,
        endPositionId: endPositionId ?? this.endPositionId,
        status: status,
        submittedBy: submittedBy,
        flags: flags ?? this.flags,
      );
}

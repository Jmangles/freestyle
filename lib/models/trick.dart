class Trick {
  final int id;
  final String givenName;
  final String? technicalName;
  final int difficultyTier;
  final DateTime dateSubmitted;
  final DateTime? datePerformed;
  final String? originalPerformer;
  final List<int> prerequisiteTrickIds;
  final String? description;
  final String? tips;
  final String? videoLink;
  final int? startPositionId;
  final int? endPositionId;
  final int status;
  final int? submittedBy;

  // Joined via Supabase select
  final String? startPositionName;
  final String? endPositionName;

  // Converts a raw difficulty value (1–30) to a display label like "1-", "1", "1+".
  // Every 3 consecutive values map to one logical tier: 1–3 → Tier 1, 4–6 → Tier 2, etc.
  static String tierLabel(int value) {
    if (value == -1) return 'TBD';
    final tier = (value - 1) ~/ 3 + 1;
    const suffixes = ['-', '', '+'];
    final suffix = suffixes[(value - 1) % 3];
    return '$tier$suffix';
  }

  String get difficultyLabel => Trick.tierLabel(difficultyTier);

  int get difficultyLogicalTier {
    if (difficultyTier == -1) return -1;
    return (difficultyTier - 1) ~/ 3 + 1;
  }

  const Trick({
    required this.id,
    required this.givenName,
    this.technicalName,
    required this.difficultyTier,
    required this.dateSubmitted,
    this.datePerformed,
    this.originalPerformer,
    required this.prerequisiteTrickIds,
    this.description,
    this.tips,
    this.videoLink,
    this.startPositionId,
    this.endPositionId,
    required this.status,
    this.submittedBy,
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
      description: json['description'] as String?,
      tips: json['tips'] as String?,
      videoLink: json['video_link'] as String?,
      startPositionId: json['start_position_id'] as int?,
      endPositionId: json['end_position_id'] as int?,
      status: json['status'] as int,
      submittedBy: json['submitted_by'] as int?,
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
        'description': description,
        'tips': tips,
        'video_link': videoLink,
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
    String? description,
    String? tips,
    String? videoLink,
    int? startPositionId,
    int? endPositionId,
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
        description: description ?? this.description,
        tips: tips ?? this.tips,
        videoLink: videoLink ?? this.videoLink,
        startPositionId: startPositionId ?? this.startPositionId,
        endPositionId: endPositionId ?? this.endPositionId,
        status: status,
        submittedBy: submittedBy,
      );
}

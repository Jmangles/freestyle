class TrickAnnotation {
  final int id;
  final int trickId;
  final int startMs;
  final int endMs;
  final String text;
  final String language;

  const TrickAnnotation({
    required this.id,
    required this.trickId,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.language = 'en',
  });

  factory TrickAnnotation.fromJson(Map<String, dynamic> json) => TrickAnnotation(
        id: json['id'] as int,
        trickId: json['trick_id'] as int,
        startMs: json['start_ms'] as int,
        endMs: json['end_ms'] as int,
        text: json['text'] as String,
        language: json['language'] as String? ?? 'en',
      );

  bool isActiveAt(Duration position) {
    final ms = position.inMilliseconds;
    return ms >= startMs && ms <= endMs;
  }
}

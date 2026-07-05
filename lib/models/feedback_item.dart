class FeedbackItem {
  final int id;
  final int? submittedBy;
  final String message;
  final String? attachmentPath;
  final String status;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    this.submittedBy,
    required this.message,
    this.attachmentPath,
    required this.status,
    required this.createdAt,
  });

  bool get isImageAttachment {
    final path = attachmentPath;
    if (path == null) return false;
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.heic') ||
        ext.endsWith('.heif');
  }

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
        id: json['id'] as int,
        submittedBy: json['submitted_by'] as int?,
        message: json['message'] as String,
        attachmentPath: json['attachment_path'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

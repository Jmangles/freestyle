class FeedbackItem {
  final int id;
  final int? submittedBy;
  final String message;
  final List<String> attachmentPaths;
  final String status;
  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    this.submittedBy,
    required this.message,
    this.attachmentPaths = const [],
    required this.status,
    required this.createdAt,
  });

  static bool isImagePath(String path) {
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
        attachmentPaths:
            (json['attachment_paths'] as List?)?.cast<String>() ?? const [],
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FeedbackAttachment {
  final String path;
  final String signedUrl;

  const FeedbackAttachment({required this.path, required this.signedUrl});

  bool get isImage => FeedbackItem.isImagePath(path);
}

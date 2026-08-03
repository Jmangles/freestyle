class FeedbackItem {
  final int id;
  final int? submittedBy;
  final String? submitterUsername;
  final String status;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final DateTime? userLastReadAt;
  final List<FeedbackMessage> messages;

  const FeedbackItem({
    required this.id,
    this.submittedBy,
    this.submitterUsername,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    this.userLastReadAt,
    this.messages = const [],
  });

  static const statusNew = 'new';
  static const statusAnswered = 'answered';
  static const statusReviewed = 'reviewed';
  static const statusDismissed = 'dismissed';

  bool get isClosed => status == statusReviewed || status == statusDismissed;
  bool get isAwaitingUser => status == statusAnswered;

  bool get hasUnread =>
      userLastReadAt == null || lastMessageAt.isAfter(userLastReadAt!);

  FeedbackMessage? get firstMessage => messages.isEmpty ? null : messages.first;

  List<String> get attachmentPaths =>
      [for (final m in messages) ...m.attachmentPaths];

  bool isFromOwner(FeedbackMessage message) =>
      message.authorId != null && message.authorId == submittedBy;

  static bool isImagePath(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.heic') ||
        ext.endsWith('.heif');
  }

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    final messages = (json['feedback_messages'] as List?)
            ?.map((e) => FeedbackMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <FeedbackMessage>[];
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final createdAt = DateTime.parse(json['created_at'] as String);
    return FeedbackItem(
      id: json['id'] as int,
      submittedBy: json['submitted_by'] as int?,
      submitterUsername: (json['profiles'] as Map?)?['username'] as String?,
      status: json['status'] as String,
      createdAt: createdAt,
      lastMessageAt: json['last_message_at'] == null
          ? createdAt
          : DateTime.parse(json['last_message_at'] as String),
      userLastReadAt: json['user_last_read_at'] == null
          ? null
          : DateTime.parse(json['user_last_read_at'] as String),
      messages: messages,
    );
  }
}

class FeedbackMessage {
  final int id;
  final int feedbackId;
  final int? authorId;
  final String? authorUsername;
  final String body;
  final List<String> attachmentPaths;
  final DateTime createdAt;

  const FeedbackMessage({
    required this.id,
    required this.feedbackId,
    this.authorId,
    this.authorUsername,
    required this.body,
    this.attachmentPaths = const [],
    required this.createdAt,
  });

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) => FeedbackMessage(
        id: json['id'] as int,
        feedbackId: json['feedback_id'] as int,
        authorId: json['author_id'] as int?,
        authorUsername: (json['profiles'] as Map?)?['username'] as String?,
        body: json['body'] as String,
        attachmentPaths:
            (json['attachment_paths'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FeedbackAttachment {
  final String path;
  final String signedUrl;

  const FeedbackAttachment({required this.path, required this.signedUrl});

  bool get isImage => FeedbackItem.isImagePath(path);
}

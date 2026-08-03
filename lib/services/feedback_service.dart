import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feedback_item.dart';

class FeedbackService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'feedback-attachments';

  static const _threadSelect =
      '*, profiles(username), feedback_messages(*, profiles(username))';

  // Head and first message are created together server-side; a client-side
  // two-step would leave an empty thread behind if the message insert failed.
  static Future<int> submitFeedback({
    required String message,
    required int submittedBy,
    List<FeedbackAttachmentUpload> attachments = const [],
  }) async {
    final uploadedPaths = <String>[];
    try {
      await _upload(submittedBy, attachments, uploadedPaths);
      final id = await _client.rpc('submit_feedback', params: {
        'p_message': message,
        'p_attachment_paths': uploadedPaths.isEmpty ? null : uploadedPaths,
      });
      return id as int;
    } catch (_) {
      await _discardUploads(uploadedPaths);
      rethrow;
    }
  }

  static Future<void> postMessage({
    required int feedbackId,
    required int authorId,
    required String body,
    List<FeedbackAttachmentUpload> attachments = const [],
  }) async {
    final uploadedPaths = <String>[];
    try {
      await _upload(authorId, attachments, uploadedPaths);
      await _client.from('feedback_messages').insert({
        'feedback_id': feedbackId,
        'author_id': authorId,
        'body': body,
        if (uploadedPaths.isNotEmpty) 'attachment_paths': uploadedPaths,
      });
    } catch (_) {
      await _discardUploads(uploadedPaths);
      rethrow;
    }
  }

  static Future<void> _upload(
    int authorId,
    List<FeedbackAttachmentUpload> attachments,
    List<String> uploadedPaths,
  ) async {
    for (final a in attachments) {
      final path =
          '$authorId/${DateTime.now().microsecondsSinceEpoch}_${uploadedPaths.length}.${a.extension}';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            a.bytes,
            fileOptions: FileOptions(contentType: a.mimeType),
          );
      uploadedPaths.add(path);
    }
  }

  static Future<void> _discardUploads(List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(_bucket).remove(paths);
  }

  // Admin queue: threads waiting on an admin first, then ones the user has
  // already been answered on and may still reply to.
  static Future<List<FeedbackItem>> getPendingFeedback() async {
    final data = await _client
        .from('feedback')
        .select(_threadSelect)
        .inFilter('status',
            [FeedbackItem.statusNew, FeedbackItem.statusAnswered])
        .order('last_message_at', ascending: true);
    return (data as List)
        .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<FeedbackItem>> getMyThreads(int submittedBy) async {
    final data = await _client
        .from('feedback')
        .select(_threadSelect)
        .eq('submitted_by', submittedBy)
        .order('last_message_at', ascending: false);
    return (data as List)
        .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<FeedbackItem> getThread(int feedbackId) async {
    final data = await _client
        .from('feedback')
        .select(_threadSelect)
        .eq('id', feedbackId)
        .single();
    return FeedbackItem.fromJson(data);
  }

  static Future<void> markRead(int feedbackId) async {
    await _client.rpc('mark_feedback_read', params: {'p_feedback_id': feedbackId});
  }

  static Future<int> unreadCount() async {
    final count = await _client.rpc('unread_feedback_count');
    return (count as int?) ?? 0;
  }

  static Future<String> getAttachmentUrl(String path) async {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  static Future<Map<int, List<FeedbackAttachment>>> signAttachments(
      List<FeedbackItem> threads) async {
    final signed = <int, List<FeedbackAttachment>>{};
    for (final thread in threads) {
      for (final message in thread.messages) {
        final list = <FeedbackAttachment>[];
        for (final path in message.attachmentPaths) {
          try {
            list.add(FeedbackAttachment(
              path: path,
              signedUrl: await getAttachmentUrl(path),
            ));
          } catch (_) {
            // A missing or expired object shouldn't blank out the message.
          }
        }
        if (list.isNotEmpty) signed[message.id] = list;
      }
    }
    return signed;
  }

  static String downloadUrl(String signedUrl, String path) =>
      '$signedUrl&download=${Uri.encodeComponent(path.split('/').last)}';

  // Closing a thread is terminal, so its attachments go with it.
  static Future<void> resolveFeedback(FeedbackItem item, String status) async {
    final paths = item.attachmentPaths;
    if (paths.isNotEmpty) {
      await _client.storage.from(_bucket).remove(paths);
    }
    await _client.from('feedback').update({'status': status}).eq('id', item.id);
  }
}

class FeedbackAttachmentUpload {
  final Uint8List bytes;
  final String extension;
  final String? mimeType;

  const FeedbackAttachmentUpload({
    required this.bytes,
    required this.extension,
    this.mimeType,
  });
}

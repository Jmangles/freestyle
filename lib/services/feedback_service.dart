import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feedback_item.dart';

class FeedbackService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'feedback-attachments';

  static Future<void> submitFeedback({
    required String message,
    required int submittedBy,
    List<FeedbackAttachmentUpload> attachments = const [],
  }) async {
    final uploadedPaths = <String>[];
    try {
      for (final a in attachments) {
        final path =
            '$submittedBy/${DateTime.now().microsecondsSinceEpoch}_${uploadedPaths.length}.${a.extension}';
        await _client.storage.from(_bucket).uploadBinary(
              path,
              a.bytes,
              fileOptions: FileOptions(contentType: a.mimeType),
            );
        uploadedPaths.add(path);
      }
      await _client.from('feedback').insert({
        'submitted_by': submittedBy,
        'message': message,
        if (uploadedPaths.isNotEmpty) 'attachment_paths': uploadedPaths,
      });
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        await _client.storage.from(_bucket).remove(uploadedPaths);
      }
      rethrow;
    }
  }

  static Future<List<FeedbackItem>> getPendingFeedback() async {
    final data = await _client
        .from('feedback')
        .select()
        .eq('status', 'new')
        .order('created_at', ascending: true);
    return (data as List).map((e) => FeedbackItem.fromJson(e)).toList();
  }

  static Future<String> getAttachmentUrl(String path) async {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  static String downloadUrl(String signedUrl, String path) =>
      '$signedUrl&download=${Uri.encodeComponent(path.split('/').last)}';

  static Future<void> resolveFeedback(FeedbackItem item, String status) async {
    if (item.attachmentPaths.isNotEmpty) {
      await _client.storage.from(_bucket).remove(item.attachmentPaths);
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

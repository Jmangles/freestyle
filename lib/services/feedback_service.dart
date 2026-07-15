import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feedback_item.dart';

class FeedbackService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'feedback-attachments';

  static Future<void> submitFeedback({
    required String message,
    required int submittedBy,
    Uint8List? attachmentBytes,
    String? attachmentExtension,
    String? attachmentMimeType,
  }) async {
    String? attachmentPath;
    if (attachmentBytes != null && attachmentExtension != null) {
      attachmentPath =
          '$submittedBy/${DateTime.now().millisecondsSinceEpoch}.$attachmentExtension';
      await _client.storage.from(_bucket).uploadBinary(
            attachmentPath,
            attachmentBytes,
            fileOptions: FileOptions(contentType: attachmentMimeType),
          );
    }
    try {
      await _client.from('feedback').insert({
        'submitted_by': submittedBy,
        'message': message,
        if (attachmentPath != null) 'attachment_path': attachmentPath,
      });
    } catch (_) {
      if (attachmentPath != null) {
        await _client.storage.from(_bucket).remove([attachmentPath]);
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

  static Future<void> resolveFeedback(FeedbackItem item, String status) async {
    if (item.attachmentPath != null) {
      await _client.storage.from(_bucket).remove([item.attachmentPath!]);
    }
    await _client.from('feedback').update({'status': status}).eq('id', item.id);
  }
}

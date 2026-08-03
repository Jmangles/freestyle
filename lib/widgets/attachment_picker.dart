import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations_extension.dart';
import '../services/feedback_service.dart';

const int maxAttachmentBytes = 10 * 1024 * 1024;

class PickedAttachment {
  final Uint8List bytes;
  final String name;
  final String extension;
  final String? mimeType;

  const PickedAttachment({
    required this.bytes,
    required this.name,
    required this.extension,
    this.mimeType,
  });

  FeedbackAttachmentUpload toUpload() => FeedbackAttachmentUpload(
        bytes: bytes,
        extension: extension,
        mimeType: mimeType,
      );
}

class PickedAttachments {
  final List<PickedAttachment> attachments;
  final bool skippedTooLarge;

  const PickedAttachments(this.attachments, this.skippedTooLarge);
}

String? _mimeTypeFromExtension(String extension) => switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => null,
    };

Future<PickedAttachments> pickImageAttachments(ImagePicker picker) async {
  final files = await picker.pickMultiImage();
  if (files.isEmpty) return const PickedAttachments([], false);
  var skippedTooLarge = false;
  final picked = <PickedAttachment>[];
  for (final file in files) {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxAttachmentBytes) {
      skippedTooLarge = true;
      continue;
    }
    final extension =
        file.name.contains('.') ? file.name.split('.').last.toLowerCase() : null;
    final mimeType = file.mimeType ??
        (extension != null ? _mimeTypeFromExtension(extension) : null);
    picked.add(PickedAttachment(
      bytes: bytes,
      name: file.name,
      extension: extension ?? 'jpg',
      mimeType: mimeType,
    ));
  }
  return PickedAttachments(picked, skippedTooLarge);
}

class AttachmentPreview extends StatelessWidget {
  final Uint8List bytes;
  final String name;
  final VoidCallback onRemove;

  const AttachmentPreview({
    super.key,
    required this.bytes,
    required this.name,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.removeAttachmentTooltip,
          onPressed: onRemove,
        ),
      ),
    );
  }
}

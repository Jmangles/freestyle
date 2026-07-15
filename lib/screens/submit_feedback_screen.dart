import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations_extension.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';

class SubmitFeedbackScreen extends StatefulWidget {
  const SubmitFeedbackScreen({super.key});

  @override
  State<SubmitFeedbackScreen> createState() => _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState extends State<SubmitFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _attachmentBytes;
  String? _attachmentName;
  String? _attachmentExtension;
  String? _attachmentMimeType;
  bool _saving = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  String? _mimeTypeFromExtension(String extension) => switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => null,
      };

  static const _maxAttachmentBytes = 10 * 1024 * 1024;

  Future<void> _pickAttachment() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxAttachmentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.attachmentTooLarge),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : null;
    final mimeType = file.mimeType ?? (extension != null ? _mimeTypeFromExtension(extension) : null);
    setState(() {
      _attachmentBytes = bytes;
      _attachmentName = file.name;
      _attachmentExtension = extension ?? 'jpg';
      _attachmentMimeType = mimeType;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachmentBytes = null;
      _attachmentName = null;
      _attachmentExtension = null;
      _attachmentMimeType = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile == null) throw StateError('Not signed in');
      await FeedbackService.submitFeedback(
        message: _messageCtrl.text.trim(),
        submittedBy: profile.intId,
        attachmentBytes: _attachmentBytes,
        attachmentExtension: _attachmentExtension,
        attachmentMimeType: _attachmentMimeType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.feedbackSubmitted)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Feedback submit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.feedbackSubmitError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.submitFeedbackTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.feedbackMessageLabel, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageCtrl,
              minLines: 5,
              maxLines: 10,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: l10n.feedbackMessageHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.requiredValidator : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            if (_attachmentBytes == null)
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file),
                label: Text(l10n.attachFileButton),
              )
            else
              _AttachmentPreview(
                bytes: _attachmentBytes!,
                name: _attachmentName ?? '',
                onRemove: _removeAttachment,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.submitFeedbackButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final Uint8List bytes;
  final String name;
  final VoidCallback onRemove;

  const _AttachmentPreview({
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

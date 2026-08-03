import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations_extension.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../widgets/attachment_picker.dart';

class SubmitFeedbackScreen extends StatefulWidget {
  const SubmitFeedbackScreen({super.key});

  @override
  State<SubmitFeedbackScreen> createState() => _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState extends State<SubmitFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  final _picker = ImagePicker();

  final List<PickedAttachment> _attachments = [];
  bool _saving = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final picked = await pickImageAttachments(_picker);
    if (!mounted) return;
    setState(() => _attachments.addAll(picked.attachments));
    if (picked.skippedTooLarge) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.attachmentTooLarge),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
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
        attachments: [for (final a in _attachments) a.toUpload()],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.feedbackSubmitted,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
            OutlinedButton.icon(
              onPressed: _pickAttachments,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.attachFileButton),
            ),
            for (int i = 0; i < _attachments.length; i++) ...[
              const SizedBox(height: 8),
              AttachmentPreview(
                bytes: _attachments[i].bytes,
                name: _attachments[i].name,
                onRemove: () => _removeAttachment(i),
              ),
            ],
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

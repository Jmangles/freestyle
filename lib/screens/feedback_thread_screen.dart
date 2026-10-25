import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations_extension.dart';
import '../models/feedback_item.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../utils/safe_state.dart';
import '../widgets/attachment_picker.dart';
import '../widgets/feedback_message_list.dart';
import 'admin_screen.dart' show approveButtonStyle, rejectButtonStyle;

class FeedbackThreadScreen extends StatefulWidget {
  final int feedbackId;

  /// Admins get the review actions pinned above the conversation.
  final bool adminMode;

  const FeedbackThreadScreen({
    super.key,
    required this.feedbackId,
    this.adminMode = false,
  });

  @override
  State<FeedbackThreadScreen> createState() => _FeedbackThreadScreenState();
}

class _FeedbackThreadScreenState extends State<FeedbackThreadScreen>
    with SafeStateMixin {
  final _replyCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<PickedAttachment> _attachments = [];

  late Future<_ThreadView> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<_ThreadView> _load() async {
    final profile = await AuthService.getCurrentProfile();
    final thread = await FeedbackService.getThread(widget.feedbackId);
    final attachments = await FeedbackService.signAttachments([thread]);
    final unseen = thread.unseenMessageIds(
        asAdmin: widget.adminMode, viewerId: profile?.intId);
    final needsRead =
        widget.adminMode ? thread.hasUnreadForAdmin : thread.hasUnread;
    if (needsRead) {
      try {
        await FeedbackService.markRead(thread.id);
      } catch (e) {
        debugPrint('Feedback mark read failed: $e');
      }
    }
    return _ThreadView(
      thread: thread,
      attachments: attachments,
      viewerId: profile?.intId,
      unseenIds: unseen,
    );
  }

  void _refresh() => safeSetState(() {
        _future = _load();
      });

  Future<void> _pick() async {
    final picked = await pickImageAttachments(_picker);
    if (!mounted) return;
    safeSetState(() => _attachments.addAll(picked.attachments));
    if (picked.skippedTooLarge) showErrorSnackBar(context.l10n.attachmentTooLarge);
  }

  Future<void> _send(int viewerId) async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty) return;
    safeSetState(() => _sending = true);
    try {
      await FeedbackService.postMessage(
        feedbackId: widget.feedbackId,
        authorId: viewerId,
        body: body,
        attachments: [for (final a in _attachments) a.toUpload()],
      );
      _replyCtrl.clear();
      _attachments.clear();
      if (mounted) showInfoSnackBar(context.l10n.feedbackReplySent);
      _refresh();
    } catch (e) {
      debugPrint('Feedback reply failed: $e');
      if (mounted) showErrorSnackBar(context.l10n.feedbackReplyError);
    } finally {
      safeSetState(() => _sending = false);
    }
  }

  Future<void> _resolve(FeedbackItem thread, String status) async {
    try {
      await FeedbackService.resolveFeedback(thread, status);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Feedback resolve failed: $e');
      if (mounted) showErrorSnackBar(context.l10n.feedbackResolveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackThreadTitle(widget.feedbackId))),
      body: FutureBuilder<_ThreadView>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(child: Text(l10n.feedbackLoadError));
          }
          final view = snap.data!;
          return Column(
            children: [
              if (widget.adminMode && !view.thread.isClosed) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _resolve(view.thread, 'reviewed'),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l10n.markReviewedButton),
                          style: approveButtonStyle(theme),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _resolve(view.thread, 'dismissed'),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(l10n.dismissButton),
                          style: rejectButtonStyle(theme),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FeedbackMessageList(
                      thread: view.thread,
                      attachments: view.attachments,
                      viewerId: view.viewerId,
                      unseenIds: view.unseenIds,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (view.thread.isClosed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.feedbackThreadClosed,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (view.viewerId != null)
                _ReplyComposer(
                  controller: _replyCtrl,
                  attachments: _attachments,
                  sending: _sending,
                  onPick: _pick,
                  onRemove: (i) => safeSetState(() => _attachments.removeAt(i)),
                  onSend: () => _send(view.viewerId!),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ThreadView {
  final FeedbackItem thread;
  final Map<int, List<FeedbackAttachment>> attachments;
  final int? viewerId;
  final Set<int> unseenIds;

  const _ThreadView({
    required this.thread,
    required this.attachments,
    this.viewerId,
    this.unseenIds = const {},
  });
}

/// Height of the empty text field; the attach and send buttons match it.
const double _controlSize = 48;

class _ReplyComposer extends StatelessWidget {
  final TextEditingController controller;
  final List<PickedAttachment> attachments;
  final bool sending;
  final VoidCallback onPick;
  final void Function(int index) onRemove;
  final VoidCallback onSend;

  const _ReplyComposer({
    required this.controller,
    required this.attachments,
    required this.sending,
    required this.onPick,
    required this.onRemove,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < attachments.length; i++)
              AttachmentPreview(
                bytes: attachments[i].bytes,
                name: attachments[i].name,
                onRemove: () => onRemove(i),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: l10n.attachFileButton,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(_controlSize, _controlSize),
                  ),
                  onPressed: sending ? null : onPick,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    // Fixed line height + padding make the empty field exactly
                    // _controlSize tall, matching the buttons beside it.
                    strutStyle: const StrutStyle(
                      fontSize: 16,
                      height: 1.5,
                      forceStrutHeight: true,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.feedbackReplyHint,
                      border: const OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: (_controlSize - 24) / 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : onSend,
                  tooltip: l10n.feedbackSendReply,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(_controlSize, _controlSize),
                    shape: const CircleBorder(),
                  ),
                  icon: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

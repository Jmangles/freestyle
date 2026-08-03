import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations_extension.dart';
import '../models/feedback_item.dart';
import '../services/feedback_service.dart';
import '../utils/date_formatters.dart';

class FeedbackMessageList extends StatelessWidget {
  final FeedbackItem thread;
  final Map<int, List<FeedbackAttachment>> attachments;
  final int? viewerId;

  const FeedbackMessageList({
    super.key,
    required this.thread,
    this.attachments = const {},
    this.viewerId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < thread.messages.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _FeedbackMessageBubble(
            message: thread.messages[i],
            fromOwner: thread.isFromOwner(thread.messages[i]),
            isMine: viewerId != null && thread.messages[i].authorId == viewerId,
            attachments: attachments[thread.messages[i].id] ?? const [],
          ),
        ],
      ],
    );
  }
}

class _FeedbackMessageBubble extends StatelessWidget {
  final FeedbackMessage message;
  final bool fromOwner;
  final bool isMine;
  final List<FeedbackAttachment> attachments;

  const _FeedbackMessageBubble({
    required this.message,
    required this.fromOwner,
    required this.isMine,
    required this.attachments,
  });

  String _author(BuildContext context) {
    final l10n = context.l10n;
    if (isMine) return l10n.feedbackFromYou;
    if (!fromOwner) return l10n.feedbackFromTeam;
    return message.authorUsername ?? l10n.feedbackUnknownUser;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final background = fromOwner
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    final foreground = fromOwner
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onPrimaryContainer;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _author(context),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatShortDate(message.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(message.body, style: TextStyle(color: foreground)),
              for (final attachment in attachments) ...[
                const SizedBox(height: 12),
                if (attachment.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      attachment.signedUrl,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 160,
                        alignment: Alignment.center,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined,
                            color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(FeedbackService.downloadUrl(
                          attachment.signedUrl, attachment.path)),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(l10n.downloadButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String feedbackStatusLabel(BuildContext context, FeedbackItem thread) {
  final l10n = context.l10n;
  return switch (thread.status) {
    FeedbackItem.statusAnswered => l10n.feedbackStatusAnswered,
    FeedbackItem.statusReviewed => l10n.feedbackStatusReviewed,
    FeedbackItem.statusDismissed => l10n.feedbackStatusDismissed,
    _ => l10n.feedbackStatusNew,
  };
}

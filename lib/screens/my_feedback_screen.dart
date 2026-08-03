import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations_extension.dart';
import '../models/feedback_item.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../utils/date_formatters.dart';
import '../utils/safe_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/feedback_message_list.dart';

class MyFeedbackScreen extends StatefulWidget {
  const MyFeedbackScreen({super.key});

  @override
  State<MyFeedbackScreen> createState() => _MyFeedbackScreenState();
}

class _MyFeedbackScreenState extends State<MyFeedbackScreen> with SafeStateMixin {
  late Future<List<FeedbackItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FeedbackItem>> _load() async {
    final Profile? profile = await AuthService.getCurrentProfile();
    if (profile == null) return [];
    return FeedbackService.getMyThreads(profile.intId);
  }

  void _refresh() => safeSetState(() => _future = _load());

  Future<void> _openThread(int id) async {
    await context.push<void>('/feedback/mine/$id');
    _refresh();
  }

  Future<void> _compose() async {
    await context.push<void>('/feedback');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myFeedbackTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        tooltip: l10n.newFeedbackTooltip,
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: FutureBuilder<List<FeedbackItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(l10n.feedbackLoadError));
          }
          final threads = snap.data ?? const <FeedbackItem>[];
          if (threads.isEmpty) {
            return EmptyState(
              asset: 'assets/img/arms_crossed.svg',
              message: l10n.noFeedbackYet,
              action: FilledButton(
                onPressed: _compose,
                child: Text(l10n.submitFeedbackButton),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _FeedbackThreadTile(
                thread: threads[i],
                onTap: () => _openThread(threads[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedbackThreadTile extends StatelessWidget {
  final FeedbackItem thread;
  final VoidCallback onTap;

  const _FeedbackThreadTile({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = thread.firstMessage?.body ?? '';
    return Card(
      child: Opacity(
        opacity: thread.isClosed ? 0.6 : 1,
        child: ListTile(
          onTap: onTap,
          title: Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(feedbackStatusLabel(context, thread),
                    style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Text(formatShortDate(thread.lastMessageAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          trailing: thread.hasUnread
              ? Icon(Icons.circle, size: 12, color: theme.colorScheme.primary)
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

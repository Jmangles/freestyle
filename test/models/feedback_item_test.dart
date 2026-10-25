import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/models/feedback_item.dart';

Map<String, dynamic> _message({
  required int id,
  required int? authorId,
  required String body,
  required String createdAt,
  List<String>? attachments,
  String? username,
}) =>
    {
      'id': id,
      'feedback_id': 1,
      'author_id': authorId,
      'body': body,
      'created_at': createdAt,
      'attachment_paths': attachments,
      if (username != null) 'profiles': {'username': username},
    };

Map<String, dynamic> _thread({
  String status = 'new',
  String? userLastReadAt,
  String lastMessageAt = '2026-08-02T10:00:00Z',
  List<Map<String, dynamic>>? messages,
}) =>
    {
      'id': 1,
      'submitted_by': 7,
      'status': status,
      'created_at': '2026-08-01T09:00:00Z',
      'last_message_at': lastMessageAt,
      'user_last_read_at': userLastReadAt,
      'profiles': {'username': 'lineworm'},
      'feedback_messages': messages ??
          [
            _message(
              id: 10,
              authorId: 7,
              body: 'The timer resets on lap 3',
              createdAt: '2026-08-01T09:00:00Z',
            ),
          ],
    };

void main() {
  group('FeedbackItem.fromJson', () {
    test('reads the thread head and its submitter', () {
      final item = FeedbackItem.fromJson(_thread());

      expect(item.id, 1);
      expect(item.submittedBy, 7);
      expect(item.submitterUsername, 'lineworm');
      expect(item.status, FeedbackItem.statusNew);
      expect(item.lastMessageAt, DateTime.parse('2026-08-02T10:00:00Z'));
    });

    test('sorts messages oldest first regardless of embed order', () {
      final item = FeedbackItem.fromJson(_thread(messages: [
        _message(
          id: 11,
          authorId: 2,
          body: 'Which lap counter mode?',
          createdAt: '2026-08-02T10:00:00Z',
          username: 'admin',
        ),
        _message(
          id: 10,
          authorId: 7,
          body: 'The timer resets on lap 3',
          createdAt: '2026-08-01T09:00:00Z',
        ),
      ]));

      expect(item.messages.map((m) => m.id), [10, 11]);
      expect(item.firstMessage?.body, 'The timer resets on lap 3');
      expect(item.messages.last.authorUsername, 'admin');
    });

    test('falls back to created_at when last_message_at is absent', () {
      final json = _thread()..remove('last_message_at');
      final item = FeedbackItem.fromJson(json);

      expect(item.lastMessageAt, item.createdAt);
    });

    test('collects attachment paths across every message', () {
      final item = FeedbackItem.fromJson(_thread(messages: [
        _message(
          id: 10,
          authorId: 7,
          body: 'Screenshot',
          createdAt: '2026-08-01T09:00:00Z',
          attachments: ['7/a.png'],
        ),
        _message(
          id: 11,
          authorId: 7,
          body: 'One more',
          createdAt: '2026-08-02T10:00:00Z',
          attachments: ['7/b.jpg'],
        ),
      ]));

      expect(item.attachmentPaths, ['7/a.png', '7/b.jpg']);
    });
  });

  group('unread', () {
    test('a thread never opened is unread', () {
      expect(FeedbackItem.fromJson(_thread()).hasUnread, isTrue);
    });

    test('activity after the last read is unread', () {
      final item = FeedbackItem.fromJson(_thread(
        lastMessageAt: '2026-08-02T10:00:00Z',
        userLastReadAt: '2026-08-01T09:00:00Z',
      ));

      expect(item.hasUnread, isTrue);
    });

    test('nothing new since the last read is read', () {
      final item = FeedbackItem.fromJson(_thread(
        lastMessageAt: '2026-08-02T10:00:00Z',
        userLastReadAt: '2026-08-02T10:00:00Z',
      ));

      expect(item.hasUnread, isFalse);
    });
  });

  group('status', () {
    test('reviewed and dismissed are closed, new and answered are not', () {
      expect(FeedbackItem.fromJson(_thread(status: 'reviewed')).isClosed, isTrue);
      expect(
          FeedbackItem.fromJson(_thread(status: 'dismissed')).isClosed, isTrue);
      expect(FeedbackItem.fromJson(_thread(status: 'new')).isClosed, isFalse);
      expect(
          FeedbackItem.fromJson(_thread(status: 'answered')).isClosed, isFalse);
    });

    test('answered means the thread waits on the user', () {
      expect(FeedbackItem.fromJson(_thread(status: 'answered')).isAwaitingUser,
          isTrue);
      expect(
          FeedbackItem.fromJson(_thread(status: 'new')).isAwaitingUser, isFalse);
    });
  });

  test('isFromOwner separates the submitter from admin replies', () {
    final item = FeedbackItem.fromJson(_thread(messages: [
      _message(
        id: 10,
        authorId: 7,
        body: 'The timer resets on lap 3',
        createdAt: '2026-08-01T09:00:00Z',
      ),
      _message(
        id: 11,
        authorId: 2,
        body: 'Which lap counter mode?',
        createdAt: '2026-08-02T10:00:00Z',
      ),
    ]));

    expect(item.isFromOwner(item.messages[0]), isTrue);
    expect(item.isFromOwner(item.messages[1]), isFalse);
  });

  test('a message from a deleted account is not attributed to the owner', () {
    final item = FeedbackItem.fromJson({
      ..._thread(),
      'submitted_by': null,
      'feedback_messages': [
        _message(
          id: 10,
          authorId: null,
          body: 'Orphaned',
          createdAt: '2026-08-01T09:00:00Z',
        ),
      ],
    });

    expect(item.isFromOwner(item.messages.first), isFalse);
  });
}

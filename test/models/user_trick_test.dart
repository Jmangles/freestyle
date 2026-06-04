import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/models/user_trick.dart';

void main() {
  group('UserTrick.fromJson', () {
    Map<String, dynamic> base() => {
          'id': 1,
          'user_id': 10,
          'trick_id': 5,
          'consistency': 2,
        };

    test('parses updated_at when present', () {
      final ut = UserTrick.fromJson({...base(), 'updated_at': '2024-06-01T12:00:00.000Z'});
      expect(ut.updatedAt, DateTime.utc(2024, 6, 1, 12, 0, 0));
    });

    test('falls back to epoch when updated_at is null', () {
      final ut = UserTrick.fromJson({...base(), 'updated_at': null});
      expect(ut.updatedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('falls back to epoch when updated_at key is absent', () {
      final ut = UserTrick.fromJson(base());
      expect(ut.updatedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('parses optional fields as null when absent', () {
      final ut = UserTrick.fromJson({...base(), 'updated_at': '2024-01-01T00:00:00.000Z'});
      expect(ut.difficultyVote, isNull);
      expect(ut.leashPosition, isNull);
      expect(ut.videoLink, isNull);
    });
  });
}

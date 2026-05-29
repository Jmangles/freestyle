import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freestyle_highline/services/user_tricks_service.dart';

// Helpers ─────────────────────────────────────────────────────────────────────

int _seq = 0;

Map<String, dynamic> _write({
  required int trickId,
  Map<String, dynamic>? payload,
  String? createdAt,
}) {
  _seq++;
  return {
    'id': _seq,
    'table_name': 'user_tricks',
    'operation': 'upsert',
    'payload': jsonEncode(
        payload ?? {'user_id': 1, 'trick_id': trickId, 'consistency': 2}),
    'local_snapshot_at': '1970-01-01T00:00:00.000Z',
    'created_at': createdAt ?? '2024-01-01T00:00:0${_seq % 10}.000Z',
    'retry_count': 0,
  };
}

Map<String, dynamic> _payload(Map<String, dynamic> write) =>
    jsonDecode(write['payload'] as String) as Map<String, dynamic>;

void main() {
  setUp(() => _seq = 0);

  group('collapsePendingWrites', () {
    test('empty list returns empty list', () {
      expect(UserTricksService.collapsePendingWrites([]), isEmpty);
    });

    test('single write is kept unchanged', () {
      final writes = [_write(trickId: 1)];
      final result = UserTricksService.collapsePendingWrites(writes);
      expect(result, hasLength(1));
      expect(result.first['id'], writes.first['id']);
    });

    test('two upserts for same trick keeps only the last', () {
      final first = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1});
      final second = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 3});
      final result = UserTricksService.collapsePendingWrites([first, second]);
      expect(result, hasLength(1));
      expect(_payload(result.first)['consistency'], 3);
    });

    test('three upserts for same trick keeps only the last', () {
      final writes = [
        _write(trickId: 1, payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1}),
        _write(trickId: 1, payload: {'user_id': 1, 'trick_id': 1, 'consistency': 2}),
        _write(trickId: 1, payload: {'user_id': 1, 'trick_id': 1, 'consistency': 3}),
      ];
      final result = UserTricksService.collapsePendingWrites(writes);
      expect(result, hasLength(1));
      expect(_payload(result.first)['consistency'], 3);
    });

    // Core regression: setConsistency → setLandedDetails → setConsistency
    // must not lose the landed details in the final collapsed write.
    test('consistency → landed → consistency collapses to last write with all fields', () {
      final firstConsistency = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1});
      final landedDetails = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1, 'leash_position': 1});
      final secondConsistency = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 3, 'leash_position': 1});
      final result = UserTricksService.collapsePendingWrites(
          [firstConsistency, landedDetails, secondConsistency]);
      expect(result, hasLength(1));
      final p = _payload(result.first);
      expect(p['consistency'], 3);
      expect(p['leash_position'], 1);
    });

    test('writes for different tricks are all kept', () {
      final writes = [
        _write(trickId: 1),
        _write(trickId: 2),
        _write(trickId: 3),
      ];
      expect(UserTricksService.collapsePendingWrites(writes), hasLength(3));
    });

    test('mixed same and different tricks: one entry per trick, last wins', () {
      final writes = [
        _write(trickId: 1, payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1}),
        _write(trickId: 2),
        _write(trickId: 1, payload: {'user_id': 1, 'trick_id': 1, 'consistency': 4}),
        _write(trickId: 3),
      ];
      final result = UserTricksService.collapsePendingWrites(writes);
      expect(result, hasLength(3));
      final trick1 = result.firstWhere(
          (w) => _payload(w)['trick_id'] == 1);
      expect(_payload(trick1)['consistency'], 4);
    });

    test('writes for same trick but different users are kept separately', () {
      final user1 = _write(trickId: 1,
          payload: {'user_id': 1, 'trick_id': 1, 'consistency': 1});
      final user2 = _write(trickId: 1,
          payload: {'user_id': 2, 'trick_id': 1, 'consistency': 3});
      final result = UserTricksService.collapsePendingWrites([user1, user2]);
      expect(result, hasLength(2));
    });

    test('original order is preserved after collapse', () {
      final writes = [
        _write(trickId: 3),
        _write(trickId: 1),
        _write(trickId: 2),
      ];
      final result = UserTricksService.collapsePendingWrites(writes);
      final ids = result.map((w) => _payload(w)['trick_id']).toList();
      expect(ids, [3, 1, 2]);
    });
  });
}

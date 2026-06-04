import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:freestyle_highline/models/approval_status.dart';
import 'package:freestyle_highline/models/position.dart';
import 'package:freestyle_highline/models/trick.dart';
import 'package:freestyle_highline/models/trick_annotation.dart';
import 'package:freestyle_highline/models/user_trick.dart';
import 'package:freestyle_highline/services/local_database_stub.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    await LocalDatabase.resetForTest();
    await LocalDatabase.init(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await LocalDatabase.resetForTest();
  });

  // ─── 1. Schema and BLOB encoding ──────────────────────────────────────────

  group('1. Schema', () {
    test('1.1 – all six tables are created', () async {
      // If any table is missing, queries below would throw.
      expect(await LocalDatabase.getTricks(), isEmpty);
      expect(await LocalDatabase.getPositions(), isEmpty);
      expect(await LocalDatabase.getUserTricks(1), isEmpty);
      expect(await LocalDatabase.getAnnotations(1, 'en'), isEmpty);
      expect(await LocalDatabase.getPendingWrites(), isEmpty);
      expect(await LocalDatabase.getMeta('any'), isNull);
    });

    test('1.2 – BLOB encode [] → decode returns []', () {
      final blob = LocalDatabase.encodePrerequisiteIds([]);
      expect(LocalDatabase.decodePrerequisiteIds(blob), isEmpty);
    });

    test('1.3 – BLOB encode [1, 42, 1000] → decode returns same list', () {
      const ids = [1, 42, 1000];
      final blob = LocalDatabase.encodePrerequisiteIds(ids);
      expect(LocalDatabase.decodePrerequisiteIds(blob), equals(ids));
    });

    test('1.4 – BLOB encode 300 IDs → decode returns identical list', () {
      final ids = List.generate(300, (i) => i + 1);
      final blob = LocalDatabase.encodePrerequisiteIds(ids);
      expect(LocalDatabase.decodePrerequisiteIds(blob), equals(ids));
    });
  });

  // ─── Tricks round-trip ────────────────────────────────────────────────────

  group('Tricks', () {
    Trick makeTrick({int id = 1, List<int> prereqs = const []}) => Trick(
          id: id,
          givenName: 'Chest Roll',
          difficultyTier: 2,
          dateSubmitted: DateTime(2024, 1, 1),
          prerequisiteTrickIds: prereqs,
          status: ApprovalStatus.approved,
          flags: 0,
        );

    test('cacheTricks then getTricks returns cached tricks', () async {
      final trick = makeTrick();
      await LocalDatabase.cacheTricks([trick]);
      final list = await LocalDatabase.getTricks();
      expect(list.length, 1);
      expect(list.first.id, trick.id);
      expect(list.first.givenName, trick.givenName);
    });

    test('getTrickById returns correct trick', () async {
      await LocalDatabase.cacheTricks([makeTrick(id: 7)]);
      final t = await LocalDatabase.getTrickById(7);
      expect(t?.id, 7);
    });

    test('getTrickById returns null for unknown id', () async {
      expect(await LocalDatabase.getTrickById(99), isNull);
    });

    test('getTricksByIds returns matching tricks', () async {
      await LocalDatabase.cacheTricks([
        makeTrick(id: 1),
        makeTrick(id: 2),
        makeTrick(id: 3),
      ]);
      final list = await LocalDatabase.getTricksByIds([1, 3]);
      expect(list.map((t) => t.id).toSet(), {1, 3});
    });

    test('prerequisite BLOB survives round-trip through DB', () async {
      final trick = makeTrick(id: 5, prereqs: [10, 20, 30]);
      await LocalDatabase.cacheTricks([trick]);
      final fetched = await LocalDatabase.getTrickById(5);
      expect(fetched?.prerequisiteTrickIds, equals([10, 20, 30]));
    });

    test('cacheTricks with conflict replaces existing row', () async {
      final original = makeTrick(id: 1);
      await LocalDatabase.cacheTricks([original]);

      final updated = Trick(
        id: 1,
        givenName: 'Updated Name',
        difficultyTier: 3,
        dateSubmitted: DateTime(2024, 1, 1),
        prerequisiteTrickIds: const [],
        status: ApprovalStatus.approved,
        flags: 0,
      );
      await LocalDatabase.cacheTricks([updated]);

      final list = await LocalDatabase.getTricks();
      expect(list.length, 1);
      expect(list.first.givenName, 'Updated Name');
    });
  });

  // ─── Positions round-trip ─────────────────────────────────────────────────

  group('Positions', () {
    test('cachePositions then getPositions returns cached positions', () async {
      final positions = [
        const Position(id: 1, name: 'Chest'),
        const Position(id: 2, name: 'Hip'),
      ];
      await LocalDatabase.cachePositions(positions);
      final list = await LocalDatabase.getPositions();
      expect(list.length, 2);
      expect(list.map((p) => p.name).toList(), ['Chest', 'Hip']);
    });
  });

  // ─── UserTricks round-trip ────────────────────────────────────────────────

  group('UserTricks', () {
    UserTrick makeUT({
      int id = 1,
      int userId = 10,
      int trickId = 5,
      Consistency consistency = Consistency.sometimes,
    }) =>
        UserTrick(
          id: id,
          userId: userId,
          trickId: trickId,
          consistency: consistency,
          updatedAt: DateTime(2024, 6, 1).toUtc(),
        );

    test('cacheUserTricks then getUserTricks returns rows', () async {
      final ut = makeUT();
      await LocalDatabase.cacheUserTricks([ut]);
      final list = await LocalDatabase.getUserTricks(10);
      expect(list.length, 1);
      expect(list.first.consistency, Consistency.sometimes);
    });

    test('getUserTrickForTrick returns correct row', () async {
      await LocalDatabase.cacheUserTricks([makeUT(userId: 10, trickId: 5)]);
      final result = await LocalDatabase.getUserTrickForTrick(10, 5);
      expect(result?.trickId, 5);
    });

    test('getUserTricksForTrickIds returns map keyed by trickId', () async {
      await LocalDatabase.cacheUserTricks([
        makeUT(id: 1, userId: 10, trickId: 5),
        makeUT(id: 2, userId: 10, trickId: 6),
        makeUT(id: 3, userId: 10, trickId: 7),
      ]);
      final map = await LocalDatabase.getUserTricksForTrickIds(10, [5, 7]);
      expect(map.keys.toSet(), {5, 7});
    });

    test('upsertUserTrick inserts when no row exists', () async {
      await LocalDatabase.upsertUserTrick({
        'user_id': 10,
        'trick_id': 5,
        'consistency': Consistency.often.index,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      final result = await LocalDatabase.getUserTrickForTrick(10, 5);
      expect(result?.consistency, Consistency.often);
    });

    test('upsertUserTrick updates when row exists', () async {
      await LocalDatabase.cacheUserTricks([makeUT(consistency: Consistency.once)]);
      await LocalDatabase.upsertUserTrick({
        'user_id': 10,
        'trick_id': 5,
        'consistency': Consistency.always.index,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      final result = await LocalDatabase.getUserTrickForTrick(10, 5);
      expect(result?.consistency, Consistency.always);
    });

    test('upsertUserTrick with full landed-fields payload round-trips correctly',
        () async {
      await LocalDatabase.upsertUserTrick({
        'user_id': 10,
        'trick_id': 5,
        'consistency': Consistency.often.index,
        'difficulty_vote': 12,
        'leash_position': LeashPosition.backside.index,
        'video_link': 'https://example.com/v.mp4',
        'video_start': 30,
        'video_end': 90,
        'updated_at': '2024-06-01T00:00:00.000Z',
      });
      final result = await LocalDatabase.getUserTrickForTrick(10, 5);
      expect(result?.consistency, Consistency.often);
      expect(result?.difficultyVote, 12);
      expect(result?.leashPosition, LeashPosition.backside);
      expect(result?.videoLink, 'https://example.com/v.mp4');
      expect(result?.videoStart, 30);
      expect(result?.videoEnd, 90);
    });

    test('upsertUserTrick overwrites landed fields on second write', () async {
      await LocalDatabase.upsertUserTrick({
        'user_id': 10,
        'trick_id': 5,
        'consistency': Consistency.sometimes.index,
        'leash_position': LeashPosition.frontside.index,
        'updated_at': '2024-06-01T00:00:00.000Z',
      });
      await LocalDatabase.upsertUserTrick({
        'user_id': 10,
        'trick_id': 5,
        'consistency': Consistency.often.index,
        'leash_position': LeashPosition.backside.index,
        'updated_at': '2024-06-01T00:00:01.000Z',
      });
      final result = await LocalDatabase.getUserTrickForTrick(10, 5);
      expect(result?.consistency, Consistency.often);
      expect(result?.leashPosition, LeashPosition.backside);
    });
  });

  // ─── Annotations round-trip ───────────────────────────────────────────────

  group('Annotations', () {
    TrickAnnotation makeAnnotation({int id = 1}) => TrickAnnotation(
          id: id,
          trickId: 5,
          startMs: 1000,
          endMs: 3000,
          text: 'Keep balance',
          language: 'en',
        );

    test('cacheAnnotations then getAnnotations returns rows', () async {
      await LocalDatabase.cacheAnnotations([makeAnnotation()], 5, 'en');
      final list = await LocalDatabase.getAnnotations(5, 'en');
      expect(list.length, 1);
      expect(list.first.text, 'Keep balance');
    });

    test('getAnnotations for different language returns empty', () async {
      await LocalDatabase.cacheAnnotations([makeAnnotation()], 5, 'en');
      final list = await LocalDatabase.getAnnotations(5, 'es');
      expect(list, isEmpty);
    });

    test('cacheAnnotations replaces previous annotations for same (trick, lang)',
        () async {
      await LocalDatabase.cacheAnnotations([makeAnnotation(id: 1)], 5, 'en');
      await LocalDatabase.cacheAnnotations(
          [makeAnnotation(id: 2), makeAnnotation(id: 3)], 5, 'en');
      final list = await LocalDatabase.getAnnotations(5, 'en');
      expect(list.length, 2);
    });
  });

  // ─── Pending writes queue ─────────────────────────────────────────────────

  group('Pending writes', () {
    Future<void> enqueue({
      int trickId = 1,
      String operation = 'upsert',
      String snapshotAt = '2024-01-01T00:00:00.000Z',
    }) =>
        LocalDatabase.enqueuePendingWrite(
          tableName: 'user_tricks',
          operation: operation,
          payload: {'user_id': 10, 'trick_id': trickId, 'consistency': 2},
          localSnapshotAt: snapshotAt,
        );

    test('enqueuePendingWrite adds a row', () async {
      await enqueue();
      final writes = await LocalDatabase.getPendingWrites();
      expect(writes.length, 1);
      expect(writes.first['operation'], 'upsert');
    });

    test('deletePendingWrite removes the row', () async {
      await enqueue();
      final writes = await LocalDatabase.getPendingWrites();
      await LocalDatabase.deletePendingWrite(writes.first['id'] as int);
      expect(await LocalDatabase.getPendingWrites(), isEmpty);
    });

    test('incrementRetryCount increments the counter', () async {
      await enqueue();
      final id =
          (await LocalDatabase.getPendingWrites()).first['id'] as int;
      await LocalDatabase.incrementRetryCount(id);
      await LocalDatabase.incrementRetryCount(id);
      final updated = await LocalDatabase.getPendingWrites();
      expect(updated.first['retry_count'], 2);
    });

    test('getPendingWrites returns rows in created_at order', () async {
      await enqueue(trickId: 1);
      await enqueue(trickId: 2);
      await enqueue(trickId: 3);
      final writes = await LocalDatabase.getPendingWrites();
      expect(writes.length, 3);
      final payloads = writes
          .map((w) => (w['payload'] as String))
          .map((p) => (p.contains('"trick_id":1')
              ? 1
              : p.contains('"trick_id":2')
                  ? 2
                  : 3))
          .toList();
      expect(payloads, [1, 2, 3]);
    });
  });

  // ─── Meta ─────────────────────────────────────────────────────────────────

  group('Meta', () {
    test('setMeta then getMeta returns value', () async {
      await LocalDatabase.setMeta('tricks_last_synced', '2024-06-01T00:00:00Z');
      expect(
          await LocalDatabase.getMeta('tricks_last_synced'), '2024-06-01T00:00:00Z');
    });

    test('setMeta overwrites existing value', () async {
      await LocalDatabase.setMeta('key', 'v1');
      await LocalDatabase.setMeta('key', 'v2');
      expect(await LocalDatabase.getMeta('key'), 'v2');
    });

    test('getMeta returns null for unknown key', () async {
      expect(await LocalDatabase.getMeta('no_such_key'), isNull);
    });
  });
}

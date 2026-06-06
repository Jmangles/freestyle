import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/approval_status.dart';
import '../models/position.dart';
import '../models/trick.dart';
import '../models/trick_annotation.dart';
import '../models/user_trick.dart';

class LocalDatabase {
  LocalDatabase._();

  static const int _kVersion = 3;
  static Database? _db;

  static Database get _instance {
    assert(_db != null, 'LocalDatabase.init() has not been called');
    return _db!;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  static Future<void> init({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? join(await getDatabasesPath(), 'highline.db');
    _db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) => _createSchema(db);

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // Preserve pending writes before dropping tables — they hold unsynced offline changes.
    List<Map<String, dynamic>> savedWrites = [];
    try {
      savedWrites = await db.query('pending_writes');
    } catch (_) {}

    for (final table in const [
      'tricks',
      'positions',
      'user_tricks',
      'trick_annotations',
      'pending_writes',
      'meta',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createSchema(db);

    for (final row in savedWrites) {
      try {
        // Drop id so AUTOINCREMENT assigns a fresh one.
        await db.insert('pending_writes', Map<String, dynamic>.from(row)..remove('id'));
      } catch (_) {}
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE tricks (
        id INTEGER PRIMARY KEY,
        given_name TEXT NOT NULL,
        technical_name TEXT,
        difficulty_tier INTEGER NOT NULL,
        date_submitted TEXT NOT NULL,
        date_performed TEXT,
        original_performer TEXT,
        prerequisite_trick_ids BLOB NOT NULL,
        base_trick_ids BLOB NOT NULL,
        description TEXT,
        tips TEXT,
        video_link TEXT,
        video_start INTEGER,
        video_end INTEGER,
        start_position_id INTEGER,
        end_position_id INTEGER,
        start_position_name TEXT,
        end_position_name TEXT,
        status INTEGER NOT NULL,
        submitted_by INTEGER,
        flags INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE positions (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE user_tricks (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        trick_id INTEGER NOT NULL,
        consistency INTEGER NOT NULL,
        difficulty_vote INTEGER,
        leash_position INTEGER,
        video_link TEXT,
        video_start INTEGER,
        video_end INTEGER,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id, trick_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE trick_annotations (
        id INTEGER PRIMARY KEY,
        trick_id INTEGER NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        text TEXT NOT NULL,
        language TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_writes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        local_snapshot_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ─── BLOB helpers ─────────────────────────────────────────────────────────

  static Uint8List encodePrerequisiteIds(List<int> ids) {
    final data = ByteData(ids.length * 4);
    for (var i = 0; i < ids.length; i++) {
      data.setInt32(i * 4, ids[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static List<int> decodePrerequisiteIds(Uint8List bytes) {
    final count = bytes.length ~/ 4;
    if (count == 0) return [];
    final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    return List.generate(count, (i) => data.getInt32(i * 4, Endian.little));
  }

  // ─── Row converters ───────────────────────────────────────────────────────

  static Map<String, dynamic> _trickToRow(Trick trick) => {
        'id': trick.id,
        'given_name': trick.givenName,
        'technical_name': trick.technicalName,
        'difficulty_tier': trick.difficultyTier,
        'date_submitted': trick.dateSubmitted.toIso8601String().split('T').first,
        'date_performed': trick.datePerformed?.toIso8601String().split('T').first,
        'original_performer': trick.originalPerformer,
        'prerequisite_trick_ids': encodePrerequisiteIds(trick.prerequisiteTrickIds),
        'base_trick_ids': encodePrerequisiteIds(trick.baseTrickIds),
        'description': trick.description,
        'tips': trick.tips,
        'video_link': trick.videoLink,
        'video_start': trick.videoStart,
        'video_end': trick.videoEnd,
        'start_position_id': trick.startPositionId,
        'end_position_id': trick.endPositionId,
        'start_position_name': trick.startPositionName,
        'end_position_name': trick.endPositionName,
        'status': trick.status.index,
        'submitted_by': trick.submittedBy,
        'flags': trick.flags,
      };

  static Uint8List _readBlob(Map<String, dynamic> row, String key) {
    final raw = row[key];
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    return Uint8List(0);
  }

  static Trick _trickFromRow(Map<String, dynamic> row) {
    return Trick(
      id: row['id'] as int,
      givenName: row['given_name'] as String,
      technicalName: row['technical_name'] as String?,
      difficultyTier: row['difficulty_tier'] as int,
      dateSubmitted: DateTime.parse(row['date_submitted'] as String),
      datePerformed: row['date_performed'] != null
          ? DateTime.parse(row['date_performed'] as String)
          : null,
      originalPerformer: row['original_performer'] as String?,
      prerequisiteTrickIds: decodePrerequisiteIds(_readBlob(row, 'prerequisite_trick_ids')),
      baseTrickIds: decodePrerequisiteIds(_readBlob(row, 'base_trick_ids')),
      description: row['description'] as String?,
      tips: row['tips'] as String?,
      videoLink: row['video_link'] as String?,
      videoStart: row['video_start'] as int?,
      videoEnd: row['video_end'] as int?,
      startPositionId: row['start_position_id'] as int?,
      endPositionId: row['end_position_id'] as int?,
      status: ApprovalStatus.fromIndex(row['status'] as int),
      submittedBy: row['submitted_by'] as int?,
      flags: row['flags'] as int? ?? 0,
      startPositionName: row['start_position_name'] as String?,
      endPositionName: row['end_position_name'] as String?,
    );
  }

  static Map<String, dynamic> _userTrickToRow(UserTrick ut) => {
        'id': ut.id,
        'user_id': ut.userId,
        'trick_id': ut.trickId,
        'consistency': ut.consistency.index,
        'difficulty_vote': ut.difficultyVote,
        'leash_position': ut.leashPosition?.index,
        'video_link': ut.videoLink,
        'video_start': ut.videoStart,
        'video_end': ut.videoEnd,
        'updated_at': ut.updatedAt.toUtc().toIso8601String(),
      };

  // ─── Tricks ───────────────────────────────────────────────────────────────

  static Future<void> cacheTricks(List<Trick> tricks) async {
    final batch = _instance.batch();
    for (final t in tricks) {
      batch.insert('tricks', _trickToRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Trick>> getTricks() async {
    final rows = await _instance.query('tricks',
        where: 'status = ?',
        whereArgs: [ApprovalStatus.approved.index],
        orderBy: 'given_name');
    return rows.map(_trickFromRow).toList();
  }

  static Future<Trick?> getTrickById(int id) async {
    final rows = await _instance.query('tricks',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _trickFromRow(rows.first);
  }

  static Future<List<Trick>> getTricksByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _instance
        .query('tricks', where: 'id IN ($placeholders)', whereArgs: ids);
    return rows.map(_trickFromRow).toList();
  }

  // ─── Positions ────────────────────────────────────────────────────────────

  static Future<void> cachePositions(List<Position> positions) async {
    final batch = _instance.batch();
    for (final p in positions) {
      batch.insert('positions', {'id': p.id, 'name': p.name},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Position>> getPositions() async {
    final rows =
        await _instance.query('positions', orderBy: 'name');
    return rows.map((r) => Position.fromJson(r)).toList();
  }

  // ─── UserTricks ───────────────────────────────────────────────────────────

  static Future<void> cacheUserTricks(List<UserTrick> list) async {
    final batch = _instance.batch();
    for (final ut in list) {
      batch.insert('user_tricks', _userTrickToRow(ut),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<UserTrick>> getUserTricks(int userId) async {
    final rows = await _instance.query('user_tricks',
        where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => UserTrick.fromJson(r)).toList();
  }

  static Future<Map<int, UserTrick>> getUserTricksForTrickIds(
      int userId, List<int> trickIds) async {
    if (trickIds.isEmpty) return {};
    final placeholders = List.filled(trickIds.length, '?').join(',');
    final rows = await _instance.query(
      'user_tricks',
      where: 'user_id = ? AND trick_id IN ($placeholders)',
      whereArgs: [userId, ...trickIds],
    );
    final list = rows.map((r) => UserTrick.fromJson(r)).toList();
    return {for (final ut in list) ut.trickId: ut};
  }

  static Future<UserTrick?> getUserTrickForTrick(
      int userId, int trickId) async {
    final rows = await _instance.query(
      'user_tricks',
      where: 'user_id = ? AND trick_id = ?',
      whereArgs: [userId, trickId],
      limit: 1,
    );
    return rows.isEmpty ? null : UserTrick.fromJson(rows.first);
  }

  /// Upsert a user_trick row locally (offline write). The map must include
  /// user_id, trick_id, consistency, and updated_at.
  static Future<void> upsertUserTrick(Map<String, dynamic> data) async {
    final userId = data['user_id'] as int;
    final trickId = data['trick_id'] as int;
    final updated = await _instance.update(
      'user_tricks',
      data,
      where: 'user_id = ? AND trick_id = ?',
      whereArgs: [userId, trickId],
    );
    if (updated == 0) {
      await _instance.insert('user_tricks', data);
    }
  }

  /// Atomically upserts a user_trick row and enqueues the corresponding
  /// pending write so the two are never out of sync if the app crashes
  /// between them.
  static Future<void> upsertUserTrickAndEnqueueWrite({
    required Map<String, dynamic> trickData,
    required String tableName,
    required String operation,
    required Map<String, dynamic> payload,
    required String localSnapshotAt,
  }) async {
    await _instance.transaction((txn) async {
      final userId = trickData['user_id'] as int;
      final trickId = trickData['trick_id'] as int;
      final updated = await txn.update(
        'user_tricks',
        trickData,
        where: 'user_id = ? AND trick_id = ?',
        whereArgs: [userId, trickId],
      );
      if (updated == 0) {
        await txn.insert('user_tricks', trickData);
      }
      await txn.insert('pending_writes', {
        'table_name': tableName,
        'operation': operation,
        'payload': jsonEncode(payload),
        'local_snapshot_at': localSnapshotAt,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'retry_count': 0,
      });
    });
  }

  // ─── Annotations ──────────────────────────────────────────────────────────

  static Future<void> cacheAnnotations(
      List<TrickAnnotation> annotations, int trickId, String language) async {
    await _instance.transaction((txn) async {
      await txn.delete(
        'trick_annotations',
        where: 'trick_id = ? AND language = ?',
        whereArgs: [trickId, language],
      );
      final batch = txn.batch();
      for (final a in annotations) {
        batch.insert('trick_annotations', {
          'id': a.id,
          'trick_id': a.trickId,
          'start_ms': a.startMs,
          'end_ms': a.endMs,
          'text': a.text,
          'language': a.language,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<TrickAnnotation>> getAnnotations(
      int trickId, String language) async {
    final rows = await _instance.query(
      'trick_annotations',
      where: 'trick_id = ? AND language = ?',
      whereArgs: [trickId, language],
      orderBy: 'start_ms',
    );
    return rows.map((r) => TrickAnnotation.fromJson(r)).toList();
  }

  // ─── Pending writes ───────────────────────────────────────────────────────

  static Future<void> enqueuePendingWrite({
    required String tableName,
    required String operation,
    required Map<String, dynamic> payload,
    required String localSnapshotAt,
  }) async {
    await _instance.insert('pending_writes', {
      'table_name': tableName,
      'operation': operation,
      'payload': jsonEncode(payload),
      'local_snapshot_at': localSnapshotAt,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingWrites() async {
    return _instance.query('pending_writes', orderBy: 'created_at ASC');
  }

  static Future<void> deletePendingWrite(int id) async {
    await _instance.delete('pending_writes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> incrementRetryCount(int id) async {
    await _instance.rawUpdate(
        'UPDATE pending_writes SET retry_count = retry_count + 1 WHERE id = ?',
        [id]);
  }

  // ─── Meta ─────────────────────────────────────────────────────────────────

  static Future<void> setMeta(String key, String value) async {
    await _instance.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getMeta(String key) async {
    final rows = await _instance.query('meta',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
  }
}

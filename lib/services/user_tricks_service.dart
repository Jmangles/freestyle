import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trick_vote_stats.dart';
import '../models/user_trick.dart';
import '../utils/network_utils.dart';
import 'auth_service.dart';
import 'local_database.dart';

class UserTricksService {
  static final _client = Supabase.instance.client;

  // Sentinel used as local_snapshot_at when no prior server row exists for this
  // user+trick, so any real server timestamp will sort as "newer". Consequence:
  // if another device creates the same row while this device is offline, the
  // server row wins on flush — intentional "last writer wins" behaviour.
  static const _noSnapshotAt = '1970-01-01T00:00:00.000Z';

  // Resolves the user's integer profile ID, with an offline fallback stored in
  // the meta table so cold launches without connectivity still work.
  static Future<int?> _getUserIntId() async {
    if (!AuthService.isLoggedIn) return null;
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile != null) {
        if (!kIsWeb) {
          unawaited(
              LocalDatabase.setMeta('cached_user_int_id', '${profile.intId}'));
        }
        return profile.intId;
      }
      return null;
    } catch (e) {
      if (kIsWeb) rethrow;
      final stored = await LocalDatabase.getMeta('cached_user_int_id');
      return stored != null ? int.tryParse(stored) : null;
    }
  }

  // ─── Reads ────────────────────────────────────────────────────────────────

  static Future<List<UserTrick>> getUserTricks() async {
    final intId = await _getUserIntId();
    if (intId == null) {
      // Stamp the timestamp so the freshness check doesn't retry on every
      // cold launch when no user is logged in — there is nothing to sync.
      if (!kIsWeb) {
        unawaited(LocalDatabase.setMeta(
            'user_tricks_last_synced', DateTime.now().toUtc().toIso8601String()));
      }
      return [];
    }
    if (isDeviceOffline) return LocalDatabase.getUserTricks(intId);
    try {
      final data =
          await _client.from('user_tricks').select().eq('user_id', intId);
      final list = (data as List).map((e) => UserTrick.fromJson(e)).toList();
      await LocalDatabase.cacheUserTricks(list);
      await LocalDatabase.setMeta(
          'user_tricks_last_synced', DateTime.now().toUtc().toIso8601String());
      return list;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTricks: $e\n$st');
        rethrow;
      }
      return LocalDatabase.getUserTricks(intId);
    }
  }

  static Future<Map<int, UserTrick>> getUserTricksForTrickIds(
      List<int> trickIds) async {
    if (trickIds.isEmpty) return {};
    final intId = await _getUserIntId();
    if (intId == null) return {};
    if (isDeviceOffline) return LocalDatabase.getUserTricksForTrickIds(intId, trickIds);
    try {
      final data = await _client
          .from('user_tricks')
          .select()
          .eq('user_id', intId)
          .inFilter('trick_id', trickIds);
      final list = (data as List).map((e) => UserTrick.fromJson(e)).toList();
      await LocalDatabase.cacheUserTricks(list);
      return {for (final t in list) t.trickId: t};
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTricksForTrickIds: $e\n$st');
        rethrow;
      }
      return LocalDatabase.getUserTricksForTrickIds(intId, trickIds);
    }
  }

  static Future<UserTrick?> getUserTrickForTrick(int trickId) async {
    final intId = await _getUserIntId();
    if (intId == null) return null;
    if (isDeviceOffline) return LocalDatabase.getUserTrickForTrick(intId, trickId);
    try {
      final data = await _client
          .from('user_tricks')
          .select()
          .eq('user_id', intId)
          .eq('trick_id', trickId)
          .maybeSingle();
      if (data != null) {
        final ut = UserTrick.fromJson(data);
        await LocalDatabase.cacheUserTricks([ut]);
        return ut;
      }
      return null;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTrickForTrick($trickId): $e\n$st');
        rethrow;
      }
      return LocalDatabase.getUserTrickForTrick(intId, trickId);
    }
  }

  // ─── Writes ───────────────────────────────────────────────────────────────

  static Future<void> setConsistency(
      int trickId, Consistency consistency) async {
    final intId = await _getUserIntId();
    if (intId == null) return;

    if (!isDeviceOffline) {
      try {
        await _client.from('user_tricks').upsert(
          {
            'user_id': intId,
            'trick_id': trickId,
            'consistency': consistency.index,
          },
          onConflict: 'user_id,trick_id',
        );
        if (!kIsWeb) unawaited(_recacheUserTrick(intId, trickId));
        return;
      } catch (e, st) {
        if (kIsWeb || !isNetworkError(e)) {
          debugPrint('UserTricksService.setConsistency($trickId): $e\n$st');
          rethrow;
        }
      }
    }

    // Offline path
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await LocalDatabase.getUserTrickForTrick(intId, trickId);
    final snapshotAt =
        existing?.updatedAt.toUtc().toIso8601String() ?? _noSnapshotAt;

    await LocalDatabase.upsertUserTrickAndEnqueueWrite(
      trickData: {
        'user_id': intId,
        'trick_id': trickId,
        'consistency': consistency.index,
        'updated_at': now,
        if (existing != null) ...{
          'difficulty_vote': existing.difficultyVote,
          'leash_position': existing.leashPosition?.index,
          'video_link': existing.videoLink,
          'video_start': existing.videoStart,
          'video_end': existing.videoEnd,
        },
      },
      tableName: 'user_tricks',
      operation: 'upsert',
      payload: {
        'user_id': intId,
        'trick_id': trickId,
        'consistency': consistency.index,
        if (existing != null) ...{
          'difficulty_vote': existing.difficultyVote,
          'leash_position': existing.leashPosition?.index,
          'video_link': existing.videoLink,
          'video_start': existing.videoStart,
          'video_end': existing.videoEnd,
        },
      },
      localSnapshotAt: snapshotAt,
    );
  }

  static Future<void> setLandedDetails(
    int trickId, {
    int? difficultyVote,
    LeashPosition? leashPosition,
    String? videoLink,
    int? videoStart,
    int? videoEnd,
  }) async {
    final intId = await _getUserIntId();
    if (intId == null) return;

    final landedFields = {
      'difficulty_vote': difficultyVote,
      'leash_position': leashPosition?.index,
      'video_link': videoLink,
      'video_start': videoStart,
      'video_end': videoEnd,
    };

    if (!isDeviceOffline) {
      try {
        // Use upsert so the write succeeds even when no user_tricks row exists yet,
        // matching the offline path. Read consistency from the local cache (native)
        // or from the server (web) to avoid overwriting an existing value on conflict.
        Consistency? existingConsistency;
        if (!kIsWeb) {
          existingConsistency =
              (await LocalDatabase.getUserTrickForTrick(intId, trickId))?.consistency;
        } else {
          final row = await _client
              .from('user_tricks')
              .select('consistency')
              .eq('user_id', intId)
              .eq('trick_id', trickId)
              .maybeSingle();
          if (row != null) {
            existingConsistency = Consistency.values[row['consistency'] as int];
          }
        }
        await _client.from('user_tricks').upsert(
          {
            'user_id': intId,
            'trick_id': trickId,
            'consistency': (existingConsistency ?? Consistency.never).index,
            ...landedFields,
          },
          onConflict: 'user_id,trick_id',
        );
        if (!kIsWeb) unawaited(_recacheUserTrick(intId, trickId));
        return;
      } catch (e, st) {
        if (kIsWeb || !isNetworkError(e)) {
          debugPrint('UserTricksService.setLandedDetails($trickId): $e\n$st');
          rethrow;
        }
      }
    }

    // Offline path
    final existing = await LocalDatabase.getUserTrickForTrick(intId, trickId);
    final now = DateTime.now().toUtc().toIso8601String();
    // Use the existing consistency if available; fall back to never so the
    // write is not silently dropped when the user sets landed details on a
    // trick they rated offline moments earlier and the UI has not yet reloaded.
    final consistency = existing?.consistency ?? Consistency.never;
    final snapshotAt =
        existing?.updatedAt.toUtc().toIso8601String() ?? _noSnapshotAt;

    await LocalDatabase.upsertUserTrickAndEnqueueWrite(
      trickData: {
        'user_id': intId,
        'trick_id': trickId,
        'consistency': consistency.index,
        'updated_at': now,
        ...landedFields,
      },
      tableName: 'user_tricks',
      operation: 'upsert',
      payload: {
        'user_id': intId,
        'trick_id': trickId,
        'consistency': consistency.index,
        ...landedFields,
      },
      localSnapshotAt: snapshotAt,
    );
  }

  static Future<TrickVoteStats> getTrickVoteStats(int trickId) async {
    if (isDeviceOffline) return TrickVoteStats.empty();
    try {
      final data = await _client
          .rpc('get_trick_vote_stats', params: {'p_trick_id': trickId});
      return TrickVoteStats.fromRpc(data as Map<String, dynamic>);
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getTrickVoteStats($trickId): $e\n$st');
        rethrow;
      }
      return TrickVoteStats.empty();
    }
  }

  // ─── Flush pending writes ─────────────────────────────────────────────────

  // Guards against concurrent flush runs. flushPendingWrites is triggered from
  // three independent sites (cold launch, app resume, connectivity restored),
  // so back-to-back signals must not produce overlapping flush loops.
  static bool _flushing = false;

  static Future<void> flushPendingWrites() async {
    if (kIsWeb || _flushing || isDeviceOffline) return;
    _flushing = true;
    try {
      final writes = await LocalDatabase.getPendingWrites();
      if (writes.isEmpty) return;

      final collapsedWrites = collapsePendingWrites(writes);
      final keepIds = collapsedWrites.map((w) => w['id'] as int).toSet();
      for (final write in writes) {
        if (!keepIds.contains(write['id'] as int)) {
          await LocalDatabase.deletePendingWrite(write['id'] as int);
        }
      }

      // Tracks the latest server-side updated_at per (userId:trickId) so that
      // subsequent writes for the same row use the post-trigger timestamp and
      // don't false-trigger the conflict check.
      final Map<String, DateTime> latestServerTs = {};

      for (final write in collapsedWrites) {
        final id = write['id'] as int;
        final retryCount = write['retry_count'] as int;
        try {
          final payload =
              jsonDecode(write['payload'] as String) as Map<String, dynamic>;
          final userId = payload['user_id'] as int;
          final trickId = payload['trick_id'] as int;
          final tsKey = '$userId:$trickId';
          var snapshotAt = DateTime.parse(write['local_snapshot_at'] as String);
          final knownTs = latestServerTs[tsKey];
          if (knownTs != null && knownTs.isAfter(snapshotAt)) {
            snapshotAt = knownTs;
          }
          final serverTs = await _flushUserTrickWrite(
            pendingId: id,
            operation: write['operation'] as String,
            payload: payload,
            localSnapshotAt: snapshotAt,
          );
          if (serverTs != null) {
            latestServerTs[tsKey] = serverTs;
          }
        } catch (e, st) {
          debugPrint('flushPendingWrites: error on write $id: $e\n$st');
          // Network errors mean the device went offline mid-flush — abort without
          // touching retry counts so the writes survive until reconnect.
          if (isNetworkError(e)) return;
          if (retryCount + 1 >= 5) {
            debugPrint('flushPendingWrites: dropping write $id after 5 failures');
            await LocalDatabase.deletePendingWrite(id);
          } else {
            await LocalDatabase.incrementRetryCount(id);
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }

  // Collapses all writes for the same (table, trick_id) to the latest one.
  // Every pending write carries the full row state, so only the final snapshot
  // matters — earlier entries for the same trick are redundant.
  @visibleForTesting
  static List<Map<String, dynamic>> collapsePendingWrites(
      List<Map<String, dynamic>> writes) {
    final Map<String, int> latestIndex = {};
    for (var i = 0; i < writes.length; i++) {
      final payload =
          jsonDecode(writes[i]['payload'] as String) as Map<String, dynamic>;
      final key = '${writes[i]['table_name']}:${payload['user_id']}:${payload['trick_id']}';
      latestIndex[key] = i;
    }
    final keepSet = latestIndex.values.toSet();
    return [
      for (var i = 0; i < writes.length; i++)
        if (keepSet.contains(i)) writes[i],
    ];
  }

  static Future<DateTime?> _flushUserTrickWrite({
    required int pendingId,
    required String operation,
    required Map<String, dynamic> payload,
    required DateTime localSnapshotAt,
  }) async {
    final userId = payload['user_id'] as int;
    final trickId = payload['trick_id'] as int;

    // Check for a conflict: another device may have written after our last sync.
    final serverRow = await _client
        .from('user_tricks')
        .select('updated_at')
        .eq('user_id', userId)
        .eq('trick_id', trickId)
        .maybeSingle();

    if (serverRow != null) {
      final serverUpdatedAt =
          DateTime.parse(serverRow['updated_at'] as String);
      if (serverUpdatedAt.isAfter(localSnapshotAt)) {
        // Server is newer — discard our write and pull the server row.
        debugPrint(
            'flushPendingWrites: conflict for trick $trickId, server wins');
        final fresh = await _client
            .from('user_tricks')
            .select()
            .eq('user_id', userId)
            .eq('trick_id', trickId)
            .maybeSingle();
        if (fresh != null) {
          await LocalDatabase.cacheUserTricks([UserTrick.fromJson(fresh)]);
        }
        await LocalDatabase.deletePendingWrite(pendingId);
        return null;
      }
    }

    if (operation == 'upsert') {
      await _client.from('user_tricks').upsert(
            payload,
            onConflict: 'user_id,trick_id',
          );
    } else {
      debugPrint(
          'flushPendingWrites: unknown operation "$operation" for write $pendingId — dropping');
      await LocalDatabase.deletePendingWrite(pendingId);
      return null;
    }

    // Re-cache with the server's final state (includes trigger-set updated_at).
    final recached = await _recacheUserTrick(userId, trickId);
    await LocalDatabase.deletePendingWrite(pendingId);
    return recached?.updatedAt;
  }

  static Future<UserTrick?> _recacheUserTrick(int userId, int trickId) async {
    try {
      final data = await _client
          .from('user_tricks')
          .select()
          .eq('user_id', userId)
          .eq('trick_id', trickId)
          .maybeSingle();
      if (data != null) {
        final ut = UserTrick.fromJson(data);
        await LocalDatabase.cacheUserTricks([ut]);
        return ut;
      }
    } catch (e, st) {
      if (!isNetworkError(e)) {
        debugPrint('_recacheUserTrick($userId, $trickId): $e\n$st');
      }
    }
    return null;
  }
}

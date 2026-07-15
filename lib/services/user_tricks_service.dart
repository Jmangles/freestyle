import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trick_vote_stats.dart';
import '../models/user_trick.dart';
import '../utils/network_utils.dart';
import '../utils/offline_fallback.dart';
import 'auth_service.dart';
import 'local_database.dart';

class UserTricksService {
  static final _client = Supabase.instance.client;

  // Sentinel used as local_snapshot_at when no prior server row exists for this
  // user+trick, so any real server timestamp will sort as "newer". Consequence:
  // if another device creates the same row while this device is offline, the
  // server row wins on flush — intentional "last writer wins" behaviour.
  static const _noSnapshotAt = '1970-01-01T00:00:00.000Z';

  // Optimistic consistency values, keyed by trick ID. Set synchronously when a
  // write starts so every screen can reflect it immediately; removed once a
  // read confirms the stored value matches, or when the write fails hard.
  static final ValueNotifier<Map<int, Consistency>> consistencyOverrides =
      ValueNotifier(const {});

  static void _addConsistencyOverride(int trickId, Consistency c) {
    consistencyOverrides.value = {...consistencyOverrides.value, trickId: c};
  }

  static void _removeConsistencyOverride(int trickId, Consistency c) {
    if (consistencyOverrides.value[trickId] != c) return;
    consistencyOverrides.value = {...consistencyOverrides.value}
      ..remove(trickId);
  }

  static UserTrick _withConsistencyOverride(UserTrick ut) {
    final override = consistencyOverrides.value[ut.trickId];
    if (override == null) return ut;
    if (ut.consistency == override) {
      _removeConsistencyOverride(ut.trickId, override);
      return ut;
    }
    return ut.withConsistency(override);
  }

  static List<UserTrick> _withConsistencyOverrides(List<UserTrick> list) =>
      [for (final ut in list) _withConsistencyOverride(ut)];

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
    if (isDeviceOffline) {
      return _withConsistencyOverrides(await LocalDatabase.getUserTricks(intId));
    }
    try {
      final data =
          await _client.from('user_tricks').select().eq('user_id', intId);
      final list = (data as List).map((e) => UserTrick.fromJson(e)).toList();
      await LocalDatabase.cacheUserTricks(list);
      await LocalDatabase.setMeta(
          'user_tricks_last_synced', DateTime.now().toUtc().toIso8601String());
      return _withConsistencyOverrides(list);
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTricks: $e\n$st');
        rethrow;
      }
      return _withConsistencyOverrides(await LocalDatabase.getUserTricks(intId));
    }
  }

  static Future<Map<int, UserTrick>> getUserTricksForTrickIds(
      List<int> trickIds) async {
    if (trickIds.isEmpty) return {};
    final intId = await _getUserIntId();
    if (intId == null) return {};
    if (isDeviceOffline) {
      final map = await LocalDatabase.getUserTricksForTrickIds(intId, trickIds);
      return map.map((k, v) => MapEntry(k, _withConsistencyOverride(v)));
    }
    try {
      final data = await _client
          .from('user_tricks')
          .select()
          .eq('user_id', intId)
          .inFilter('trick_id', trickIds);
      final list = (data as List).map((e) => UserTrick.fromJson(e)).toList();
      await LocalDatabase.cacheUserTricks(list);
      return {
        for (final t in _withConsistencyOverrides(list)) t.trickId: t
      };
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTricksForTrickIds: $e\n$st');
        rethrow;
      }
      final map = await LocalDatabase.getUserTricksForTrickIds(intId, trickIds);
      return map.map((k, v) => MapEntry(k, _withConsistencyOverride(v)));
    }
  }

  static Future<UserTrick?> getUserTrickForTrick(int trickId) async {
    final intId = await _getUserIntId();
    if (intId == null) return null;
    if (isDeviceOffline) {
      final ut = await LocalDatabase.getUserTrickForTrick(intId, trickId);
      return ut != null ? _withConsistencyOverride(ut) : null;
    }
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
        return _withConsistencyOverride(ut);
      }
      return null;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('UserTricksService.getUserTrickForTrick($trickId): $e\n$st');
        rethrow;
      }
      final ut = await LocalDatabase.getUserTrickForTrick(intId, trickId);
      return ut != null ? _withConsistencyOverride(ut) : null;
    }
  }

  // ─── Writes ───────────────────────────────────────────────────────────────

  static Future<void> setConsistency(
      int trickId, Consistency consistency) async {
    _addConsistencyOverride(trickId, consistency);
    try {
      await _writeConsistency(trickId, consistency);
    } catch (e) {
      _removeConsistencyOverride(trickId, consistency);
      rethrow;
    }
  }

  static Future<void> _writeConsistency(
      int trickId, Consistency consistency) async {
    final intId = await _getUserIntId();
    if (intId == null) {
      _removeConsistencyOverride(trickId, consistency);
      return;
    }

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
        Consistency existingConsistency;
        if (!kIsWeb) {
          existingConsistency =
              (await LocalDatabase.getUserTrickForTrick(intId, trickId))
                  .effectiveConsistency;
        } else {
          final row = await _client
              .from('user_tricks')
              .select('consistency')
              .eq('user_id', intId)
              .eq('trick_id', trickId)
              .maybeSingle();
          existingConsistency = row != null
              ? Consistency.values
                      .elementAtOrNull(row['consistency'] as int) ??
                  Consistency.neverTried
              : Consistency.neverTried;
        }
        await _client.from('user_tricks').upsert(
          {
            'user_id': intId,
            'trick_id': trickId,
            'consistency': existingConsistency.index,
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
    // Keep the existing consistency; a missing row defaults to neverTried so
    // the landed details are still written rather than silently dropped.
    final consistency = existing.effectiveConsistency;
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

  static Future<TrickVoteStats> getTrickVoteStats(int trickId) {
    return withOfflineFallback(
      caller: 'UserTricksService.getTrickVoteStats($trickId)',
      online: () async {
        final data = await _client
            .rpc('get_trick_vote_stats', params: {'p_trick_id': trickId});
        return TrickVoteStats.fromRpc(data as Map<String, dynamic>);
      },
      offline: () async => TrickVoteStats.empty(),
    );
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
        // Our write lost — drop its override so the UI shows the server row.
        final lost = payload['consistency'] is int
            ? Consistency.values.elementAtOrNull(payload['consistency'] as int)
            : null;
        if (lost != null) _removeConsistencyOverride(trickId, lost);
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

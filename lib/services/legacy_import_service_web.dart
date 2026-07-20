import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../models/legacy_import.dart';
import '../models/user_trick.dart';
import 'auth_service.dart';

// Recovers progress from the old highline-freestyle.com app (React + Dexie),
// which stored everything in this origin's IndexedDB. See
// docs/legacy-migration/README.md for the id mapping and its caveats.
class LegacyImportService {
  LegacyImportService._();

  static const _legacyDbName = 'db';
  static const _legacyHost = 'highline-freestyle.com';
  static const _legacyStore = 'userTricks';
  static const _mapAsset = 'assets/legacy/trick_id_map.json';
  static const _donePref = 'legacy_import_done';
  static const _promptSeenPref = 'legacy_import_prompt_seen';

  // Ids below this are tricks the user created themselves; only the predefined
  // catalog (10000+) can be mapped onto this app's tricks.
  static const _firstPredefinedId = 10000;

  static Map<int, int>? _trickIdMap;

  static Future<bool> isDone() async =>
      (await SharedPreferences.getInstance()).getBool(_donePref) ?? false;

  static Future<bool> promptSeen() async =>
      (await SharedPreferences.getInstance()).getBool(_promptSeenPref) ?? false;

  static Future<void> markPromptSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_promptSeenPref, true);

  static Future<LegacyScan?> scan() async {
    if (!web.window.location.hostname.endsWith(_legacyHost)) return null;
    if (await isDone()) return null;

    final legacy = await _readLegacyUserTricks();
    if (legacy == null) return null;
    final (rows, schemaVersion) = legacy;

    final map = await _loadTrickIdMap();
    final consistencies = <int, Consistency>{};
    var untransferable = 0;
    var customTricks = 0;

    for (final row in rows) {
      if (row['deleted'] == true) continue;

      final legacyId = (row['id'] as num?)?.toInt();
      if (legacyId == null) continue;
      if (legacyId < _firstPredefinedId) {
        customTricks++;
        continue;
      }

      var stickFrequency = (row['stickFrequency'] as num?)?.toInt() ?? 0;
      // Dexie v5 shifted the two top values up by one when a level was
      // inserted. A browser that never reopened the old app after that release
      // still holds pre-shift values, and we read the store directly instead
      // of letting Dexie run its upgrades.
      if (schemaVersion < 5 && (stickFrequency == 5 || stickFrequency == 6)) {
        stickFrequency++;
      }
      if (stickFrequency <= 0) continue;

      final newId = map[legacyId];
      if (newId == null) {
        untransferable++;
        continue;
      }
      consistencies[newId] = consistencyFromStickFrequency(stickFrequency);
    }

    final scan = LegacyScan(
      consistencyByTrickId: consistencies,
      untransferable: untransferable,
      customTricks: customTricks,
    );
    return scan.hasAnything ? scan : null;
  }

  static Future<LegacyImportResult> import(LegacyScan scan) async {
    final profile = await AuthService.getCurrentProfile();
    if (profile == null) {
      throw StateError('Legacy import requires a signed-in profile');
    }
    final client = Supabase.instance.client;

    final existingRows = await client
        .from('user_tricks')
        .select('trick_id, consistency')
        .eq('user_id', profile.intId);
    final existing = {
      for (final row in existingRows)
        (row['trick_id'] as num).toInt(): (row['consistency'] as num).toInt(),
    };

    // Never downgrade what the user already tracked in this app.
    final payload = <Map<String, dynamic>>[];
    var skipped = 0;
    scan.consistencyByTrickId.forEach((trickId, consistency) {
      if ((existing[trickId] ?? -1) >= consistency.index) {
        skipped++;
        return;
      }
      payload.add({
        'user_id': profile.intId,
        'trick_id': trickId,
        'consistency': consistency.index,
      });
    });

    for (var i = 0; i < payload.length; i += 200) {
      final end = (i + 200) < payload.length ? i + 200 : payload.length;
      await client
          .from('user_tricks')
          .upsert(payload.sublist(i, end), onConflict: 'user_id,trick_id');
    }

    // The legacy database is left in place: a bad import stays recoverable,
    // and the flag alone stops the prompt from coming back.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_donePref, true);

    return LegacyImportResult(
      written: payload.length,
      skippedNotHigher: skipped,
      untransferable: scan.untransferable,
    );
  }

  static Future<Map<int, int>> _loadTrickIdMap() async {
    if (_trickIdMap != null) return _trickIdMap!;
    final raw = jsonDecode(await rootBundle.loadString(_mapAsset)) as Map;
    return _trickIdMap = {
      for (final entry in raw.entries)
        int.parse(entry.key as String): (entry.value as num).toInt(),
    };
  }

  // Returns the rows of the legacy `userTricks` store plus the schema version
  // the database is actually at, or null when this browser has no legacy data.
  static Future<(List<Map>, int)?> _readLegacyUserTricks() async {
    web.IDBDatabase? db;
    try {
      // Opening without a version never triggers a Dexie upgrade, but it does
      // create an empty database when none exists — cleaned up below so a
      // visitor who never used the old app is left as they were.
      db = await _await<web.IDBDatabase>(
          web.window.indexedDB.open(_legacyDbName));
      if (!db.objectStoreNames.contains(_legacyStore)) {
        db.close();
        db = null;
        web.window.indexedDB.deleteDatabase(_legacyDbName);
        return null;
      }

      final rows = await _await<JSArray>(db
          .transaction(_legacyStore.toJS, 'readonly')
          .objectStore(_legacyStore)
          .getAll(null));
      return ([
        for (final row in rows.dartify() as List)
          if (row is Map) row
      ], db.version);
    } catch (e, st) {
      debugPrint('LegacyImportService.scan: $e\n$st');
      return null;
    } finally {
      db?.close();
    }
  }

  static Future<T> _await<T extends JSAny?>(web.IDBRequest request) {
    final completer = Completer<T>();
    request.onsuccess = (web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result as T);
    }.toJS;
    request.onerror = (web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('IndexedDB request failed: ${request.error?.message}'));
      }
    }.toJS;
    return completer.future;
  }
}

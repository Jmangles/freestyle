import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/approval_status.dart';
import '../models/position.dart';
import '../models/trick.dart';
import '../models/trick_suggestion.dart';
import '../utils/network_utils.dart';
import '../utils/offline_fallback.dart';
import 'auth_service.dart';
import 'local_database.dart';

class TricksService {
  static final _client = Supabase.instance.client;

  static const _select =
      '*, '
      'start_position:positions!start_position_id(name), '
      'end_position:positions!end_position_id(name)';

  static Future<List<Trick>> getApprovedTricks() {
    return withOfflineFallback(
      caller: 'TricksService.getApprovedTricks',
      online: () async {
        final data = await _client
            .from('tricks')
            .select(_select)
            .eq('status', ApprovalStatus.approved.index)
            .order('given_name');
        final tricks = (data as List).map((e) => Trick.fromJson(e)).toList();
        await LocalDatabase.cacheTricks(tricks);
        await LocalDatabase.setMeta(
            'tricks_last_synced', DateTime.now().toUtc().toIso8601String());
        return tricks;
      },
      offline: () => LocalDatabase.getTricks(),
    );
  }

  static Future<Trick> getTrickById(int id) async {
    if (isDeviceOffline) {
      final cached = await LocalDatabase.getTrickById(id);
      if (cached != null) return cached;
      throw Exception('Trick $id not in local cache and device is offline');
    }
    try {
      final data =
          await _client.from('tricks').select(_select).eq('id', id).single();
      final trick = Trick.fromJson(data);
      await LocalDatabase.cacheTricks([trick]);
      return trick;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('TricksService.getTrickById($id): $e\n$st');
        rethrow;
      }
      final cached = await LocalDatabase.getTrickById(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<List<Trick>> getTricksByIds(List<int> ids) {
    if (ids.isEmpty) return Future.value([]);
    return withOfflineFallback(
      caller: 'TricksService.getTricksByIds',
      online: () async {
        final data =
            await _client.from('tricks').select(_select).inFilter('id', ids);
        final tricks = (data as List).map((e) => Trick.fromJson(e)).toList();
        await LocalDatabase.cacheTricks(tricks);
        return tricks;
      },
      offline: () => LocalDatabase.getTricksByIds(ids),
    );
  }

  static Future<List<Trick>> getVariationsForBaseIds(List<int> baseIds) {
    if (baseIds.isEmpty) return Future.value([]);
    return withOfflineFallback(
      caller: 'TricksService.getVariationsForBaseIds',
      online: () async {
        final data = await _client
            .from('tricks')
            .select(_select)
            .eq('status', ApprovalStatus.approved.index)
            .overlaps('base_trick_ids', baseIds);
        return (data as List).map((e) => Trick.fromJson(e)).toList();
      },
      offline: () async {
        final all = await LocalDatabase.getTricks();
        return all.where((t) => t.baseTrickIds.any(baseIds.contains)).toList();
      },
    );
  }

  static Future<List<Trick>> getVariationsOf(int trickId) {
    return withOfflineFallback(
      caller: 'TricksService.getVariationsOf($trickId)',
      online: () async {
        final data = await _client
            .from('tricks')
            .select(_select)
            .eq('status', ApprovalStatus.approved.index)
            .contains('base_trick_ids', [trickId]);
        return (data as List).map((e) => Trick.fromJson(e)).toList();
      },
      offline: () async {
        final all = await LocalDatabase.getTricks();
        return all.where((t) => t.baseTrickIds.contains(trickId)).toList();
      },
    );
  }

  static Future<List<Trick>> getTricksRequiring(int trickId) {
    return withOfflineFallback(
      caller: 'TricksService.getTricksRequiring($trickId)',
      online: () async {
        final data = await _client
            .from('tricks')
            .select(_select)
            .eq('status', ApprovalStatus.approved.index)
            .contains('prerequisite_trick_ids', [trickId]);
        return (data as List).map((e) => Trick.fromJson(e)).toList();
      },
      offline: () async {
        final all = await LocalDatabase.getTricks();
        return all.where((t) => t.prerequisiteTrickIds.contains(trickId)).toList();
      },
    );
  }

  static Future<List<Trick>> getPendingTricks() async {
    try {
      final data = await _client
          .from('tricks')
          .select(_select)
          .eq('status', ApprovalStatus.pending.index)
          .order('date_submitted');
      return (data as List).map((e) => Trick.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getPendingTricks: $e\n$st');
      rethrow;
    }
  }

  static Future<void> submitTrick(Trick trick) async {
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile == null) {
        debugPrint('TricksService.submitTrick: no authenticated profile');
        return;
      }
      await _client.from('tricks').insert({
        ...trick.toInsertJson(),
        'submitted_by': profile.intId,
      });
    } catch (e, st) {
      debugPrint('TricksService.submitTrick: $e\n$st');
      rethrow;
    }
  }

  static Future<void> updateTrickStatus(int id, ApprovalStatus status) async {
    try {
      await _client.from('tricks').update({'status': status.index}).eq('id', id);
    } catch (e, st) {
      debugPrint('TricksService.updateTrickStatus($id): $e\n$st');
      rethrow;
    }
  }

  static Future<void> updateTrick(int id, Map<String, dynamic> updates) async {
    try {
      await _client.from('tricks').update(updates).eq('id', id);
    } catch (e, st) {
      debugPrint('TricksService.updateTrick($id): $e\n$st');
      rethrow;
    }
  }

  static Future<List<Position>> getPositions() {
    return withOfflineFallback(
      caller: 'TricksService.getPositions',
      online: () async {
        final data = await _client.from('positions').select().order('name');
        final positions =
            (data as List).map((e) => Position.fromJson(e)).toList();
        await LocalDatabase.cachePositions(positions);
        await LocalDatabase.setMeta(
            'positions_last_synced', DateTime.now().toUtc().toIso8601String());
        return positions;
      },
      offline: () => LocalDatabase.getPositions(),
    );
  }

  static Future<void> addPosition(String name) async {
    try {
      await _client.from('positions').insert({'name': name});
    } catch (e, st) {
      debugPrint('TricksService.addPosition($name): $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteTrick(int id) async {
    try {
      await _client.from('tricks').delete().eq('id', id);
    } catch (e, st) {
      debugPrint('TricksService.deleteTrick($id): $e\n$st');
      rethrow;
    }
  }

  static Future<void> submitTrickSuggestion({
    required int trickId,
    required Map<String, dynamic> fields,
  }) async {
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile == null) {
        debugPrint('TricksService.submitTrickSuggestion: no authenticated profile');
        return;
      }
      await _client.from('trick_suggestions').insert({
        'trick_id': trickId,
        ...fields,
        'submitted_by': profile.intId,
      });
    } catch (e, st) {
      debugPrint('TricksService.submitTrickSuggestion(trickId=$trickId): $e\n$st');
      rethrow;
    }
  }

  static Future<List<TrickSuggestion>> getPendingSuggestions() async {
    try {
      final data = await _client
          .from('trick_suggestions')
          .select(_select)
          .order('date_submitted');
      return (data as List).map((e) => TrickSuggestion.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getPendingSuggestions: $e\n$st');
      rethrow;
    }
  }

  static Future<void> deleteSuggestion(int id) async {
    try {
      await _client.from('trick_suggestions').delete().eq('id', id);
    } catch (e, st) {
      debugPrint('TricksService.deleteSuggestion($id): $e\n$st');
      rethrow;
    }
  }

  static Future<void> approveSuggestion(TrickSuggestion suggestion) async {
    try {
      final delta = suggestion.toDeltaJson();
      if (delta.isNotEmpty) await updateTrick(suggestion.trickId, delta);
      await deleteSuggestion(suggestion.id);
    } catch (e, st) {
      debugPrint('TricksService.approveSuggestion(${suggestion.id}): $e\n$st');
      rethrow;
    }
  }
}

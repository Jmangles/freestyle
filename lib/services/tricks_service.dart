import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/approval_status.dart';
import '../models/trick.dart';
import '../models/trick_suggestion.dart';
import '../models/position.dart';
import 'auth_service.dart';

class TricksService {
  static final _client = Supabase.instance.client;

  static const _select =
      '*, '
      'start_position:positions!start_position_id(name), '
      'end_position:positions!end_position_id(name)';

  static Future<List<Trick>> getApprovedTricks() async {
    try {
      final data = await _client
          .from('tricks')
          .select(_select)
          .eq('status', ApprovalStatus.approved.index)
          .order('given_name');
      return (data as List).map((e) => Trick.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getApprovedTricks: $e\n$st');
      rethrow;
    }
  }

  static Future<Trick> getTrickById(int id) async {
    try {
      final data =
          await _client.from('tricks').select(_select).eq('id', id).single();
      return Trick.fromJson(data);
    } catch (e, st) {
      debugPrint('TricksService.getTrickById($id): $e\n$st');
      rethrow;
    }
  }

  static Future<List<Trick>> getTricksByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final data = await _client
          .from('tricks')
          .select(_select)
          .inFilter('id', ids);
      return (data as List).map((e) => Trick.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getTricksByIds: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Trick>> getTricksRequiring(int trickId) async {
    try {
      final data = await _client
          .from('tricks')
          .select(_select)
          .eq('status', ApprovalStatus.approved.index)
          .contains('prerequisite_trick_ids', [trickId]);
      return (data as List).map((e) => Trick.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getTricksRequiring($trickId): $e\n$st');
      rethrow;
    }
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

  static Future<void> updateTrick(
      int id, Map<String, dynamic> updates) async {
    try {
      await _client.from('tricks').update(updates).eq('id', id);
    } catch (e, st) {
      debugPrint('TricksService.updateTrick($id): $e\n$st');
      rethrow;
    }
  }

  static Future<List<Position>> getPositions() async {
    try {
      final data =
          await _client.from('positions').select().order('name');
      return (data as List).map((e) => Position.fromJson(e)).toList();
    } catch (e, st) {
      debugPrint('TricksService.getPositions: $e\n$st');
      rethrow;
    }
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

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trick_vote_stats.dart';
import '../models/user_trick.dart';
import 'auth_service.dart';

class UserTricksService {
  static final _client = Supabase.instance.client;

  static Future<int?> _getUserIntId() async {
    if (!AuthService.isLoggedIn) return null;
    final profile = await AuthService.getCurrentProfile();
    return profile?.intId;
  }

  static Future<List<UserTrick>> getUserTricks() async {
    final intId = await _getUserIntId();
    if (intId == null) return [];
    final data = await _client
        .from('user_tricks')
        .select()
        .eq('user_id', intId);
    return (data as List).map((e) => UserTrick.fromJson(e)).toList();
  }

  static Future<Map<int, UserTrick>> getUserTricksForTrickIds(
      List<int> trickIds) async {
    if (trickIds.isEmpty) return {};
    final intId = await _getUserIntId();
    if (intId == null) return {};
    final data = await _client
        .from('user_tricks')
        .select()
        .eq('user_id', intId)
        .inFilter('trick_id', trickIds);
    final list = (data as List).map((e) => UserTrick.fromJson(e)).toList();
    return {for (final t in list) t.trickId: t};
  }

  static Future<UserTrick?> getUserTrickForTrick(int trickId) async {
    final intId = await _getUserIntId();
    if (intId == null) return null;
    final data = await _client
        .from('user_tricks')
        .select()
        .eq('user_id', intId)
        .eq('trick_id', trickId)
        .maybeSingle();
    return data != null ? UserTrick.fromJson(data) : null;
  }

  static Future<void> setConsistency(
      int trickId, Consistency consistency) async {
    final intId = await _getUserIntId();
    if (intId == null) return;
    await _client.from('user_tricks').upsert(
      {
        'user_id': intId,
        'trick_id': trickId,
        'consistency': consistency.index,
      },
      onConflict: 'user_id,trick_id',
    );
  }

  static Future<TrickVoteStats> getTrickVoteStats(int trickId) async {
    final data = await _client
        .rpc('get_trick_vote_stats', params: {'p_trick_id': trickId});
    return TrickVoteStats.fromRpc(data as Map<String, dynamic>);
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
    await _client
        .from('user_tricks')
        .update({
          'difficulty_vote': difficultyVote,
          'leash_position': leashPosition?.index,
          'video_link': videoLink,
          'video_start': videoStart,
          'video_end': videoEnd,
        })
        .eq('user_id', intId)
        .eq('trick_id', trickId);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_trick.dart';

class UserTricksService {
  static final _client = Supabase.instance.client;

  static Future<List<UserTrick>> getUserTricks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('user_tricks')
        .select()
        .eq('user_id', userId);
    return (data as List).map((e) => UserTrick.fromJson(e)).toList();
  }

  static Future<UserTrick?> getUserTrickForTrick(int trickId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await _client
        .from('user_tricks')
        .select()
        .eq('user_id', userId)
        .eq('trick_id', trickId)
        .maybeSingle();
    return data != null ? UserTrick.fromJson(data) : null;
  }

  static Future<void> setConsistency(
      int trickId, Consistency consistency) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('user_tricks').upsert(
      {
        'user_id': userId,
        'trick_id': trickId,
        'consistency': consistency.index,
      },
      onConflict: 'user_id,trick_id',
    );
  }
}

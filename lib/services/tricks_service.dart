import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trick.dart';
import '../models/position.dart';
import 'auth_service.dart';

class TricksService {
  static final _client = Supabase.instance.client;

  static const _select =
      '*, '
      'start_position:positions!start_position_id(name), '
      'end_position:positions!end_position_id(name)';

  static Future<List<Trick>> getApprovedTricks() async {
    final data = await _client
        .from('tricks')
        .select(_select)
        .eq('status', 1)
        .order('given_name');
    return (data as List).map((e) => Trick.fromJson(e)).toList();
  }

  static Future<Trick> getTrickById(int id) async {
    final data =
        await _client.from('tricks').select(_select).eq('id', id).single();
    return Trick.fromJson(data);
  }

  static Future<List<Trick>> getTricksByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final data = await _client
        .from('tricks')
        .select(_select)
        .inFilter('id', ids);
    return (data as List).map((e) => Trick.fromJson(e)).toList();
  }

  static Future<List<Trick>> getPendingTricks() async {
    final data = await _client
        .from('tricks')
        .select(_select)
        .eq('status', 0)
        .order('date_submitted');
    return (data as List).map((e) => Trick.fromJson(e)).toList();
  }

  static Future<void> submitTrick(Trick trick) async {
    final profile = await AuthService.getCurrentProfile();
    if (profile == null) return;
    await _client.from('tricks').insert({
      ...trick.toInsertJson(),
      'submitted_by': profile.intId,
    });
  }

  static Future<void> updateTrickStatus(int id, int status) async {
    await _client.from('tricks').update({'status': status}).eq('id', id);
  }

  static Future<void> updateTrick(
      int id, Map<String, dynamic> updates) async {
    await _client.from('tricks').update(updates).eq('id', id);
  }

  static Future<List<Position>> getPositions() async {
    final data =
        await _client.from('positions').select().order('name');
    return (data as List).map((e) => Position.fromJson(e)).toList();
  }

  static Future<void> addPosition(String name) async {
    await _client.from('positions').insert({'name': name});
  }

  static Future<void> deleteTrick(int id) async {
    await _client.from('tricks').delete().eq('id', id);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trick.dart';
import '../models/position.dart';

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
        .eq('status', 'approved')
        .order('given_name');
    return (data as List).map((e) => Trick.fromJson(e)).toList();
  }

  static Future<Trick> getTrickById(String id) async {
    final data =
        await _client.from('tricks').select(_select).eq('id', id).single();
    return Trick.fromJson(data);
  }

  static Future<List<Trick>> getTricksByIds(List<String> ids) async {
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
        .eq('status', 'pending')
        .order('date_submitted');
    return (data as List).map((e) => Trick.fromJson(e)).toList();
  }

  static Future<void> submitTrick(Trick trick) async {
    await _client.from('tricks').insert({
      ...trick.toInsertJson(),
      'submitted_by': _client.auth.currentUser!.id,
    });
  }

  static Future<void> updateTrickStatus(String id, String status) async {
    await _client.from('tricks').update({'status': status}).eq('id', id);
  }

  static Future<void> updateTrick(
      String id, Map<String, dynamic> updates) async {
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
}

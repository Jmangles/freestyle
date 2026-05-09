import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tip.dart';
import '../models/tip_type.dart';

class TipsService {
  static final _client = Supabase.instance.client;

  static Future<List<Tip>> getApprovedTips() async {
    final data = await _client
        .from('tips')
        .select()
        .eq('status', true)
        .order('submitted_on', ascending: false);
    return (data as List).map((e) => Tip.fromJson(e)).toList();
  }

  static Future<List<Tip>> getPendingTips() async {
    final data = await _client
        .from('tips')
        .select()
        .eq('status', false)
        .order('submitted_on', ascending: true);
    return (data as List).map((e) => Tip.fromJson(e)).toList();
  }

  static Future<void> submitTip({
    required String title,
    required String header,
    required String body,
    required TipType type,
    int? submittedBy,
  }) async {
    await _client.from('tips').insert({
      'title': title,
      'header': header,
      'body': body,
      'type': type.value,
      'status': false,
      'submitted_on': DateTime.now().toIso8601String().substring(0, 10),
      if (submittedBy != null) 'submitted_by': submittedBy,
    });
  }

  static Future<void> approveTip(int id) async {
    await _client.from('tips').update({
      'status': true,
      'approved_on': DateTime.now().toIso8601String().substring(0, 10),
      'approved_by': _client.auth.currentUser != null
          ? int.tryParse(_client.auth.currentUser!.id)
          : null,
    }).eq('id', id);
  }

  static Future<void> deleteTip(int id) async {
    await _client.from('tips').delete().eq('id', id);
  }

  static Future<void> updateTip({
    required int id,
    required String title,
    required String header,
    required String body,
    required TipType type,
  }) async {
    await _client.from('tips').update({
      'title': title,
      'header': header,
      'body': body,
      'type': type.value,
      'last_updated': DateTime.now().toIso8601String().substring(0, 10),
    }).eq('id', id);
  }
}

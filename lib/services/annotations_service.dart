import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trick_annotation.dart';
import 'auth_service.dart';

class AnnotationsService {
  static final _db = Supabase.instance.client;

  static Future<List<TrickAnnotation>> getForTrick(
      int trickId, String language) async {
    final data = await _db
        .from('trick_annotations')
        .select()
        .eq('trick_id', trickId)
        .eq('language', language)
        .order('start_ms');
    return (data as List)
        .map((e) => TrickAnnotation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TrickAnnotation> create({
    required int trickId,
    required int startMs,
    required int endMs,
    required String text,
    String language = 'en',
  }) async {
    final data = await _db
        .from('trick_annotations')
        .insert({
          'trick_id': trickId,
          'start_ms': startMs,
          'end_ms': endMs,
          'text': text,
          'language': language,
          'created_by': (await AuthService.getCurrentProfile())!.intId,
        })
        .select()
        .single();
    return TrickAnnotation.fromJson(data);
  }

  static Future<TrickAnnotation> update(
    int id, {
    required int startMs,
    required int endMs,
    required String text,
    required String language,
  }) async {
    final data = await _db
        .from('trick_annotations')
        .update({
          'start_ms': startMs,
          'end_ms': endMs,
          'text': text,
          'language': language,
        })
        .eq('id', id)
        .select()
        .single();
    return TrickAnnotation.fromJson(data);
  }

  static Future<void> delete(int id) async {
    await _db.from('trick_annotations').delete().eq('id', id);
  }
}

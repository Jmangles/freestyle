import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trick_annotation.dart';
import '../utils/network_utils.dart';
import 'auth_service.dart';
import 'local_database.dart';

class AnnotationsService {
  static final _db = Supabase.instance.client;

  static Future<List<TrickAnnotation>> getForTrick(
      int trickId, String language) async {
    if (isDeviceOffline) return LocalDatabase.getAnnotations(trickId, language);
    try {
      final data = await _db
          .from('trick_annotations')
          .select()
          .eq('trick_id', trickId)
          .eq('language', language)
          .order('start_ms');

      final annotations = (data as List)
          .map((e) => TrickAnnotation.fromJson(e as Map<String, dynamic>))
          .toList();

      await LocalDatabase.cacheAnnotations(annotations, trickId, language);

      return annotations;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('AnnotationsService.getForTrick($trickId): $e\n$st');
        rethrow;
      }

      return LocalDatabase.getAnnotations(trickId, language);
    }
  }

  static Future<TrickAnnotation> create({
    required int trickId,
    required int startMs,
    required int endMs,
    required String text,
    String language = 'en',
  }) async {
    try {
      final profile = await AuthService.getCurrentProfile();

      if (profile == null) {
        throw StateError('No authenticated profile for annotation creation');
      }

      final data = await _db
          .from('trick_annotations')
          .insert({
            'trick_id': trickId,
            'start_ms': startMs,
            'end_ms': endMs,
            'text': text,
            'language': language,
            'created_by': profile.intId,
          })
          .select()
          .single();

      return TrickAnnotation.fromJson(data);

    } catch (e, st) {
      debugPrint('AnnotationsService.create(trickId=$trickId): $e\n$st');
      rethrow;
    }
  }

  static Future<TrickAnnotation> update(
    int id, {
    required int startMs,
    required int endMs,
    required String text,
    required String language,
  }) async {
    try {
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
    } catch (e, st) {
      debugPrint('AnnotationsService.update($id): $e\n$st');
      rethrow;
    }
  }

  static Future<void> delete(int id) async {
    try {
      await _db.from('trick_annotations').delete().eq('id', id);
    } catch (e, st) {
      debugPrint('AnnotationsService.delete($id): $e\n$st');
      rethrow;
    }
  }
}

import '../models/position.dart';
import '../models/trick.dart';
import '../models/trick_annotation.dart';
import '../models/user_trick.dart';

// On web, all local-DB operations are no-ops. The app uses the Supabase path
// directly and relies on browser caching if connectivity is lost.
class LocalDatabase {
  LocalDatabase._();

  static Future<void> init() async {}

  static Future<void> cacheTricks(List<Trick> _) async {}
  static Future<List<Trick>> getTricks() async => [];
  static Future<Trick?> getTrickById(int _) async => null;
  static Future<List<Trick>> getTricksByIds(List<int> _) async => [];

  static Future<void> cachePositions(List<Position> _) async {}
  static Future<List<Position>> getPositions() async => [];

  static Future<void> cacheUserTricks(List<UserTrick> _) async {}
  static Future<List<UserTrick>> getUserTricks(int _) async => [];
  static Future<Map<int, UserTrick>> getUserTricksForTrickIds(
          int _, List<int> __) async =>
      {};
  static Future<UserTrick?> getUserTrickForTrick(int _, int __) async => null;
  static Future<void> upsertUserTrick(Map<String, dynamic> _) async {}
  static Future<void> upsertUserTrickAndEnqueueWrite({
    required Map<String, dynamic> trickData,
    required String tableName,
    required String operation,
    required Map<String, dynamic> payload,
    required String localSnapshotAt,
  }) async {}

  static Future<void> cacheAnnotations(
      List<TrickAnnotation> _, int __, String ___) async {}
  static Future<List<TrickAnnotation>> getAnnotations(
          int _, String __) async =>
      [];

  static Future<void> enqueuePendingWrite({
    required String tableName,
    required String operation,
    required Map<String, dynamic> payload,
    required String localSnapshotAt,
  }) async {}
  static Future<List<Map<String, dynamic>>> getPendingWrites() async => [];
  static Future<void> deletePendingWrite(int _) async {}
  static Future<void> incrementRetryCount(int _) async {}

  static Future<void> setMeta(String _, String __) async {}
  static Future<String?> getMeta(String _) async => null;
}

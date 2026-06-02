import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../utils/network_utils.dart';
import 'local_database.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Profile? _cachedProfile;

  static Future<Profile?> getCurrentProfile({bool forceRefresh = false}) async {
    if (_cachedProfile != null && !forceRefresh) return _cachedProfile;

    final user = currentUser;
    if (user == null) return null;

    if (isDeviceOffline) return _cachedProfile ?? await _loadProfileFromDisk();

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;

      _cachedProfile = Profile.fromJson(data);

      unawaited(LocalDatabase.setMeta('cached_profile', jsonEncode(data)));

      return _cachedProfile;
    } catch (e, st) {
      if (kIsWeb || !isNetworkError(e)) {
        debugPrint('AuthService.getCurrentProfile: $e\n$st');
        rethrow;
      }

      debugPrint('AuthService.getCurrentProfile: offline, using cache');

      return _cachedProfile ?? await _loadProfileFromDisk();
    }
  }

  static Future<Profile?> _loadProfileFromDisk() async {
    final stored = await LocalDatabase.getMeta('cached_profile');

    if (stored == null) return null;

    _cachedProfile = Profile.fromJson(jsonDecode(stored) as Map<String, dynamic>);

    return _cachedProfile;
  }

  static void clearCache() => _cachedProfile = null;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    clearCache();
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
      emailRedirectTo: kIsWeb ? Uri.base.resolve('/').toString() : null,
    );
  }

  static Future<void> resetPassword(String email) async {
    final redirectTo = kIsWeb ? Uri.base.resolve('/').toString() : null;
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static Future<void> signOut() async {
    clearCache();
    await _client.auth.signOut();
  }
}

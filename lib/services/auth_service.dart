import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Profile? _cachedProfile;

  static Future<Profile?> getCurrentProfile({bool forceRefresh = false}) async {
    if (_cachedProfile != null && !forceRefresh) return _cachedProfile;
    final user = currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    _cachedProfile = Profile.fromJson(data);
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
    );
  }

  static Future<void> signOut() async {
    clearCache();
    await _client.auth.signOut();
  }
}

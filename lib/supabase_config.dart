class SupabaseConfig {
  // Run with --dart-define=USE_LOCAL_SUPABASE=true to point at a local
  // `supabase start` instance instead of prod. See docs/DEV_SETUP.md.
  static const bool useLocal = bool.fromEnvironment('USE_LOCAL_SUPABASE');

  static const String _prodUrl = 'https://ubsmdiesqofnfxuicwxj.supabase.co';
  static const String _prodAnonKey = 'sb_publishable_EHLEMf4zv4Im0u3O6cwhXA_WzIuNDT9';

  // Fixed defaults every `supabase start` local instance uses out of the
  // box - not a secret, safe to hardcode.
  static const String _localUrl = 'http://127.0.0.1:54321';
  static const String _localAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  static String get url => useLocal ? _localUrl : _prodUrl;
  static String get anonKey => useLocal ? _localAnonKey : _prodAnonKey;
}

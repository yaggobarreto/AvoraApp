import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project connection info.
///
/// Defaults point at a local `supabase start` instance. The anon key below is
/// the fixed, publicly-documented demo key Supabase CLI ships for every local
/// install — it is not a secret. Override both via `--dart-define` when
/// pointing the app at a real cloud project:
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=xxxx
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  static Future<void> initialize() {
    return Supabase.initialize(url: url, publishableKey: anonKey);
  }
}

SupabaseClient get supabase => Supabase.instance.client;

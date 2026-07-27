import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_config.dart';

class AuthRepository {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;

  Future<void> signInWithEmail(String email, String password) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password, String name) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  // Google and Apple sign-in need OAuth client IDs configured in the Supabase
  // dashboard (Authentication > Providers) plus platform-specific setup
  // (google-services.json / Sign in with Apple capability) before they can
  // be wired up — left as a follow-up once a Supabase project exists.
  Future<void> signInWithGoogle() {
    throw UnimplementedError('Configure Google OAuth in Supabase dashboard first.');
  }

  Future<void> signInWithApple() {
    throw UnimplementedError('Configure Apple OAuth in Supabase dashboard first.');
  }

  Future<void> signOut() {
    return supabase.auth.signOut();
  }
}

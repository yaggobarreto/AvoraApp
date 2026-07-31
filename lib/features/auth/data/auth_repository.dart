import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_config.dart';

/// Thrown for auth problems that are safe to show the user verbatim.
/// Anything else is surfaced as a generic message so backend details
/// (driver errors, stack traces, provider internals) never leak to the UI.
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;

  /// supabase_flutter persists the session (localStorage on web, secure
  /// storage on mobile) and refreshes it in the background, so "stay logged
  /// in" needs no extra work here — only a session that survives restarts.
  Session? get currentSession => supabase.auth.currentSession;

  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  Future<void> signInWithEmail(String email, String password) {
    return _guard(() => supabase.auth.signInWithPassword(
          email: email,
          password: password,
        ));
  }

  /// Returns true when the account still needs email confirmation, so the UI
  /// can tell the user to go check their inbox instead of silently doing
  /// nothing.
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    final response = await _guard(() => supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
          emailRedirectTo: _redirectUrl,
        ));
    return response.session == null;
  }

  Future<void> signInWithGoogle() {
    return _guard(() => supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _redirectUrl,
        ));
  }

  Future<void> signInWithApple() {
    return _guard(() => supabase.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: _redirectUrl,
        ));
  }

  Future<void> sendPasswordReset(String email) {
    return _guard(() => supabase.auth.resetPasswordForEmail(
          email,
          redirectTo: _redirectUrl,
        ));
  }

  Future<void> resendConfirmation(String email) {
    return _guard(() => supabase.auth.resend(
          type: OtpType.signup,
          email: email,
          emailRedirectTo: _redirectUrl,
        ));
  }

  /// Signs out everywhere rather than just this device, so a logout from a
  /// shared or lost device invalidates the refresh tokens too.
  Future<void> signOut() {
    return _guard(() => supabase.auth.signOut(scope: SignOutScope.global));
  }

  /// On web the OAuth/callback flow must come back to the running app origin.
  /// On mobile it needs a registered deep link, which isn't configured yet,
  /// so we let the SDK use its platform default there.
  String? get _redirectUrl => kIsWeb ? Uri.base.origin : null;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (e) {
      // Never surface raw exception text: it can carry connection strings,
      // hostnames or driver internals.
      debugPrint('Unexpected auth error: $e');
      throw AuthFailure('Não foi possível concluir. Tente novamente.');
    }
  }

  String _friendlyMessage(AuthException e) {
    final code = e.code ?? '';
    if (code.contains('invalid_credentials') ||
        e.message.toLowerCase().contains('invalid login')) {
      // Deliberately identical for "wrong password" and "unknown email" so
      // the endpoint can't be used to enumerate which accounts exist.
      return 'Email ou senha incorretos.';
    }
    if (code.contains('email_not_confirmed')) {
      return 'Confirme seu email antes de entrar. Verifique sua caixa de entrada.';
    }
    if (code.contains('user_already_exists') || code.contains('email_exists')) {
      return 'Esse email já está cadastrado.';
    }
    if (code.contains('weak_password')) {
      return 'Senha fraca: use ao menos 8 caracteres, com maiúscula, minúscula e número.';
    }
    if (code.contains('over_request_rate_limit') || code.contains('over_email_send_rate_limit')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    }
    return 'Não foi possível concluir. Tente novamente.';
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../network/supabase_config.dart';
import 'home_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Guards against re-validating on every auth stream event.
  String? _validatedUserId;

  /// A stored session can outlive the account it belongs to — the user was
  /// deleted, or the database was reset in development. The token still looks
  /// valid to the client (correct signature, not expired), so the app boots
  /// straight into a logged-in shell where every request fails: functions
  /// return 401, and REST quietly returns an empty list because RLS matches
  /// nothing. That reads as "the app is broken" rather than "you're signed
  /// out", and there is no way back short of clearing site data.
  ///
  /// Asking the server who the token belongs to is the only way to tell the
  /// difference, so do it once per session and sign out if the answer is
  /// "nobody".
  Future<void> _validateSession(Session session) async {
    final userId = session.user.id;
    if (_validatedUserId == userId) return;
    _validatedUserId = userId;

    try {
      await supabase.auth.getUser();
    } on AuthException catch (e) {
      // Only a definitive "this user is gone" should sign anyone out; a
      // network blip must not.
      final isMissingUser = e.statusCode == '403' ||
          e.statusCode == '404' ||
          (e.code?.contains('user_not_found') ?? false);
      if (isMissingUser) {
        debugPrint('Stored session refers to a missing user; signing out.');
        await supabase.auth.signOut(scope: SignOutScope.local);
      }
    } catch (e) {
      debugPrint('Could not validate session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) {
          _validatedUserId = null;
          return const LoginScreen();
        }

        _validateSession(session);
        return const HomeShell();
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'core/network/supabase_config.dart';
import 'core/pending_invite.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PendingInvite.captureFromUrl();
  await SupabaseConfig.initialize();
  runApp(const AvoraApp());
}

class AvoraApp extends StatelessWidget {
  const AvoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Avora',
      theme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

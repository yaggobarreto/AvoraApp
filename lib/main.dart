import 'package:flutter/material.dart';

import 'core/network/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MeusAppRoot());
}

class MeusAppRoot extends StatelessWidget {
  const MeusAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nosso Diário de Filmes',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

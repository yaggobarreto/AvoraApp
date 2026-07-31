import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/group.dart';

/// Builds the shareable join link for a group's invite code. Only
/// meaningful on web today — opening it loads the app, and once the person
/// is logged in the code is applied automatically (see PendingInvite).
/// Native mobile deep linking (app_links + platform config) is a future
/// step; on non-web platforms this falls back to just the raw code.
String buildInviteLink(String inviteCode) {
  if (!kIsWeb) return inviteCode;
  final base = Uri.base;
  return Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: base.path,
    queryParameters: {'join': inviteCode},
  ).toString();
}

class InviteScreen extends StatelessWidget {
  final Group group;

  const InviteScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final link = buildInviteLink(group.inviteCode);

    return Scaffold(
      appBar: AppBar(title: Text('Convidar para ${group.name}')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Código: ${group.inviteCode}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kIsWeb
                    ? 'Quem escanear ou abrir o link entra direto no grupo depois de logar.'
                    : 'Compartilhe esse código — a pessoa entra pelo botão "Entrar em um grupo".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onSurfaceMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copiado!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Share.share(
                        'Entra no meu grupo "${group.name}" no Avora: $link',
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avora/core/network/captcha_config.dart';
import 'package:avora/features/auth/presentation/login_screen.dart';
import 'package:avora/features/auth/presentation/turnstile/turnstile.dart';

/// These run on the Dart VM, so the conditional export resolves to the stub —
/// the same code path a mobile build takes. The property that matters here is
/// that a platform without a CAPTCHA implementation degrades gracefully
/// instead of blocking sign-up on a token it can never obtain.
void main() {
  test('CAPTCHA is disabled unless a site key is compiled in', () {
    // No --dart-define in the normal test run.
    expect(CaptchaConfig.siteKey, isEmpty);
    expect(CaptchaConfig.isEnabled, isFalse);
  });

  test('Turnstile is unsupported off the web', () {
    expect(turnstileSupported, isFalse);
  });

  testWidgets('the stub widget renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TurnstileWidget(onToken: (_) {})),
    );

    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up is not blocked by a CAPTCHA that cannot render',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Yago');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'yago@avora.dev',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'SenhaForte1',
    );
    await tester.tap(find.text('Criar conta').last);
    await tester.pump();

    // It must not stop at the CAPTCHA gate. (It will fail later on the
    // network call, which is fine — that is past the point under test.)
    expect(find.text('Complete a verificação de segurança.'), findsNothing);
  });
}

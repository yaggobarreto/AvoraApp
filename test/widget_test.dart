import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:avora/core/widgets/gradient_button.dart';
import 'package:avora/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Login screen shows email and password fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Nosso diário de filmes'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Entrar'), findsOneWidget);
  });

  testWidgets('Switching to sign-up reveals the name field', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Nome'), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Criar conta'), findsOneWidget);
  });

  testWidgets('Sign-up rejects a password that fails the policy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Yago');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'yago@avora.dev',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
    await tester.tap(find.widgetWithText(GradientButton, 'Criar conta'));
    await tester.pump();

    expect(find.text('Inclua uma letra maiúscula'), findsOneWidget);
  });
}

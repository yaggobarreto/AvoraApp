import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meusapp/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Login screen shows email and password fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Nosso Diário de Filmes'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
  });
}

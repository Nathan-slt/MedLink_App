import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/features/auth/screens/senha_screen.dart';

void main() {
  Widget app() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {'/login': (_) => const Scaffold(body: Text('Tela de login'))},
      home: const SenhaScreen(),
    );
  }

  testWidgets('valida o e-mail antes de solicitar a recuperação', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Recuperar senha'));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu e-mail'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'email-invalido');
    await tester.tap(find.text('Recuperar senha'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(find.textContaining('ainda não está disponível'), findsNothing);
  });

  testWidgets('informa que a recuperação ainda não está disponível', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextFormField), 'paciente@exemplo.com');

    await tester.tap(find.text('Recuperar senha'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ainda não está disponível'), findsOneWidget);
    expect(
      find.text('Entre em contato com a clínica para obter ajuda.'),
      findsNothing,
    );
  });

  testWidgets('volta ao login pelo botão da tela', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text('Tela de login'), findsOneWidget);
  });
}

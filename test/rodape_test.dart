import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/widgets/rodape.dart';

void main() {
  Widget app(List<int> taps, {int currentIndex = 0}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        bottomNavigationBar: Rodape(
          currentIndex: currentIndex,
          onTap: taps.add,
        ),
      ),
    );
  }

  testWidgets('tocar na aba já selecionada não dispara onTap', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(app(taps, currentIndex: 0));

    await tester.tap(find.byIcon(Icons.home));
    await tester.pump();

    expect(taps, isEmpty);
  });

  testWidgets('tocar em outra aba dispara onTap com o índice certo',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(app(taps, currentIndex: 0));

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.tap(find.text('PXX'));
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pump();

    expect(taps, [1, 2, 3]);
  });

  testWidgets('mostra confirmação quando o usuário está na fila',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          bottomNavigationBar: Rodape(
            currentIndex: 0,
            usuarioNaFila: true,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.bySemanticsLabel('Fila, você está na fila'), findsOneWidget);
  });
}

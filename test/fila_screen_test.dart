import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/core/models/fila_posicao.dart';
import 'package:projeto_final/features/fila/screens/fila_screen.dart';
import 'package:projeto_final/services/fila_service.dart';

class _FilaServiceFake extends FilaService {
  _FilaServiceFake(this.resposta);

  FilaPosicao? resposta;
  int consultas = 0;

  @override
  Future<FilaPosicao?> minhaPosicao() async {
    consultas++;
    return resposta;
  }
}

void main() {
  testWidgets('oculta identificador e posição até o check-in', (tester) async {
    final service = _FilaServiceFake(null);
    await tester.pumpWidget(
      MaterialApp(home: FilaScreen(isActive: true, service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Você ainda não está na fila.'), findsOneWidget);
    expect(find.text('SEU IDENTIFICADOR'), findsNothing);
    expect(find.text('POSIÇÃO NA FILA'), findsNothing);
    expect(service.consultas, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'mostra os valores enviados pelo backend e atualiza por polling',
    (tester) async {
      final service = _FilaServiceFake(
        const FilaPosicao(
          codigoAtendimento: 'C123',
          status: 'aguardando',
          posicao: 2,
          profissional: 'Dra. Juliana Martins',
          especialidade: 'Ortopedia',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: FilaScreen(isActive: true, service: service)),
      );
      await tester.pumpAndSettle();

      expect(find.text('C123'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Dra. Juliana Martins'), findsOneWidget);
      expect(find.text('Ortopedia'), findsOneWidget);
      expect(find.text('Fila em tempo real'), findsOneWidget);

      service.resposta = const FilaPosicao(
        codigoAtendimento: 'C123',
        status: 'aguardando',
        posicao: 1,
        profissional: 'Dra. Juliana Martins',
        especialidade: 'Ortopedia',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(service.consultas, 2);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mostra cartão chamado e barra de progresso de 40 segundos', (
    tester,
  ) async {
    final service = _FilaServiceFake(
      const FilaPosicao(
        codigoAtendimento: 'P823',
        status: 'chamado',
        posicao: 1,
        profissional: 'Dr. Felipe Rodrigues',
        especialidade: 'Psiquiatria',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FilaScreen(isActive: true, service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAMANDO PACIENTE'), findsOneWidget);
    expect(find.text('Dr. Felipe Rodrigues'), findsOneWidget);
    expect(find.text('Psiquiatria'), findsOneWidget);
    expect(find.text('P823'), findsOneWidget);
    expect(find.text('Iniciando atendimento em 40s'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('chamada-progress')),
    );
    expect(progress.value, 1);
    expect(find.text('POSIÇÃO NA FILA'), findsNothing);
    expect(find.textContaining('00:'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Theme.of(
        tester.element(find.text('CHAMANDO PACIENTE')),
      ).colorScheme.primary,
    );
  });

  testWidgets('após 40 segundos no chamado abre a tela em atendimento', (
    tester,
  ) async {
    final service = _FilaServiceFake(
      const FilaPosicao(
        codigoAtendimento: 'P823',
        status: 'em_atendimento',
        posicao: 1,
        profissional: 'Dr. Felipe Rodrigues',
        especialidade: 'Psiquiatria',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FilaScreen(isActive: true, service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAMANDO PACIENTE'), findsOneWidget);
    expect(find.text('P823'), findsOneWidget);
    await tester.pump(const Duration(seconds: 39));
    expect(find.text('Em atendimento'), findsNothing);
    expect(find.text('Iniciando atendimento em 1s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.text('P823'), findsNothing);
  });

  testWidgets('finalização da fila avisa para atualizar consultas', (
    tester,
  ) async {
    final service = _FilaServiceFake(
      const FilaPosicao(
        codigoAtendimento: 'P823',
        status: 'em_atendimento',
        posicao: 1,
        profissional: 'Dr. Felipe Rodrigues',
        especialidade: 'Psiquiatria',
      ),
    );
    var emAtendimento = false;
    var finalizado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FilaScreen(
          isActive: false,
          keepPolling: true,
          service: service,
          onInServiceStatusChanged: (value) => emAtendimento = value,
          onConsultationCompleted: () => finalizado = true,
        ),
      ),
    );
    await tester.pump();
    expect(emAtendimento, isTrue);

    service.resposta = null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(finalizado, isTrue);
    expect(emAtendimento, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reconhece status de conclusão com acento', (tester) async {
    final service = _FilaServiceFake(
      const FilaPosicao(
        codigoAtendimento: 'P823',
        status: 'concluído',
        posicao: 1,
        profissional: 'Dr. Felipe Rodrigues',
        especialidade: 'Psiquiatria',
      ),
    );
    var finalizado = false;

    await tester.pumpWidget(
      MaterialApp(
        home: FilaScreen(
          isActive: false,
          keepPolling: true,
          service: service,
          onConsultationCompleted: () => finalizado = true,
        ),
      ),
    );
    await tester.pump();

    expect(finalizado, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/features/historico/screens/historico_screen.dart';
import 'package:projeto_final/services/agendamento_service.dart';

class _AgendamentoServiceFake extends AgendamentoService {
  _AgendamentoServiceFake(this.agendamentos);

  final List<AgendamentoDetalhado> agendamentos;

  @override
  Future<List<AgendamentoDetalhado>> listarMeus() async => agendamentos;
}

AgendamentoDetalhado _criarAgendamento({
  required int id,
  required String medico,
  required DateTime data,
  required StatusAgendamento status,
}) {
  return AgendamentoDetalhado(
    agendamento: Agendamento(
      idAgendamento: id,
      idPaciente: 1,
      idProfissional: id,
      idClinica: 1,
      idHorario: id,
      dataHoraConsulta: data,
      status: status,
      criadoPorUsuario: 1,
    ),
    medico: medico,
    especialidade: 'Clínica geral',
    clinica: 'Clínica MedLink',
    endereco: 'Rua Central, 100',
  );
}

void main() {
  final servicoOriginal = AgendamentoService.instance;
  tearDown(() => AgendamentoService.instance = servicoOriginal);

  testWidgets(
    'mostra consultas passadas e realizadas, sem canceladas ou futuras',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final agora = DateTime.now();
      AgendamentoService.instance = _AgendamentoServiceFake([
        _criarAgendamento(
          id: 1,
          medico: 'Dra. Consulta recente',
          data: agora.subtract(const Duration(days: 1)),
          status: StatusAgendamento.realizado,
        ),
        _criarAgendamento(
          id: 2,
          medico: 'Dr. Consulta passada',
          data: agora.subtract(const Duration(days: 3)),
          status: StatusAgendamento.agendado,
        ),
        _criarAgendamento(
          id: 3,
          medico: 'Dr. Consulta cancelada',
          data: agora.subtract(const Duration(days: 2)),
          status: StatusAgendamento.cancelado,
        ),
        _criarAgendamento(
          id: 4,
          medico: 'Dr. Consulta futura',
          data: agora.add(const Duration(days: 1)),
          status: StatusAgendamento.agendado,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HistoricoScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dra. Consulta recente'), findsOneWidget);
      expect(find.text('Dr. Consulta passada'), findsOneWidget);
      expect(find.text('Dr. Consulta cancelada'), findsNothing);
      expect(find.text('Dr. Consulta futura'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('agrupa consultas por dia e filtra por médico', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    AgendamentoService.instance = _AgendamentoServiceFake([
      _criarAgendamento(
        id: 1,
        medico: 'Dra. Ana Silva',
        data: DateTime(2024, 10, 2, 10),
        status: StatusAgendamento.realizado,
      ),
      _criarAgendamento(
        id: 2,
        medico: 'Dr. Bruno Souza',
        data: DateTime(2024, 10, 1, 14),
        status: StatusAgendamento.realizado,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HistoricoScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('quarta-feira, 2 de outubro de 2024'), findsOneWidget);
    expect(find.text('terça-feira, 1 de outubro de 2024'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bruno Souza');
    await tester.pumpAndSettle();

    expect(find.text('Dr. Bruno Souza'), findsOneWidget);
    expect(find.text('Dra. Ana Silva'), findsNothing);
    expect(
      find.text('Nenhuma consulta encontrada com esses filtros.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

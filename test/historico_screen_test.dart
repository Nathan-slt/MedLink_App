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

AgendamentoDetalhado _agendamentoFinalizadoPelaApi({
  required int id,
  required String medico,
  required DateTime data,
}) {
  return AgendamentoDetalhado(
    agendamento: Agendamento.fromJson({
      'id_agendamento': id,
      'id_paciente': 1,
      'id_profissional': id,
      'id_clinica': 1,
      'id_horario': id,
      'data_hora_consulta': data.toUtc().toIso8601String(),
      'status': 'finalizado',
      'criado_por_usuario': 1,
    }),
    medico: medico,
    especialidade: 'Clínica geral',
    clinica: 'Clínica MedLink',
    endereco: 'Rua Central, 100',
  );
}

void main() {
  final servicoOriginal = AgendamentoService.instance;
  tearDown(() {
    AgendamentoService.instance = servicoOriginal;
    AgendamentoService.limparConclusoesDaSessao();
  });

  Future<void> selecionarPeriodo(WidgetTester tester, String periodo) async {
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text(periodo).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mostra somente realizadas; atrasadas aparecem apenas com o filtro',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final agora = DateTime.now();
      AgendamentoService.instance = _AgendamentoServiceFake([
        _agendamentoFinalizadoPelaApi(
          id: 1,
          medico: 'Dra. Consulta recente',
          data: agora.subtract(const Duration(days: 1)),
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
      expect(find.text('Dr. Consulta passada'), findsNothing);
      expect(find.text('Dr. Consulta cancelada'), findsNothing);
      expect(find.text('Dr. Consulta futura'), findsNothing);

      await tester.tap(find.text('Finalizadas'));
      await tester.pumpAndSettle();

      expect(find.text('Dra. Consulta recente'), findsNothing);
      expect(find.text('Dr. Consulta passada'), findsOneWidget);
      expect(find.text('Atrasada - não realizada'), findsOneWidget);
      expect(find.text('Dr. Consulta cancelada'), findsNothing);
      expect(find.text('Dr. Consulta futura'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inclui no histórico a consulta finalizada nesta sessão mesmo se a API '
    'ainda retornar agendada',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final consultaDeHoje = _criarAgendamento(
        id: 20,
        medico: 'Dra. Consulta finalizada hoje',
        data: DateTime.now().subtract(const Duration(minutes: 5)),
        status: StatusAgendamento.agendado,
      );
      AgendamentoService.instance = _AgendamentoServiceFake([consultaDeHoje]);
      AgendamentoService.marcarConcluidaNaSessao(20);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HistoricoScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dra. Consulta finalizada hoje'), findsOneWidget);
      expect(find.text('Atrasada - não realizada'), findsNothing);
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

  testWidgets('filtra somente consultas atrasadas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final agora = DateTime.now();
    AgendamentoService.instance = _AgendamentoServiceFake([
      _criarAgendamento(
        id: 7,
        medico: 'Dr. Consulta atrasada',
        data: agora.subtract(const Duration(days: 2)),
        status: StatusAgendamento.agendado,
      ),
      _criarAgendamento(
        id: 8,
        medico: 'Dra. Consulta realizada',
        data: agora.subtract(const Duration(days: 1)),
        status: StatusAgendamento.realizado,
      ),
      _criarAgendamento(
        id: 9,
        medico: 'Dr. Consulta futura',
        data: agora.add(const Duration(days: 1)),
        status: StatusAgendamento.agendado,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HistoricoScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Atrasadas'), findsNothing);

    expect(find.text('Dr. Consulta atrasada'), findsNothing);
    expect(find.text('Dra. Consulta realizada'), findsOneWidget);
    await tester.tap(find.text('Finalizadas'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Consulta atrasada'), findsOneWidget);
    expect(find.text('Atrasada - não realizada'), findsOneWidget);
    expect(find.text('Dra. Consulta realizada'), findsNothing);
    expect(find.text('Dr. Consulta futura'), findsNothing);
  });

  testWidgets('filtra por semana, mês e dia', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final agora = DateTime.now();
    final inicioDaSemana = DateUtils.dateOnly(
      agora,
    ).subtract(Duration(days: agora.weekday - DateTime.monday));
    final outroDiaDaSemana = inicioDaSemana.add(
      Duration(days: agora.weekday == DateTime.monday ? 1 : 0),
    );
    final inicioMesAnterior = DateTime(
      agora.year,
      agora.month,
      1,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 12));
    AgendamentoService.instance = _AgendamentoServiceFake([
      _criarAgendamento(
        id: 10,
        medico: 'Dra. Consulta de hoje',
        data: agora.subtract(const Duration(hours: 3)),
        status: StatusAgendamento.realizado,
      ),
      _criarAgendamento(
        id: 11,
        medico: 'Dr. Outra consulta da semana',
        data: outroDiaDaSemana.subtract(const Duration(hours: 3)),
        status: StatusAgendamento.realizado,
      ),
      _criarAgendamento(
        id: 12,
        medico: 'Dra. Consulta do mês passado',
        data: inicioMesAnterior.subtract(const Duration(hours: 3)),
        status: StatusAgendamento.realizado,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HistoricoScreen()),
    );
    await tester.pumpAndSettle();

    await selecionarPeriodo(tester, 'Semana');
    expect(find.text('Dra. Consulta de hoje'), findsOneWidget);
    expect(find.text('Dr. Outra consulta da semana'), findsOneWidget);
    expect(find.text('Dra. Consulta do mês passado'), findsNothing);

    await selecionarPeriodo(tester, 'Mês');
    expect(find.text('Dra. Consulta de hoje'), findsOneWidget);
    expect(find.text('Dr. Outra consulta da semana'), findsOneWidget);
    expect(find.text('Dra. Consulta do mês passado'), findsNothing);

    await selecionarPeriodo(tester, 'Dia');
    expect(find.text('Dra. Consulta de hoje'), findsOneWidget);
    expect(find.text('Dr. Outra consulta da semana'), findsNothing);
  });
}

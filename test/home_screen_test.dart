import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/features/home/screens/home_screen.dart';
import 'package:projeto_final/services/agendamento_service.dart';

class _AgendamentoServiceFake extends AgendamentoService {
  _AgendamentoServiceFake(this.agendamentos);

  final List<AgendamentoDetalhado> agendamentos;

  @override
  Future<List<AgendamentoDetalhado>> listarMeus() async => [...agendamentos];
}

AgendamentoDetalhado _consulta({
  required int id,
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
    medico: 'Profissional $id',
    especialidade: 'Especialidade',
    clinica: 'Clínica',
  );
}

AgendamentoDetalhado _consultaFinalizadaPelaApi({
  required int id,
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
    medico: 'Profissional $id',
    especialidade: 'Especialidade',
    clinica: 'Clínica',
  );
}

void main() {
  final servicoOriginal = AgendamentoService.instance;
  tearDown(() => AgendamentoService.instance = servicoOriginal);

  testWidgets('Home mantém consultas ativas atrasadas e destaca o atraso', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final horarioAtrasadoHoje = agora.subtract(const Duration(minutes: 1));
    AgendamentoService.instance = _AgendamentoServiceFake([
      _consultaFinalizadaPelaApi(
        id: 1,
        data: agora.add(const Duration(minutes: 1)),
      ),
      _consulta(
        id: 2,
        data: hoje
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 12)),
        status: StatusAgendamento.agendado,
      ),
      _consulta(
        id: 3,
        data: agora.add(const Duration(minutes: 2)),
        status: StatusAgendamento.agendado,
      ),
      _consulta(
        id: 6,
        data: horarioAtrasadoHoje.subtract(const Duration(hours: 3)),
        status: StatusAgendamento.agendado,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agendamento-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('agendamento-card-2')), findsNothing);
    expect(find.byKey(const ValueKey('agendamento-card-6')), findsOneWidget);
    expect(find.text('Consultas atrasadas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('agendamento-atrasado-6')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('agendamento-card-3')), findsNWidgets(2));
  });

  testWidgets('a próxima consulta aparece quando a atual é finalizada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final agora = DateTime.now();
    final consultaAtual = _consulta(
      id: 4,
      data: agora.subtract(const Duration(hours: 3, minutes: 5)),
      status: StatusAgendamento.agendado,
    );
    final proximaConsulta = _consulta(
      id: 5,
      data: agora.add(const Duration(hours: 2)),
      status: StatusAgendamento.agendado,
    );
    final agendamentos = [consultaAtual, proximaConsulta];
    AgendamentoService.instance = _AgendamentoServiceFake(agendamentos);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agendamento-card-4')), findsWidgets);

    AgendamentoService.notificarConclusaoConsulta();
    await tester.pumpAndSettle();

    expect(AgendamentoService.foiConcluidaNaSessao(4), isTrue);
    expect(find.byKey(const ValueKey('agendamento-card-4')), findsNothing);
    expect(find.byKey(const ValueKey('agendamento-card-5')), findsWidgets);
  });
}

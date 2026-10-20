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
  Future<List<AgendamentoDetalhado>> listarMeus() async => agendamentos;
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

  testWidgets(
    'próxima consulta ignora finalizadas e horários passados',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final agora = DateTime.now();
      AgendamentoService.instance = _AgendamentoServiceFake([
        _consultaFinalizadaPelaApi(
          id: 1,
          data: agora.add(const Duration(minutes: 1)),
        ),
        _consulta(
          id: 2,
          data: agora.subtract(const Duration(hours: 4)),
          status: StatusAgendamento.agendado,
        ),
        _consulta(
          id: 3,
          data: agora.add(const Duration(minutes: 2)),
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
      // O horário passado pode continuar listado no calendário, mas não pode
      // ocupar o destaque de próxima consulta.
      expect(find.byKey(const ValueKey('agendamento-card-2')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agendamento-card-3')),
        findsNWidgets(2),
      );
    },
  );
}

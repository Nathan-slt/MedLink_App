import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/features/home/widgets/calendario.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  testWidgets('a linha dos dias da semana tem altura para o texto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('pt', 'BR'),
        supportedLocales: [Locale('pt', 'BR')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SingleChildScrollView(child: Calendario())),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final calendario =
        tester.widget(
              find.byWidgetPredicate((widget) => widget is TableCalendar),
            )
            as TableCalendar;
    expect(calendario.daysOfWeekHeight, 24);
  });

  testWidgets('o marcador fica próximo ao número e branco no dia selecionado', (
    tester,
  ) async {
    final hoje = DateTime.now();
    final consulta = AgendamentoDetalhado(
      agendamento: Agendamento(
        idAgendamento: 1,
        idPaciente: 1,
        idProfissional: 1,
        idClinica: 1,
        idHorario: 1,
        dataHoraConsulta: hoje.subtract(const Duration(hours: 3)),
        criadoPorUsuario: 1,
      ),
      medico: 'Médico',
      especialidade: 'Especialidade',
      clinica: 'Clínica',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: Calendario(agendamentos: [consulta]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final marker = tester.widget<Container>(
      find.byKey(const ValueKey('appointment-marker')),
    );
    final decoration = marker.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(marker.margin, isNull);
    final markerTranslation = tester.widget<Transform>(
      find.byKey(const ValueKey('appointment-marker-position')),
    );
    expect(markerTranslation.transform.getTranslation().y, -8);

    final calendario = tester.widget<TableCalendar>(
      find.byWidgetPredicate((widget) => widget is TableCalendar),
    );
    expect(calendario.calendarStyle.markerMargin.top, 1);
  });

  testWidgets('não mostra consultas finalizadas na Home', (tester) async {
    final hoje = DateTime.now();
    AgendamentoDetalhado consulta({
      required int id,
      required String medico,
      required StatusAgendamento status,
    }) {
      return AgendamentoDetalhado(
        agendamento: Agendamento(
          idAgendamento: id,
          idPaciente: 1,
          idProfissional: 1,
          idClinica: 1,
          idHorario: id,
          dataHoraConsulta: hoje,
          status: status,
          criadoPorUsuario: 1,
        ),
        medico: medico,
        especialidade: 'Especialidade',
        clinica: 'Clínica',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: Calendario(
              agendamentos: [
                consulta(
                  id: 1,
                  medico: 'Dr. Atendimento finalizado',
                  status: StatusAgendamento.realizado,
                ),
                consulta(
                  id: 2,
                  medico: 'Dra. Consulta ativa',
                  status: StatusAgendamento.agendado,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agendamento-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('agendamento-card-2')), findsOneWidget);
  });
}

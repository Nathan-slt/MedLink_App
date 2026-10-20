import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/models/clinica.dart';
import 'package:projeto_final/core/models/especialidade.dart';
import 'package:projeto_final/core/models/horario_disponivel.dart';
import 'package:projeto_final/core/models/profissional.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/features/home/screens/criar_agendamento_screen.dart';
import 'package:projeto_final/services/agendamento_service.dart';

class _AgendamentoServiceFake extends AgendamentoService {
  _AgendamentoServiceFake(this.dataDisponivel);

  final DateTime dataDisponivel;
  int? profissionalAgendado;
  int? clinicaAgendada;
  int? horarioAgendado;
  DateTime? dataHoraAgendada;
  bool falharEspecialidades = false;

  @override
  Future<List<Clinica>> listarClinicas() async => const [
    Clinica(idClinica: 1, nome: 'Clínica Centro'),
    Clinica(idClinica: 2, nome: 'Clínica Sul'),
  ];

  @override
  Future<List<Especialidade>> listarEspecialidades() async {
    if (falharEspecialidades) {
      throw const ApiException('Falha ao carregar especialidades.');
    }
    return const [
      Especialidade(idEspecialidade: 1, nome: 'Oftalmologia'),
      Especialidade(idEspecialidade: 2, nome: 'Cardiologia'),
    ];
  }

  @override
  Future<List<Profissional>> listarProfissionais({
    required int idEspecialidade,
    required int idClinica,
  }) async => [
    Profissional(
      idProfissional: idEspecialidade == 1 ? 10 : 20,
      nome: idEspecialidade == 1 ? 'Dr. Tom Holland' : 'Dr. Carlos Lima',
      idEspecialidade: idEspecialidade,
      registroProfissional: 'CRM-123',
      idClinica: idClinica,
    ),
  ];

  @override
  Future<List<HorarioDisponivel>> listarHorariosDisponiveis(
    int idProfissional,
  ) async => [
    HorarioDisponivel(
      idHorario: 100,
      idProfissional: idProfissional,
      data: dataDisponivel,
      horaInicio: '08:00:00',
      horaFim: '08:30:00',
      disponivel: true,
    ),
    HorarioDisponivel(
      idHorario: 101,
      idProfissional: idProfissional,
      data: dataDisponivel,
      horaInicio: '08:30:00',
      horaFim: '09:00:00',
      disponivel: false,
    ),
    HorarioDisponivel(
      idHorario: 102,
      idProfissional: idProfissional,
      data: dataDisponivel.add(const Duration(days: 1)),
      horaInicio: '10:00:00',
      horaFim: '10:30:00',
      disponivel: true,
    ),
  ];

  @override
  Future<void> criarAgendamento({
    required int idClinica,
    required int idProfissional,
    required int idHorario,
    required DateTime dataHoraConsulta,
  }) async {
    clinicaAgendada = idClinica;
    profissionalAgendado = idProfissional;
    horarioAgendado = idHorario;
    dataHoraAgendada = dataHoraConsulta;
  }
}

void main() {
  final servicoOriginal = AgendamentoService.instance;
  late _AgendamentoServiceFake servicoFake;

  setUp(() {
    final data = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    servicoFake = _AgendamentoServiceFake(data);
    AgendamentoService.instance = servicoFake;
  });
  tearDown(() => AgendamentoService.instance = servicoOriginal);

  Widget app() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CriarAgendamentoScreen(),
    );
  }

  void telaDeCelular(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('agendar com o formulário vazio mostra os erros', (tester) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();

    expect(find.text('Selecione a especialidade'), findsOneWidget);
    expect(find.text('Selecione o profissional'), findsWidgets);
    expect(find.text('Selecione a clínica'), findsNWidgets(2));
    expect(find.text('Selecione a data'), findsOneWidget);
    expect(find.text('Selecione o horário'), findsOneWidget);
  });

  testWidgets('mostra as clínicas carregadas da API', (tester) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecione a clínica'));
    await tester.pumpAndSettle();

    expect(find.text('Clínica Centro'), findsOneWidget);
    expect(find.text('Clínica Sul'), findsOneWidget);
  });

  testWidgets('exibe erro de especialidades e permite tentar novamente', (
    tester,
  ) async {
    telaDeCelular(tester);
    servicoFake.falharEspecialidades = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Falha ao carregar especialidades.'), findsOneWidget);
    expect(
      find.text('Tentar carregar especialidades novamente'),
      findsOneWidget,
    );

    servicoFake.falharEspecialidades = false;
    await tester.tap(find.text('Tentar carregar especialidades novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Falha ao carregar especialidades.'), findsNothing);
    expect(find.text('Selecione a especialidade médica'), findsOneWidget);
  });

  testWidgets('a lista de profissionais depende da especialidade', (
    tester,
  ) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecione a clínica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clínica Centro').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecione a especialidade médica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oftalmologia').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Selecione o profissional'));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Tom Holland'), findsWidgets);
    expect(find.text('Dr. Carlos Lima'), findsNothing);
  });

  testWidgets('mostra só horários livres da data e envia o slot selecionado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2880);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final dropdowns = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<String>,
    );

    Future<void> escolherOpcao(int indice, String opcao) async {
      final dropdown = dropdowns.at(indice);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcao).last);
      await tester.pumpAndSettle();
    }

    await escolherOpcao(0, 'Clínica Centro');
    await escolherOpcao(1, 'Oftalmologia');
    await escolherOpcao(2, 'Dr. Tom Holland');

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${servicoFake.dataDisponivel.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await escolherOpcao(3, '08:00');
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('08:30'), findsNothing);
    expect(find.text('10:00'), findsNothing);

    await tester.ensureVisible(find.text('Agendar'));
    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();

    expect(servicoFake.profissionalAgendado, 10);
    expect(servicoFake.clinicaAgendada, 1);
    expect(servicoFake.horarioAgendado, 100);
    expect(servicoFake.dataHoraAgendada?.isUtc, isTrue);
    expect(servicoFake.dataHoraAgendada?.hour, 8);
    expect(servicoFake.dataHoraAgendada?.day, servicoFake.dataDisponivel.day);
  });
}

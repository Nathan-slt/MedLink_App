import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/models/fila_posicao.dart';
import 'package:projeto_final/core/models/perfil.dart';
import 'package:projeto_final/core/models/usuario.dart';
import 'package:projeto_final/features/shell/screens/main_shell_screen.dart';
import 'package:projeto_final/services/fila_service.dart';
import 'package:projeto_final/services/perfil_service.dart';

class _FilaServiceFake extends FilaService {
  _FilaServiceFake({this.status = 'aguardando', this.naFila = true});

  final String status;
  final bool naFila;

  @override
  Future<FilaPosicao?> minhaPosicao() async => naFila
      ? FilaPosicao(
          codigoAtendimento: 'C123',
          status: status,
          posicao: 2,
          profissional: 'Dra. Juliana Martins',
          especialidade: 'Ortopedia',
        )
      : null;
}

/// A aba Perfil busca os dados na API; nos testes usamos dados fixos.
class _PerfilServiceFake extends PerfilService {
  final atualizacoes = <String, String>{};

  @override
  Future<Perfil> buscarPerfil() async => const Perfil(
    usuario: Usuario(
      idUsuario: 1,
      nome: 'Kauan Santos',
      email: 'kauansnts@email.com',
      papel: PapelUsuario.paciente,
    ),
    telefone: '(12)99775-6565',
  );

  @override
  Future<void> atualizarDadosUsuario(
    int idUsuario, {
    String? nome,
    String? email,
  }) async {
    if (nome != null) atualizacoes['nome'] = nome;
    if (email != null) atualizacoes['email'] = email;
  }
}

void main() {
  final perfilOriginal = PerfilService.instance;
  final filaOriginal = FilaService.instance;
  late _PerfilServiceFake perfilFake;

  setUp(() {
    perfilFake = _PerfilServiceFake();
    PerfilService.instance = perfilFake;
    FilaService.instance = _FilaServiceFake(naFila: false);
  });
  tearDown(() => PerfilService.instance = perfilOriginal);
  tearDown(() => FilaService.instance = filaOriginal);

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
      home: const MainShellScreen(),
    );
  }

  void telaDeCelular(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('abre na Home e só ela aparece', (tester) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Meus agendamentos'), findsOneWidget);
    expect(find.text('Últimas consultas'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('mostra o selo da fila após confirmar que entrou na fila', (
    tester,
  ) async {
    telaDeCelular(tester);
    FilaService.instance = _FilaServiceFake();
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.bySemanticsLabel('Fila, você está na fila'), findsOneWidget);
    await tester.tap(find.text('PXX'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('C123'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.bySemanticsLabel('Fila, você está na fila'), findsOneWidget);
  });

  testWidgets('destaca a chamada em azul com cartão e sem navegação inferior', (
    tester,
  ) async {
    telaDeCelular(tester);
    FilaService.instance = _FilaServiceFake(status: 'chamando');
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CHAMANDO PACIENTE'), findsOneWidget);
    expect(find.text('Dra. Juliana Martins'), findsOneWidget);
    expect(find.text('C123'), findsOneWidget);
    expect(find.text('POSIÇÃO NA FILA'), findsNothing);
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('ao ser chamado mostra cartão com código e navega para a fila', (
    tester,
  ) async {
    telaDeCelular(tester);
    FilaService.instance = _FilaServiceFake(status: 'chamado');
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CHAMANDO PACIENTE'), findsOneWidget);
    expect(find.text('C123'), findsOneWidget);
    expect(find.text('Em atendimento'), findsNothing);
    expect(find.text('Meus agendamentos'), findsNothing);
  });

  testWidgets('tela Em atendimento aparece apenas dentro da aba Fila', (
    tester,
  ) async {
    telaDeCelular(tester);
    FilaService.instance = _FilaServiceFake(status: 'em atendimento');
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Meus agendamentos'), findsNothing);
    expect(find.text('CHAMANDO PACIENTE'), findsOneWidget);
    expect(find.text('C123'), findsOneWidget);
    expect(find.text('Iniciando atendimento em 30s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Em atendimento'), findsOneWidget);
    expect(find.text('C123'), findsNothing);

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(find.text('Meus agendamentos'), findsOneWidget);
    expect(find.text('Em atendimento'), findsNothing);
  });

  testWidgets('trocar de aba mostra a tela certa e esconde o botão "+"', (
    tester,
  ) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Últimas consultas'), findsOneWidget);
    expect(find.text('Meus agendamentos'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('as abas preservam o estado e tocar na aba atual não recarrega', (
    tester,
  ) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Perfil: entra em modo de edição do telefone (vira ícone de "check").
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(find.text('(12)99775-6565'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Tocar de novo na aba atual não reconstrói a tela: continua editando.
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Ir para a Home e voltar também preserva o estado.
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('edita e salva nome e e-mail no mesmo padrão do telefone', (
    tester,
  ) async {
    telaDeCelular(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kauan Silva');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Kauan Silva'), findsOneWidget);
    expect(perfilFake.atualizacoes['nome'], 'Kauan Silva');

    await tester.tap(find.byIcon(Icons.edit).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kauan@example.com');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('kauan@example.com'), findsOneWidget);
    expect(perfilFake.atualizacoes['email'], 'kauan@example.com');
  });
}

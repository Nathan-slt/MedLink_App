import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/features/auth/screens/senha_screen.dart';
import 'package:projeto_final/services/auth_service.dart';

class _AuthServiceFake extends AuthService {
  int solicitacoesDeCodigo = 0;
  String? emailSolicitado;
  String? emailRedefinido;
  String? codigoRedefinido;
  String? senhaRedefinida;
  String? erroSolicitar;

  @override
  Future<void> solicitarCodigoRecuperacao({required String email}) async {
    solicitacoesDeCodigo++;
    emailSolicitado = email;
    if (erroSolicitar case final mensagem?) {
      throw ApiException(mensagem);
    }
  }

  @override
  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) async {
    emailRedefinido = email;
    codigoRedefinido = codigo;
    senhaRedefinida = novaSenha;
  }
}

void main() {
  final authOriginal = AuthService.instance;
  late _AuthServiceFake authFake;

  Widget app() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      routes: {'/login': (_) => const Scaffold(body: Text('Tela de login'))},
      home: const SenhaScreen(),
    );
  }

  setUp(() {
    authFake = _AuthServiceFake();
    AuthService.instance = authFake;
  });

  tearDown(() {
    AuthService.instance = authOriginal;
  });

  testWidgets('valida o e-mail antes de solicitar o código', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'email-invalido');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(authFake.emailSolicitado, isNull);
  });

  testWidgets('envia código e permite redefinir a senha', (tester) async {
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byType(TextFormField).first,
      'paciente@exemplo.com',
    );
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(authFake.emailSolicitado, 'paciente@exemplo.com');
    expect(
      find.textContaining('Se o e-mail estiver cadastrado'),
      findsOneWidget,
    );
    expect(find.text('Código de recuperação'), findsOneWidget);

    await tester.ensureVisible(find.text('Enviar código novamente'));
    await tester.tap(find.text('Enviar código novamente'));
    await tester.pumpAndSettle();
    expect(authFake.solicitacoesDeCodigo, 2);

    await tester.enterText(find.byType(TextFormField).at(1), '012345');
    await tester.enterText(find.byType(TextFormField).at(2), 'NovaSenha123');
    await tester.enterText(find.byType(TextFormField).at(3), 'NovaSenha123');
    await tester.ensureVisible(find.text('Redefinir senha'));
    await tester.tap(find.text('Redefinir senha'));
    await tester.pumpAndSettle();

    expect(authFake.emailRedefinido, 'paciente@exemplo.com');
    expect(authFake.codigoRedefinido, '012345');
    expect(authFake.senhaRedefinida, 'NovaSenha123');
    expect(find.text('Senha redefinida'), findsOneWidget);

    await tester.ensureVisible(find.text('Ir para o login'));
    await tester.tap(find.text('Ir para o login'));
    await tester.pumpAndSettle();
    expect(find.text('Tela de login'), findsOneWidget);
  });

  testWidgets('mostra erro retornado ao solicitar código', (tester) async {
    authFake.erroSolicitar = 'Não foi possível enviar o código.';
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byType(TextFormField).first,
      'paciente@exemplo.com',
    );

    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível enviar o código.'), findsOneWidget);
    expect(find.text('Código de recuperação'), findsNothing);
  });

  testWidgets('volta ao login pelo botão da tela', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('Voltar para o login'));
    await tester.pumpAndSettle();

    expect(find.text('Tela de login'), findsOneWidget);
  });
}

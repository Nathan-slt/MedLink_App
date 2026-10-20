import 'package:flutter/material.dart';
import 'package:projeto_final/features/notificacoes/screens/notificacoes_screen.dart';
import 'package:projeto_final/app/routes.dart';
import 'package:projeto_final/services/auth_service.dart';

/// Navegação fora de widgets (ex.: quando a sessão expira no meio de uma
/// requisição e precisamos mandar o usuário de volta ao login).
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _encerrando = false;

  static void abrirNotificacoes() {
    final token = AuthService.instance.sessao?.token;
    if (token == null || token.isEmpty) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => TelaNotificacoes(tokenJwt: token)),
    );
  }

  /// Encerra a sessão e volta ao login. Ligado ao `ApiClient.onSessaoExpirada`.
  static Future<void> sessaoExpirada() async {
    if (_encerrando) return; // várias requisições podem falhar juntas
    _encerrando = true;
    try {
      await AuthService.instance.logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sua sessão expirou. Faça login novamente.'),
          ),
        );
    } finally {
      _encerrando = false;
    }
  }
}

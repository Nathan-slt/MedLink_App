import 'package:flutter/foundation.dart';
import 'package:projeto_final/core/auth/sessao.dart';
import 'package:projeto_final/core/models/usuario.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/storage/armazenamento_local.dart';
import 'package:projeto_final/core/utils/mascaras.dart';
import 'package:projeto_final/core/utils/validadores.dart';
import 'package:projeto_final/services/agendamento_service.dart';
import 'package:projeto_final/services/notificacao_push_service.dart';

/// Login, logout e restauração da sessão.
class AuthService {
  AuthService({ApiClient? api, ArmazenamentoLocal? armazenamento})
      : _api = api ?? ApiClient.instance,
        _armazenamento = armazenamento ?? ArmazenamentoLocal();

  /// Instância usada pelo app. Pode ser trocada em testes.
  static AuthService instance = AuthService();

  final ApiClient _api;
  final ArmazenamentoLocal _armazenamento;

  Sessao? _sessao;

  /// Sessão atual, ou nulo se ninguém estiver logado.
  Sessao? get sessao => _sessao;

  /// Só pacientes com sessão ainda válida podem acessar a área protegida.
  bool get estaAutenticado {
    final atual = _sessao;
    return atual != null &&
        !atual.expirada &&
        atual.papel == PapelUsuario.paciente &&
        atual.idPaciente != null;
  }

  /// POST /usuarios/login
  ///
  /// Lança [ApiException] com mensagem pronta para o usuário.
  Future<Sessao> login({required String email, required String senha}) async {
    final resposta = await _api.post(
      '/usuarios/login',
      corpo: {'email': email.trim(), 'senha': senha},
      autenticado: false,
    );

    final token = resposta is Map ? resposta['token'] : null;
    if (token is! String || token.isEmpty) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    final Sessao sessao;
    try {
      sessao = Sessao.fromToken(token);
    } catch (_) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    // O app é do paciente. Equipe da clínica usa o sistema web.
    if (sessao.papel != PapelUsuario.paciente) {
      throw const ApiException(
        'Este aplicativo é exclusivo para pacientes.',
      );
    }
    if (sessao.idPaciente == null) {
      throw const ApiException(
        'Seu cadastro de paciente está incompleto. Procure a clínica.',
      );
    }

    await _iniciarSessao(sessao);
    return sessao;
  }

  /// POST /usuarios/cadastro
  ///
  /// O cadastro público sempre cria um paciente e NÃO devolve token: para
  /// entrar em seguida, chame [login] com o mesmo e-mail e senha.
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String cpf,
    required DateTime dataNascimento,
    required String telefone,
  }) async {
    if (!cpfValido(cpf)) {
      throw const ApiException('CPF inválido.');
    }

    await _api.post(
      '/usuarios/cadastro',
      corpo: {
        'nome': nome.trim(),
        'email': email.trim(),
        'senha': senha,
        'cpf': cpf.trim(),
        'data_nascimento': formatarDataIso(dataNascimento),
        'telefone': telefone.trim(),
      },
      autenticado: false,
    );
  }

  /// Tenta retomar a sessão salva no aparelho (usado na splash).
  /// Nunca lança: qualquer problema significa "não logado".
  Future<bool> restaurarSessao() async {
    try {
      final token = await _armazenamento.lerToken();
      if (token == null || token.isEmpty) return false;

      final sessao = Sessao.fromToken(token);
      if (sessao.expirada ||
          sessao.papel != PapelUsuario.paciente ||
          sessao.idPaciente == null) {
        await _armazenamento.limparTudo();
        return false;
      }

      _sessao = sessao;
      _api.token = sessao.token;
      await _registrarPushSemBloquearSessao();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.instance.removerDispositivo();
    } catch (erro, stackTrace) {
      debugPrint('Falha ao remover o dispositivo do serviço de push: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }

    _sessao = null;
    _api.token = null;
    AgendamentoService.limparConclusoesDaSessao();
    try {
      await _armazenamento.limparTudo();
    } catch (_) {
      // Sem acesso ao armazenamento não há o que apagar; a sessão em memória
      // já foi encerrada.
    }
  }

  Future<void> _iniciarSessao(Sessao sessao) async {
    _sessao = sessao;
    _api.token = sessao.token;
    AgendamentoService.limparConclusoesDaSessao();
    await _armazenamento.salvarToken(sessao.token);
    await _registrarPushSemBloquearSessao();
  }

  Future<void> _registrarPushSemBloquearSessao() async {
    try {
      await PushNotificationService.instance.registrarDispositivo();
    } catch (erro, stackTrace) {
      debugPrint('Falha ao registrar o dispositivo para notificações push: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
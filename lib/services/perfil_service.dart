import 'package:projeto_final/core/models/perfil.dart';
import 'package:projeto_final/core/models/usuario.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/storage/armazenamento_local.dart';

/// Dados do perfil do paciente logado.
class PerfilService {
  PerfilService({ApiClient? api, ArmazenamentoLocal? armazenamento})
      : _api = api ?? ApiClient.instance,
        _armazenamento = armazenamento ?? ArmazenamentoLocal();

  /// Instância usada pelo app. Pode ser trocada em testes.
  static PerfilService instance = PerfilService();

  final ApiClient _api;
  final ArmazenamentoLocal _armazenamento;

  /// GET /usuarios/me
  Future<Perfil> buscarPerfil() async {
    final json = await _api.get('/usuarios/me');
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    final Usuario usuario;
    try {
      usuario = Usuario.fromJson(json);
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    String? telefone = _telefoneDaResposta(json);
    telefone ??= await _lerTelefoneLocal(usuario.idUsuario);

    return Perfil(usuario: usuario, telefone: telefone);
  }

  /// PATCH /usuarios/pacientes/:idUsuario  (o `:id` da rota é o id_usuario)
  Future<void> atualizarTelefone(int idUsuario, String telefone) async {
    await _api.patch(
      '/usuarios/pacientes/$idUsuario',
      corpo: {'telefone': telefone},
    );
    await _armazenamento.salvarTelefone(idUsuario, telefone);
  }

  /// PATCH /usuarios/:idUsuario (campos permitidos: nome e email).
  Future<void> atualizarDadosUsuario(
    int idUsuario, {
    String? nome,
    String? email,
  }) async {
    final corpo = <String, String>{
      'nome': ?nome,
      'email': ?email,
    };
    await _api.patch('/usuarios/$idUsuario', corpo: corpo);
  }

  /// POST /usuarios/:idUsuario/alterar-senha
  Future<void> alterarSenha({
    required int idUsuario,
    required String senhaAtual,
    required String novaSenha,
  }) async {
    await _api.post(
      '/usuarios/$idUsuario/alterar-senha',
      corpo: {'senhaAtual': senhaAtual, 'novaSenha': novaSenha},
    );
  }

  Future<String?> _lerTelefoneLocal(int idUsuario) async {
    try {
      return await _armazenamento.lerTelefone(idUsuario);
    } catch (_) {
      return null;
    }
  }

  String? _telefoneDaResposta(Map<String, dynamic> json) {
    final paciente = json['Paciente'] ?? json['paciente'];
    final valores = [
      json['telefone'],
      if (paciente is Map) paciente['telefone'],
    ];

    for (final valor in valores) {
      if (valor == null) continue;
      final telefone = valor.toString().trim();
      if (telefone.isNotEmpty) return telefone;
    }
    return null;
  }
}

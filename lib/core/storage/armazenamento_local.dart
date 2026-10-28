import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Armazenamento criptografado do aparelho (Keychain no iOS, Keystore no
/// Android). Guarda o token da sessão e dados pequenos do usuário.
class ArmazenamentoLocal {
  ArmazenamentoLocal({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _chaveToken = 'token';

  Future<String?> lerToken() => _storage.read(key: _chaveToken);

  Future<void> salvarToken(String token) =>
      _storage.write(key: _chaveToken, value: token);

  // TEMPORÁRIO: o endpoint /usuarios/me ainda não devolve o telefone (ele
  // fica na tabela `pacientes`). Enquanto isso, guardamos o último telefone
  // salvo neste aparelho. Remover quando o backend passar a devolvê-lo.
  Future<String?> lerTelefone(int idUsuario) =>
      _storage.read(key: 'telefone_$idUsuario');

  Future<void> salvarTelefone(int idUsuario, String telefone) =>
      _storage.write(key: 'telefone_$idUsuario', value: telefone);

  Future<Set<int>> lerNotificacoesDispensadas(int idPaciente) async {
    final valor = await _storage.read(
      key: 'notificacoes_dispensadas_$idPaciente',
    );
    if (valor == null) return {};

    final decodificado = jsonDecode(valor);
    if (decodificado is! List || decodificado.any((id) => id is! int)) {
      throw const FormatException(
        'Lista local de notificações dispensadas inválida.',
      );
    }
    return decodificado.cast<int>().toSet();
  }

  Future<void> salvarNotificacoesDispensadas(int idPaciente, Set<int> ids) =>
      _storage.write(
        key: 'notificacoes_dispensadas_$idPaciente',
        value: jsonEncode(ids.toList()),
      );

  /// Apaga tudo (token e caches). Usado no logout.
  Future<void> limparTudo() => _storage.deleteAll();
}

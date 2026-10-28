import 'package:projeto_final/core/models/notificacoes.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';

class NotificacaoService {
  NotificacaoService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// Lista o histórico associado ao paciente identificado pelo token JWT.
  Future<List<Notificacao>> listarMinhasNotificacoes(String tokenJwt) async {
    _api.token = tokenJwt;
    final resposta = await _api.get(
      '/notificacoes/minhas',
      query: {'_': '${DateTime.now().microsecondsSinceEpoch}'},
    );

    final lista = resposta is List
        ? resposta
        : resposta is Map
        ? resposta['notificacoes']
        : null;
    if (lista is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    try {
      final notificacoes = lista.map((item) {
        if (item is! Map) {
          throw const FormatException('Notificação inválida.');
        }
        return Notificacao.fromJson(Map<String, dynamic>.from(item));
      }).toList();
      notificacoes.sort((a, b) {
        final dataA = DateTime.tryParse(a.dataEnvio);
        final dataB = DateTime.tryParse(b.dataEnvio);
        if (dataA == null) return dataB == null ? 0 : 1;
        if (dataB == null) return -1;
        return dataB.compareTo(dataA);
      });
      return notificacoes;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  /// Marca como lida uma notificação do paciente autenticado.
  Future<bool> marcarComoLida(int idNotificacao, String tokenJwt) async {
    _api.token = tokenJwt;
    await _api.patch('/notificacoes/$idNotificacao/lida');
    return true;
  }
}

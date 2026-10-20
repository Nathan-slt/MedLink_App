import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:projeto_final/core/config/api_config.dart';
import 'package:projeto_final/core/models/notificacoes.dart';

class NotificacaoService {
  // Ajuste a URL base conforme o seu ambiente (localhost, IP da máquina ou produção)
  final String baseUrl = ApiConfig.baseUrl; 

  // 1. Listar notificações do paciente logado
  Future<List<Notificacao>> listarMinhasNotificacoes(String tokenJwt) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificacoes/minhas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenJwt',
      },
    );

    if (response.statusCode == 200) {
      Iterable lista = json.decode(response.body);
      return lista.map((modelo) => Notificacao.fromJson(modelo)).toList();
    } else {
      throw Exception('Falha ao carregar notificações');
    }
  }

  // 2. Marcar notificação como lida
  Future<bool> marcarComoLida(int idNotificacao, String tokenJwt) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notificacoes/$idNotificacao/lida'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenJwt',
      },
    );

    return response.statusCode == 200;
  }
}
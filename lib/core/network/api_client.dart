import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:projeto_final/core/config/api_config.dart';
import 'package:projeto_final/core/network/api_exception.dart';

/// Cliente HTTP único do app.
///
/// - Monta a URL a partir de [ApiConfig.baseUrl].
/// - Envia o token (`Authorization: Bearer ...`) nas rotas autenticadas.
/// - Converte qualquer falha em [ApiException] com mensagem amigável.
/// - Avisa o app, via [onSessaoExpirada], quando o servidor responde 401 a
///   uma rota autenticada (token vencido/inválido).
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, Duration? timeout})
      : _http = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _timeout = timeout ?? ApiConfig.timeout;

  static final ApiClient instance = ApiClient();

  final http.Client _http;
  final String _baseUrl;
  final Duration _timeout;

  /// Token da sessão atual. Quem controla é o `AuthService`.
  String? token;

  /// Chamado quando uma rota autenticada responde 401 com [token] definido.
  Future<void> Function()? onSessaoExpirada;

  Future<dynamic> get(
    String caminho, {
    Map<String, String>? query,
    bool autenticado = true,
  }) {
    return _enviar('GET', caminho, query: query, autenticado: autenticado);
  }

  Future<dynamic> post(
    String caminho, {
    Object? corpo,
    bool autenticado = true,
  }) {
    return _enviar('POST', caminho, corpo: corpo, autenticado: autenticado);
  }

  Future<dynamic> patch(
    String caminho, {
    Object? corpo,
    bool autenticado = true,
  }) {
    return _enviar('PATCH', caminho, corpo: corpo, autenticado: autenticado);
  }

  Future<dynamic> delete(
    String caminho, {
    Object? corpo,
    bool autenticado = true,
    bool tratarSessaoExpirada = true,
  }) {
    return _enviar(
      'DELETE',
      caminho,
      corpo: corpo,
      autenticado: autenticado,
      tratarSessaoExpirada: tratarSessaoExpirada,
    );
  }

  Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Map<String, String>? query,
    Object? corpo,
    required bool autenticado,
    bool tratarSessaoExpirada = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$caminho').replace(queryParameters: query);
    final tokenAtual = token;

    final headers = <String, String>{
      'Accept': 'application/json',
      if (corpo != null) 'Content-Type': 'application/json; charset=UTF-8',
      if (autenticado && tokenAtual != null)
        'Authorization': 'Bearer $tokenAtual',
    };
    final corpoJson = corpo == null ? null : jsonEncode(corpo);

    final Future<http.Response> requisicao = switch (metodo) {
      'GET' => _http.get(uri, headers: headers),
      'POST' => _http.post(uri, headers: headers, body: corpoJson),
      'PATCH' => _http.patch(uri, headers: headers, body: corpoJson),
      'DELETE' => _http.delete(uri, headers: headers, body: corpoJson),
      _ => throw ArgumentError('Método HTTP não suportado: $metodo'),
    };

    final http.Response resposta;
    try {
      resposta = await requisicao.timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } catch (_) {
      // ClientException/SocketException/erro de TLS: não chegou ao servidor.
      throw const ApiException(
        'Sem conexão com o servidor. Verifique sua internet.',
      );
    }

    return _tratarResposta(
      resposta,
      autenticado: autenticado,
      tratarSessaoExpirada: tratarSessaoExpirada,
    );
  }

  Future<dynamic> _tratarResposta(
    http.Response resposta, {
    required bool autenticado,
    required bool tratarSessaoExpirada,
  }) async {
    final status = resposta.statusCode;
    final corpo = _decodificar(resposta);

    if (status >= 200 && status < 300) return corpo;

    if (status == 401 && autenticado) {
      if (token != null && tratarSessaoExpirada) {
        await onSessaoExpirada?.call();
      }
      throw const ApiException(
        'Sua sessão expirou. Faça login novamente.',
        statusCode: 401,
      );
    }

    throw ApiException(_mensagemDeErro(status, corpo), statusCode: status);
  }

  dynamic _decodificar(http.Response resposta) {
    final texto = utf8.decode(resposta.bodyBytes, allowMalformed: true);
    if (texto.trim().isEmpty) return null;
    try {
      return jsonDecode(texto);
    } on FormatException {
      return null;
    }
  }

  String _mensagemDeErro(int status, dynamic corpo) {
    // 5xx: o backend devolve `err.message` cru; não mostramos isso ao usuário.
    if (status >= 500) {
      return 'Erro no servidor. Tente novamente em instantes.';
    }

    // 4xx: o backend manda a mensagem pronta em português no campo `erro`.
    if (corpo is Map && corpo['erro'] is String) {
      final erro = (corpo['erro'] as String).trim();
      if (erro.isNotEmpty) return erro;
    }

    return switch (status) {
      403 => 'Você não tem permissão para fazer isso.',
      404 => 'Não encontrado.',
      _ => 'Não foi possível concluir a solicitação.',
    };
  }
}

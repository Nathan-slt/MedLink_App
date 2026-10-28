import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/services/notificacao_service.dart';

void main() {
  test(
    'lista o histórico autenticado e ordena do mais recente ao mais antigo',
    () async {
      late http.Request requisicao;
      final service = NotificacaoService(
        api: ApiClient(
          client: MockClient((request) async {
            requisicao = request;
            return http.Response(
              jsonEncode({
                'naoLidas': 1,
                'notificacoes': [
                  {
                    'id_notificacao': 1,
                    'id_agendamento': 10,
                    'tipo': 'lembrete',
                    'titulo': 'Consulta antiga',
                    'mensagem': 'Notificação antiga',
                    'lida': true,
                    'data_envio': '2026-01-01T10:00:00Z',
                  },
                  {
                    'id_notificacao': 2,
                    'id_agendamento': 11,
                    'tipo': 'consulta',
                    'titulo': 'Consulta recente',
                    'mensagem': 'Notificação recente',
                    'lida': false,
                    'data_envio': '2026-01-02T10:00:00Z',
                  },
                  {
                    'id_notificacao': 3,
                    'id_agendamento': 12,
                    'tipo': 'proxima_consulta',
                    'titulo': null,
                    'mensagem': null,
                    'lida': false,
                    'data_envio': null,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          baseUrl: 'http://teste/api',
        ),
      );

      final notificacoes = await service.listarMinhasNotificacoes(
        'token-paciente',
      );

      expect(requisicao.method, 'GET');
      expect(requisicao.url.path, '/api/notificacoes/minhas');
      expect(requisicao.url.queryParameters, contains('_'));
      expect(requisicao.headers['Authorization'], 'Bearer token-paciente');
      expect(notificacoes.map((item) => item.id), [2, 1, 3]);
      expect(notificacoes.first.mensagem, 'Notificação recente');
      expect(notificacoes.first.titulo, 'Consulta recente');
      expect(notificacoes.first.lida, isFalse);
      expect(notificacoes.last.mensagem, isEmpty);
      expect(notificacoes.last.dataEnvio, isEmpty);
    },
  );

  test('marca a notificação como lida com o token do paciente', () async {
    late http.Request requisicao;
    final service = NotificacaoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response('', 200);
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    expect(await service.marcarComoLida(7, 'token-paciente'), isTrue);
    expect(requisicao.method, 'PATCH');
    expect(requisicao.url.path, '/api/notificacoes/7/lida');
    expect(requisicao.headers['Authorization'], 'Bearer token-paciente');
  });

  test('informa resposta inválida do servidor', () async {
    final service = NotificacaoService(
      api: ApiClient(
        client: MockClient((_) async => http.Response('{"dados":[]}', 200)),
        baseUrl: 'http://teste/api',
      ),
    );

    await expectLater(
      service.listarMinhasNotificacoes('token-paciente'),
      throwsA(
        isA<ApiException>().having(
          (erro) => erro.mensagem,
          'mensagem',
          'Resposta inesperada do servidor.',
        ),
      ),
    );
  });
}
